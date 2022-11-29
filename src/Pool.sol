// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Pool {
    address public token0;
    address public token1;

    struct Vault {
        uint128 amount;
        uint128 shares;
    }

    struct TokenData {
        Vault totalCollateral;
        Vault totalborrow;
    }

    struct UserData {
        uint128 collateralBalance;
        uint128 borrowBalance;
    }

    TokenData public token0Data;
    TokenData public token1Data;
    mapping(address => UserData) public users;

    modifier _tokenExist(address token) {
        require(token == token0 || token == token1);
        _;
    }

    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
    }

    function toShares(Vault memory total, uint256 amount) internal pure returns (uint256 shares) {
        if (total.amount == 0) {
            shares = amount;
        } else {
            shares = (amount * total.shares) / total.amount;
            if ((shares * total.amount) / total.shares < amount) {
                shares = shares + 1;
            }
        }
    }

    function toAmount(Vault memory total, uint256 shares) internal pure returns (uint256 amount) {
        if (total.shares == 0) {
            amount = shares;
        } else {
            amount = (shares * total.amount) / total.shares;
            if ((amount * total.shares) / total.amount < shares) {
                amount = amount + 1;
            }
        }
    }

    function lend(address token, uint256 amount) external _tokenExist(token) {
        require(amount > 0, "Invalid amount");
        TokenData storage tokenData = (token == token0) ? token0Data : token1Data;
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        uint256 inShare = toShares(tokenData.totalCollateral, amount);
        tokenData.totalCollateral.shares = tokenData.totalCollateral.shares + uint128(inShare);
        tokenData.totalCollateral.amount = tokenData.totalCollateral.amount + uint128(amount);
        UserData storage userData = users[msg.sender];
        userData.collateralBalance = userData.collateralBalance + uint128(inShare);
    }

    function userCollateralShares(address user) public view returns (uint256) {
        return users[msg.sender].collateralBalance;
    }
}
