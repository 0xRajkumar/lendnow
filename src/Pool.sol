// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Oracle.sol";

contract Pool {
    uint256 public constant LIQUIDATION_THRESHOLD = 80;
    uint256 public constant LIQUIDATION_CLOSE_FACTOR = 50;
    uint256 public constant LIQUIDATION_REWARD = 5;
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;

    address public token0;
    address public token1;
    Oracle public oracle;

    struct Vault {
        uint128 amount;
        uint128 shares;
    }

    struct TokenData {
        Vault totalCollateral;
        Vault totalBorrow;
    }

    struct UserData {
        uint128 token0CollateralShare;
        uint128 token1CollateralShare;
        uint128 token0BorrowShare;
        uint128 token1BorrowShare;
    }

    TokenData public token0Data;
    TokenData public token1Data;
    mapping(address => UserData) public users;

    modifier _tokenExist(address token) {
        require(token == token0 || token == token1);
        _;
    }

    constructor(address _token0, address _token1, address _oracle) {
        token0 = _token0;
        token1 = _token1;
        oracle = Oracle(_oracle);
    }

    function getUserTotalCollateral(address user) public returns (uint256 totalInDai) {
        UserData memory userData = users[msg.sender];

        uint256 totalToken0Amount = token0Data.totalCollateral.amount + token0Data.totalBorrow.amount;
        uint256 token0Amount =
            toAmount(totalToken0Amount, token0Data.totalCollateral.shares, userData.token0CollateralShare);
        uint256 token0InUSDC = oracle.converttoUSD(token0, token0Amount);

        uint256 totalToken1Amount = token1Data.totalCollateral.amount + token1Data.totalBorrow.amount;
        uint256 token1Amount =
            toAmount(totalToken1Amount, token1Data.totalCollateral.shares, userData.token1CollateralShare);
        uint256 token1InUSDC = oracle.converttoUSD(token1, token1Amount);
        return token0InUSDC + token1InUSDC;
    }

    function getUsertotalBorrow(address user) public returns (uint256 totalInDai) {
        UserData memory userData = users[msg.sender];

        uint256 totalToken0Amount = token0Data.totalBorrow.amount;
        uint256 token0Amount = toAmount(totalToken0Amount, token0Data.totalBorrow.shares, userData.token0BorrowShare);
        uint256 token0InUSDC = oracle.converttoUSD(token0, token0Amount);

        uint256 totalToken1Amount = token1Data.totalBorrow.amount;
        uint256 token1Amount = toAmount(totalToken1Amount, token1Data.totalBorrow.shares, userData.token1BorrowShare);
        uint256 token1InUSDC = oracle.converttoUSD(token1, token1Amount);
        return token0InUSDC + token1InUSDC;
    }

    function healthFactor(address user) public returns (uint256) {
        uint256 userTotalCollateral = getUserTotalCollateral(user);
        uint256 usertotalBorrow = getUsertotalBorrow(user);

        if (usertotalBorrow == 0) return 100e18;

        return (((userTotalCollateral * LIQUIDATION_THRESHOLD) / 100) * 1e18) / usertotalBorrow;
    }

    function toShares(uint256 totalShares, uint256 totalAmount, uint256 amount)
        internal
        pure
        returns (uint256 shares)
    {
        if (totalAmount == 0) {
            shares = amount;
        } else {
            shares = (amount * totalShares) / totalAmount;
            if ((shares * totalAmount) / totalShares < amount) {
                shares = shares + 1;
            }
        }
    }

    function toAmount(uint256 totalAmount, uint256 totalShares, uint256 shares)
        internal
        pure
        returns (uint256 amount)
    {
        if (totalShares == 0) {
            amount = shares;
        } else {
            amount = (shares * totalAmount) / totalShares;
            if ((amount * totalShares) / totalAmount < shares) {
                amount = amount + 1;
            }
        }
    }

    function userCollateralShares(address user) public view returns (uint256, uint256) {
        UserData memory userData = users[msg.sender];
        return (userData.token0CollateralShare, userData.token1CollateralShare);
    }

    function lend(address token, uint256 amount) external _tokenExist(token) {
        require(amount > 0, "Invalid amount");
        TokenData storage tokenData = (token == token0) ? token0Data : token1Data;
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        uint256 totalAmount = tokenData.totalCollateral.amount + tokenData.totalBorrow.amount;
        uint256 inShare = toShares(tokenData.totalCollateral.shares, totalAmount, amount);
        tokenData.totalCollateral.shares = tokenData.totalCollateral.shares + uint128(inShare);
        tokenData.totalCollateral.amount = tokenData.totalCollateral.amount + uint128(amount);
        UserData storage userData = users[msg.sender];
        if (token == token0) {
            userData.token0CollateralShare = userData.token0CollateralShare + uint128(inShare);
        } else {
            userData.token1CollateralShare = userData.token1CollateralShare + uint128(inShare);
        }
    }

    function redeem(address token, uint256 shareAmount) external _tokenExist(token) {
        require(shareAmount > 0, "Invalid shares");
        UserData storage userData = users[msg.sender];
        if (token == token0) {
            require(userData.token0CollateralShare >= shareAmount, "Low collateral Balance");
        } else {
            require(userData.token1CollateralShare >= shareAmount, "Low collateral Balance");
        }
        TokenData storage tokenData = (token == token0) ? token0Data : token1Data;
        uint256 totalAmount = tokenData.totalCollateral.amount + tokenData.totalBorrow.amount;
        uint256 amount = toAmount(totalAmount, tokenData.totalCollateral.shares, shareAmount);
        IERC20(token).transfer(msg.sender, amount);
        tokenData.totalCollateral.shares = tokenData.totalCollateral.shares - uint128(shareAmount);
        tokenData.totalCollateral.amount = tokenData.totalCollateral.amount - uint128(amount);
        if (token == token0) {
            userData.token0CollateralShare = userData.token0CollateralShare - uint128(shareAmount);
        } else {
            userData.token1CollateralShare = userData.token1CollateralShare - uint128(shareAmount);
        }
        require(healthFactor(msg.sender) >= MIN_HEALTH_FACTOR, "Undercollateralized");
    }
}
