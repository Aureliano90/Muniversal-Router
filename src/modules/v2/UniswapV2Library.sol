// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {TernaryLib} from "../../libraries/TernaryLib.sol";

/// @title Uniswap v2 Helper Library
/// @notice Calculates the recipient address for a command
library UniswapV2Library {
    error InvalidReserves();
    error InvalidPath();

    /// @notice Given an input asset amount returns the maximum output amount of the other asset
    /// @param amountIn The token input amount
    /// @param reserveIn The reserves available of the input token
    /// @param reserveOut The reserves available of the output token
    /// @return amountOut The output amount of the output token
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        if (reserveIn == 0 || reserveOut == 0) revert InvalidReserves();
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }

    /// @notice Returns the input amount needed for a desired output amount in a single-hop trade
    /// @param amountOut The desired output amount
    /// @param reserveIn The reserves available of the input token
    /// @param reserveOut The reserves available of the output token
    /// @return amountIn The input amount of the input token
    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountIn) {
        if (reserveIn == 0 || reserveOut == 0) revert InvalidReserves();
        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = (reserveOut - amountOut) * 997;
        amountIn = (numerator / denominator) + 1;
    }

    /// @notice Returns the input amount needed for a desired output amount in a multi-hop trade
    /// @param amountOut The desired output amount
    /// @param path The path of the multi-hop trade
    /// @param pairs The pairs of the trade as an array of lp token addresses
    /// @return amount The input amount of the input token
    /// @return pair The first pair in the trade
    function getAmountInMultihop(
        uint256 amountOut,
        address[] calldata path,
        address[] calldata pairs
    ) internal view returns (uint256 amount, address pair) {
        uint256 pathLength = path.length;
        if (pathLength < 2) revert InvalidPath();
        amount = amountOut;
        unchecked {
            for (uint256 i = pathLength - 1; i > 0; --i) {
                (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(
                    pairs[i - 1]
                ).getReserves();
                (uint256 reserveIn, uint256 reserveOut) = TernaryLib.switchIf(
                    path[i - 1] < path[i],
                    reserve1,
                    reserve0
                );
                amount = getAmountIn(amount, reserveIn, reserveOut);
            }
        }
        pair = pairs[0];
    }
}
