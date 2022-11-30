// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/mocks/ERC20Mock.sol";
import "../src/Pool.sol";

contract PoolTest is Test {
    ERC20Mock token0;
    ERC20Mock token1;
    Pool pool;

    struct UserData {
        uint128 collateralBalance;
        uint128 borrowBalance;
    }

    function setUp() public {
        token0 = new ERC20Mock("Wrapped Ether","WETH",1000 ether);
        token1 = new ERC20Mock("Dai","DAI",1000 ether);
        pool = new Pool(address(token0),address(token1));
    }

    function testLend() public {
        uint256 balanceBefore = token0.balanceOf(address(this));
        token0.approve(address(pool), 1000 ether);
        pool.lend(address(token0), 1000 ether);
        uint256 balanceAfter = token0.balanceOf(address(this));
        assertEq(balanceBefore, balanceAfter + 1000 ether);
        uint256 totalCollateralShares = pool.userCollateralShares(address(this));
        assertEq(totalCollateralShares, 1000 ether);
    }

    function testRedeem() public {
        token0.approve(address(pool), 1000 ether);
        pool.lend(address(token0), 1000 ether);
        uint256 totalCollateralSharesBefore = pool.userCollateralShares(address(this));
        pool.redeem(address(token0), 100 ether);
        uint256 totalCollateralSharesAfter = pool.userCollateralShares(address(this));
        assertEq(totalCollateralSharesAfter, totalCollateralSharesBefore - 100 ether);
    }
}
