// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {UniswapV2Library} from "./UniswapV2Library.sol";
import {Permit2Payments} from "../Permit2Payments.sol";
import {Constants} from "../../libraries/Constants.sol";
import {TernaryLib} from "../../libraries/TernaryLib.sol";

/// @title Router for Uniswap v2 Trades
abstract contract V2SwapRouter is Permit2Payments {
    error V2TooLittleReceived();
    error V2TooMuchRequested();
    error V2InvalidPath();

    /// @dev Perform a V2 flash swap without sending tokens beforehand
    function flashSwap(
        IUniswapV2Pair pair,
        address tokenOut,
        uint256 amountOut,
        bytes calldata data
    ) internal {
        (uint256 amount0Out, uint256 amount1Out) = TernaryLib.switchIf(
            tokenOut == pair.token0(),
            0,
            amountOut
        );
        pair.swap(amount0Out, amount1Out, address(this), data);
    }

    function _v2Swap(
        address[] calldata path,
        address[] calldata pairs,
        address recipient,
        address pair
    ) private {
        unchecked {
            if (path.length < 2) revert V2InvalidPath();

            // cached to save on duplicate operations
            (address token0, ) = TernaryLib.sortTokens(path[0], path[1]);
            uint256 finalPathIndex = pairs.length;
            uint256 penultimatePathIndex = finalPathIndex - 1;
            for (uint256 i; i < finalPathIndex; ++i) {
                address input = path[i];
                uint256 amount0Out;
                uint256 amount1Out;
                {
                    (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(
                        pair
                    ).getReserves();
                    (uint256 reserveInput, uint256 reserveOutput) = TernaryLib
                        .switchIf(input == token0, reserve1, reserve0);
                    uint256 amountInput = ERC20(input).balanceOf(pair) -
                        reserveInput;
                    uint256 amountOutput = UniswapV2Library.getAmountOut(
                        amountInput,
                        reserveInput,
                        reserveOutput
                    );
                    (amount0Out, amount1Out) = TernaryLib.switchIf(
                        input == token0,
                        amountOutput,
                        0
                    );
                }
                address nextPair;
                if (i < penultimatePathIndex) {
                    nextPair = pairs[i + 1];
                    (token0, ) = TernaryLib.sortTokens(
                        path[i + 1],
                        path[i + 2]
                    );
                } else {
                    (nextPair, token0) = (recipient, address(0));
                }
                IUniswapV2Pair(pair).swap(
                    amount0Out,
                    amount1Out,
                    nextPair,
                    new bytes(0)
                );
                pair = nextPair;
            }
        }
    }

    /// @notice Performs a Uniswap v2 exact input swap
    /// @param recipient The recipient of the output tokens
    /// @param amountIn The amount of input tokens for the trade
    /// @param amountOutMinimum The minimum desired amount of output tokens
    /// @param path The path of the trade as an array of token addresses
    /// @param pairs The pairs of the trade as an array of lp token addresses
    /// @param payer The address that will be paying the input
    function v2SwapExactInput(
        address recipient,
        uint256 amountIn,
        uint256 amountOutMinimum,
        address[] calldata path,
        address[] calldata pairs,
        address payer
    ) internal {
        uint256 pairsLength = pairs.length;
        unchecked {
            if (pairsLength != path.length - 1) revert V2InvalidPath();
        }
        address firstPair = pairs[0];
        if (
            amountIn != Constants.ALREADY_PAID // amountIn of 0 to signal that the pair already has the tokens
        ) {
            payOrPermit2Transfer(path[0], payer, firstPair, amountIn);
        }

        ERC20 tokenOut = ERC20(path[pairsLength]);
        uint256 balanceBefore = tokenOut.balanceOf(recipient);

        _v2Swap(path, pairs, recipient, firstPair);

        uint256 amountOut = tokenOut.balanceOf(recipient) - balanceBefore;
        if (amountOut < amountOutMinimum) revert V2TooLittleReceived();
    }

    /// @notice Performs a Uniswap v2 exact output swap
    /// @param recipient The recipient of the output tokens
    /// @param amountOut The amount of output tokens to receive for the trade
    /// @param amountInMaximum The maximum desired amount of input tokens
    /// @param path The path of the trade as an array of token addresses
    /// @param pairs The pairs of the trade as an array of lp token addresses
    /// @param payer The address that will be paying the input
    function v2SwapExactOutput(
        address recipient,
        uint256 amountOut,
        uint256 amountInMaximum,
        address[] calldata path,
        address[] calldata pairs,
        address payer
    ) internal {
        unchecked {
            if (pairs.length != path.length - 1) revert V2InvalidPath();
        }
        (uint256 amountIn, address firstPair) = UniswapV2Library
            .getAmountInMultihop(amountOut, path, pairs);
        if (amountIn > amountInMaximum) revert V2TooMuchRequested();

        payOrPermit2Transfer(path[0], payer, firstPair, amountIn);
        _v2Swap(path, pairs, recipient, firstPair);
    }
}
