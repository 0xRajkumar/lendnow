// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/console.sol";

contract Oracle {
    mapping(address => uint256) public PriceInUSDC;

    constructor(address[] memory tokens, uint256[] memory prices) {
        require(tokens.length == prices.length, "Invalid input");
        for (uint256 i = 0; i < tokens.length; i++) {
            PriceInUSDC[tokens[i]] = prices[i];
        }
    }

    function setPrice(address token, uint256 price) public {
        PriceInUSDC[token] = price;
    }

    function converttoUSD(address token, uint256 amount) public view returns (uint256) {
        return amount * PriceInUSDC[token];
    }
}
