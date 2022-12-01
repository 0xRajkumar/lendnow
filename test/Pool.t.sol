// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/mocks/ERC20Mock.sol";
import "../src/Pool.sol";
import "../src/Oracle.sol";

contract PoolTest is Test {
    //Token0 = ETH
    ERC20Mock token0;
    //Token1 = USDC
    ERC20Mock token1;
    Pool pool;
    Oracle oracle;

    struct UserData {
        uint128 collateralBalance;
        uint128 borrowBalance;
    }

    function setUp() public {
        token0 = new ERC20Mock("Wrapped Ether","WETH",1000 ether);
        token1 = new ERC20Mock("Dai","DAI",1000 ether);
        address[] memory tokens = new address[](2);
        uint256[] memory prices = new uint[](2);
        for (uint256 i = 0; i < 2; i++) {
            if (i == 0) {
                tokens[i] = address(token0);
                prices[i] = 1000;
            } else {
                tokens[i] = address(token1);
                prices[i] = 1;
            }
        }
        oracle = new Oracle(tokens,prices);
        pool = new Pool(address(token0),address(token1),address(oracle));
    }

    function testLend() public {
        uint256 balanceBefore = token0.balanceOf(address(this));
        token0.approve(address(pool), 1000 ether);
        pool.lend(address(token0), 1000 ether);
        uint256 balanceAfter = token0.balanceOf(address(this));
        assertEq(balanceBefore, balanceAfter + 1000 ether);
        (uint256 token0CollateralShare, uint256 token1CollateralShare) = pool.userCollateralShares(address(this));
        assertEq(token0CollateralShare, 1000 ether);
    }

    function testRedeem() public {
        token0.approve(address(pool), 1000 ether);
        pool.lend(address(token0), 1000 ether);
        (uint256 token0CollateralSharesBefore,) = pool.userCollateralShares(address(this));
        pool.redeem(address(token0), 100 ether);
        (uint256 token0CollateralSharesAfter,) = pool.userCollateralShares(address(this));
        assertEq(token0CollateralSharesAfter, token0CollateralSharesBefore - 100 ether);
    }

    function testHealthFactor() public {
        token0.approve(address(pool), 1000 ether);
        pool.lend(address(token0), 1000 ether);
        uint256 health = pool.healthFactor(address(this));
        emit log_named_uint("health", health / 1e18);
    }
}
