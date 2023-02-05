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
    //Users
    address Owner = address(0x1);
    address Lender = address(0x2);
    address Borrower = address(0x3);

    struct UserData {
        uint128 collateralBalance;
        uint128 borrowBalance;
    }

    function setUp() public {
        vm.startPrank(Owner);
        token0 = new ERC20Mock("Wrapped Ether", "WETH", 100_000 ether);
        token1 = new ERC20Mock("Dai", "DAI", 100_000 ether);
        address[] memory tokens = new address[](2);
        uint256[] memory prices = new uint[](2);
        tokens[0] = address(token0);
        prices[0] = 1000;
        tokens[1] = address(token1);
        prices[1] = 1;
        oracle = new Oracle(tokens, prices);
        pool = new Pool(address(token0), address(token1), address(oracle));
        token0.transfer(Lender, 10 ether);
        token1.transfer(Borrower, 20000 ether);
        vm.stopPrank();
    }

    function testLend() public {
        vm.startPrank(Lender);
        uint256 balanceBefore = token0.balanceOf(Lender);
        token0.approve(address(pool), 10 ether);
        pool.lend(address(token0), 10 ether);
        uint256 balanceAfter = token0.balanceOf(address(this));
        assertEq(balanceBefore, balanceAfter + 10 ether);
        (uint256 token0CollateralShare, ) = pool.getUserCollateralShares(
            Lender
        );
        assertEq(token0CollateralShare, 10 ether);
        vm.stopPrank();
    }

    function testFailLendOnWrongToken() public {
        vm.startPrank(Lender);
        address wrongToken = address(0x20);
        token0.approve(address(wrongToken), 10 ether);
        pool.lend(address(wrongToken), 10 ether);
        vm.stopPrank();
    }

    function testFailLendOnWrongAmount() public {
        vm.startPrank(Lender);
        uint256 wrongAmount = 0;
        token0.approve(address(pool), 10 ether);
        pool.lend(address(token0), wrongAmount);
        vm.stopPrank();
    }

    function testRedeem() public {
        vm.startPrank(Lender);
        token0.approve(address(pool), 10 ether);
        pool.lend(address(token0), 10 ether);
        (uint256 token0CollateralSharesBefore, ) = pool.getUserCollateralShares(
            Lender
        );
        pool.redeem(address(token0), 10 ether);
        (uint256 token0CollateralSharesAfter, ) = pool.getUserCollateralShares(
            Lender
        );
        assertEq(
            token0CollateralSharesAfter,
            token0CollateralSharesBefore - 10 ether
        );
    }

    function testFailRedeemOnLowcollateral() public {
        vm.startPrank(Lender);
        token0.approve(address(pool), 10 ether);
        pool.lend(address(token0), 10 ether);
        (uint256 token0CollateralShares, ) = pool.getUserCollateralShares(
            Lender
        );
        pool.redeem(address(token0), token0CollateralShares + 1 ether);
        vm.stopPrank();
    }

    function LendTenEther() internal {
        vm.startPrank(Lender);
        token0.approve(address(pool), 10 ether);
        pool.lend(address(token0), 10 ether);
        vm.stopPrank();
    }

    function testBorrow() public {
        LendTenEther();
        vm.startPrank(Borrower);
        token1.approve(address(pool), 1000 ether);
        pool.lend(address(token1), 1000 ether);
        //Taking 0.8 ETH in borrow why? becouse we can take 80% only and 80% is 0.8 ETH becouse 1 ETH is of 1000$ and we have lended 1000$
        pool.borrow(address(token0), ((1e18 * 8) / 10));
        vm.stopPrank();
    }

    function testFailOnUndercollateralizedBorrow() public {
        LendTenEther();
        vm.startPrank(Borrower);
        token1.approve(address(pool), 1000 ether);
        pool.lend(address(token1), 1000 ether);
        pool.borrow(address(token0), ((1e18 * 8) / 10) + 1);
        vm.stopPrank();
    }

    function testFailOnHighAmount() public {
        LendTenEther();
        vm.startPrank(Borrower);
        token1.approve(address(pool), 20000 ether);
        pool.lend(address(token1), 15000 ether);
        pool.borrow(address(token0), 10 ether + 1);
        vm.stopPrank();
    }

    function testRepay() public {
        LendTenEther();
        vm.startPrank(Borrower);
        token1.approve(address(pool), 1000 ether);
        pool.lend(address(token1), 1000 ether);
        pool.borrow(address(token0), ((1e18 * 8) / 10));
        uint256 healthFactorBefore = pool.getHealthFactor(Borrower);
        token0.approve(address(pool), type(uint256).max);
        (uint256 token0UserBorrowShares, ) = pool.getUserBorrowShares(Borrower);
        pool.repay(address(token0), token0UserBorrowShares);
        uint256 healthFactorAfter = pool.getHealthFactor(Borrower);
        assertGt(healthFactorAfter, healthFactorBefore);
    }

    function testLiquidate() public {
        LendTenEther();
        vm.startPrank(Borrower);
        token1.approve(address(pool), 1000 ether);
        pool.lend(address(token1), 1000 ether);
        pool.borrow(address(token0), ((1e18 * 8) / 10));
        oracle.setPrice(address(token0), 1001);
        vm.stopPrank();
        vm.startPrank(Owner);
        token0.approve(address(pool), 10 ether);
        pool.liquidate(Borrower, address(token0), ((1e18 * 8) / 10));
        (, uint256 token1CollateralShares) = pool.getUserCollateralShares(
            Borrower
        );
        //Share will be less than 160 because actual of price of USDC W.R.T ETH
        assertLe(token1CollateralShares, 160 ether);
    }

    function testAccrue() public {
        vm.roll(0);
        LendTenEther();
        vm.startPrank(Borrower);
        token1.approve(address(pool), 1000 ether);
        pool.lend(address(token1), 1000 ether);
        pool.borrow(address(token0), ((1e18 * 8) / 10));
        vm.stopPrank();
        uint256 inUsdcBefore = pool.getUserTotalCollateral(Lender);
        vm.roll(2628000);
        pool.accrueInterest();
        uint256 inUsdcAfter = pool.getUserTotalCollateral(Lender);
        assertGt(inUsdcAfter, inUsdcBefore);
    }
}
