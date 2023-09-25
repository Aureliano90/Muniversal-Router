// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {Callbacks} from "@uniswap/universal-router/contracts/base/Callbacks.sol";
//import {V3SwapRouter} from "@uniswap/universal-router/contracts/modules/uniswap/v3/V3SwapRouter.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {V2SwapRouter} from "../modules/v2/V2SwapRouter.sol";
import {Permit2Payments} from "../modules/Permit2Payments.sol";
import {BytesLib} from "../libraries/BytesLib.sol";
import {Commands} from "../libraries/Commands.sol";
import {LockAndMsgSender} from "./LockAndMsgSender.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";

/// @title Decodes and Executes Commands
/// @notice Called by the UniversalRouter contract to efficiently decode and execute a singular command
abstract contract Dispatcher is
    Permit2Payments,
    V2SwapRouter,
    //    V3SwapRouter,
    Callbacks,
    LockAndMsgSender
{
    using BytesLib for bytes;

    error InvalidCommandType(uint256 commandType);
    error BuyPunkFailed();
    error InvalidOwnerERC721();
    error InvalidOwnerERC1155();
    error BalanceTooLow();

    /// @notice Decodes and executes the given command with the given inputs
    /// @param commandType The command type to execute
    /// @param inputs The inputs to execute the command with
    /// @dev 2 masks are used to enable use of a nested-if statement in execution for efficiency reasons
    /// @return success True on success of the command, false on failure
    /// @return output The outputs or error messages, if any, from the command
    function dispatch(bytes1 commandType, bytes calldata inputs) internal returns (bool success, bytes memory output) {
        uint256 command = uint8(commandType & Commands.COMMAND_TYPE_MASK);

        success = true;

        if (command < 0x20) {
            if (command < 0x10) {
                // 0x00 <= command < 0x08
                if (command < 0x08) {
                    if (command == Commands.V3_SWAP_EXACT_IN) {
                        // equivalent: abi.decode(inputs, (address, uint256, uint256, bytes, bool))
                        address recipient;
                        uint256 amountIn;
                        uint256 amountOutMin;
                        bool payerIsUser;
                        assembly {
                            recipient := calldataload(inputs.offset)
                            amountIn := calldataload(add(inputs.offset, 0x20))
                            amountOutMin := calldataload(add(inputs.offset, 0x40))
                            // 0x60 offset is the path, decoded below
                            payerIsUser := calldataload(add(inputs.offset, 0x80))
                        }
                        bytes calldata path = inputs.toBytes(3);
                        address payer = payerIsUser ? lockedBy : address(this);
                        //                        v3SwapExactInput(
                        //                            map(recipient),
                        //                            amountIn,
                        //                            amountOutMin,
                        //                            path,
                        //                            payer
                        //                        );
                    } else if (command == Commands.V3_SWAP_EXACT_OUT) {
                        // equivalent: abi.decode(inputs, (address, uint256, uint256, bytes, bool))
                        address recipient;
                        uint256 amountOut;
                        uint256 amountInMax;
                        bool payerIsUser;
                        assembly {
                            recipient := calldataload(inputs.offset)
                            amountOut := calldataload(add(inputs.offset, 0x20))
                            amountInMax := calldataload(add(inputs.offset, 0x40))
                            // 0x60 offset is the path, decoded below
                            payerIsUser := calldataload(add(inputs.offset, 0x80))
                        }
                        bytes calldata path = inputs.toBytes(3);
                        address payer = payerIsUser ? lockedBy : address(this);
                        //                        v3SwapExactOutput(
                        //                            map(recipient),
                        //                            amountOut,
                        //                            amountInMax,
                        //                            path,
                        //                            payer
                        //                        );
                    } else if (command == Commands.PERMIT2_TRANSFER_FROM) {
                        // equivalent: abi.decode(inputs, (address, address, uint160))
                        address token;
                        address recipient;
                        uint160 amount;
                        assembly {
                            token := calldataload(inputs.offset)
                            recipient := calldataload(add(inputs.offset, 0x20))
                            amount := calldataload(add(inputs.offset, 0x40))
                        }
                        permit2TransferFrom(token, lockedBy, map(recipient), amount);
                    } else if (command == Commands.PERMIT2_PERMIT_BATCH) {
                        // equivalent: abi.decode(inputs, (IAllowanceTransfer.PermitBatch, bytes))
                        IAllowanceTransfer.PermitBatch calldata permitBatch;
                        assembly {
                            permitBatch := add(inputs.offset, calldataload(inputs.offset))
                        }
                        bytes calldata data = inputs.toBytes(1);
                        PERMIT2.permit(lockedBy, permitBatch, data);
                    } else if (command == Commands.SWEEP) {
                        // equivalent:  abi.decode(inputs, (address, address, uint256))
                        address token;
                        address recipient;
                        uint160 amountMin;
                        assembly {
                            token := calldataload(inputs.offset)
                            recipient := calldataload(add(inputs.offset, 0x20))
                            amountMin := calldataload(add(inputs.offset, 0x40))
                        }
                        sweep(token, map(recipient), amountMin);
                    } else if (command == Commands.TRANSFER) {
                        // equivalent:  abi.decode(inputs, (address, address, uint256))
                        address token;
                        address recipient;
                        uint256 value;
                        assembly {
                            token := calldataload(inputs.offset)
                            recipient := calldataload(add(inputs.offset, 0x20))
                            value := calldataload(add(inputs.offset, 0x40))
                        }
                        pay(token, map(recipient), value);
                    } else if (command == Commands.PAY_PORTION) {
                        // equivalent:  abi.decode(inputs, (address, address, uint256))
                        address token;
                        address recipient;
                        uint256 bips;
                        assembly {
                            token := calldataload(inputs.offset)
                            recipient := calldataload(add(inputs.offset, 0x20))
                            bips := calldataload(add(inputs.offset, 0x40))
                        }
                        payPortion(token, map(recipient), bips);
                    } else {
                        // placeholder area for command 0x07
                        revert InvalidCommandType(command);
                    }
                    // 0x08 <= command < 0x10
                } else {
                    if (command == Commands.V2_SWAP_EXACT_IN) {
                        // equivalent: abi.decode(inputs, (address, uint256, uint256, address[], address[], bool))
                        address recipient;
                        uint256 amountIn;
                        uint256 amountOutMin;
                        bool payerIsUser;
                        assembly {
                            recipient := calldataload(inputs.offset)
                            amountIn := calldataload(add(inputs.offset, 0x20))
                            amountOutMin := calldataload(add(inputs.offset, 0x40))
                            // 0x60 offset is the path, decoded below
                            payerIsUser := calldataload(add(inputs.offset, 0xa0))
                        }
                        address[] calldata path = inputs.toAddressArray(3);
                        address[] calldata pairs = inputs.toAddressArray(4);
                        address payer = payerIsUser ? lockedBy : address(this);
                        v2SwapExactInput(map(recipient), amountIn, amountOutMin, path, pairs, payer);
                    } else if (command == Commands.V2_SWAP_EXACT_OUT) {
                        // equivalent: abi.decode(inputs, (address, uint256, uint256, address[], address[], bool))
                        address recipient;
                        uint256 amountOut;
                        uint256 amountInMax;
                        bool payerIsUser;
                        assembly {
                            recipient := calldataload(inputs.offset)
                            amountOut := calldataload(add(inputs.offset, 0x20))
                            amountInMax := calldataload(add(inputs.offset, 0x40))
                            // 0x60 offset is the path, decoded below
                            payerIsUser := calldataload(add(inputs.offset, 0xa0))
                        }
                        address[] calldata path = inputs.toAddressArray(3);
                        address[] calldata pairs = inputs.toAddressArray(4);
                        address payer = payerIsUser ? lockedBy : address(this);
                        v2SwapExactOutput(map(recipient), amountOut, amountInMax, path, pairs, payer);
                    } else if (command == Commands.PERMIT2_PERMIT) {
                        // equivalent: abi.decode(inputs, (IAllowanceTransfer.PermitSingle, bytes))
                        IAllowanceTransfer.PermitSingle calldata permitSingle;
                        assembly {
                            permitSingle := inputs.offset
                        }
                        bytes calldata data = inputs.toBytes(6); // PermitSingle takes first 6 slots (0..5)
                        PERMIT2.permit(lockedBy, permitSingle, data);
                    } else if (command == Commands.WRAP_ETH) {
                        // equivalent: abi.decode(inputs, (address, uint256))
                        address recipient;
                        uint256 amountMin;
                        assembly {
                            recipient := calldataload(inputs.offset)
                            amountMin := calldataload(add(inputs.offset, 0x20))
                        }
                        wrapETH(map(recipient), amountMin);
                    } else if (command == Commands.UNWRAP_WETH) {
                        // equivalent: abi.decode(inputs, (address, uint256))
                        address recipient;
                        uint256 amountMin;
                        assembly {
                            recipient := calldataload(inputs.offset)
                            amountMin := calldataload(add(inputs.offset, 0x20))
                        }
                        unwrapWETH9(map(recipient), amountMin);
                    } else if (command == Commands.PERMIT2_TRANSFER_FROM_BATCH) {
                        // equivalent: abi.decode(inputs, (IAllowanceTransfer.AllowanceTransferDetails[]))
                        IAllowanceTransfer.AllowanceTransferDetails[] calldata batchDetails;
                        (uint256 length, uint256 offset) = inputs.toLengthOffset(0);
                        assembly {
                            batchDetails.length := length
                            batchDetails.offset := offset
                        }
                        permit2TransferFrom(batchDetails, lockedBy);
                    } else if (command == Commands.BALANCE_CHECK_ERC20) {
                        // equivalent: abi.decode(inputs, (address, address, uint256))
                        address owner;
                        address token;
                        uint256 minBalance;
                        assembly {
                            owner := calldataload(inputs.offset)
                            token := calldataload(add(inputs.offset, 0x20))
                            minBalance := calldataload(add(inputs.offset, 0x40))
                        }
                        success = (ERC20(token).balanceOf(owner) >= minBalance);
                        if (!success) output = abi.encodePacked(BalanceTooLow.selector);
                    } else {
                        // placeholder area for command 0x0f
                        revert InvalidCommandType(command);
                    }
                }
                // 0x10 <= command
            } else {}
            // 0x20 <= command
        } else {
            if (command == Commands.EXECUTE_SUB_PLAN) {
                bytes calldata _commands = inputs.toBytes(0);
                bytes[] calldata _inputs = inputs.toBytesArray(1);
                (success, output) = (address(this)).call(
                    abi.encodeWithSelector(Dispatcher.execute.selector, _commands, _inputs)
                );
            } else if (command == Commands.APPROVE_ERC20) {
                address token;
                uint256 spenderID;
                assembly {
                    token := calldataload(inputs.offset)
                    spenderID := calldataload(add(inputs.offset, 0x20))
                }
                approveERC20(token, spenderID);
            } else if (command == Commands.V2_FLASH_SWAP) {
                address pair;
                address tokenOut;
                uint256 amountOut;
                // Equivalent: abi.decode(inputs, (address, address, uint256, bytes))
                assembly ("memory-safe") {
                    pair := calldataload(inputs.offset)
                    tokenOut := calldataload(add(inputs.offset, 0x20))
                    amountOut := calldataload(add(inputs.offset, 0x40))
                }
                flashSwap(IUniswapV2Pair(pair), tokenOut, amountOut, inputs.toBytes(3));
            } else {
                // placeholder area for commands 0x22-0x3f
                revert InvalidCommandType(command);
            }
        }
    }

    /// @notice Executes encoded commands along with provided inputs.
    /// @param commands A set of concatenated commands, each 1 byte in length
    /// @param inputs An array of byte strings containing abi encoded inputs for each command
    function execute(bytes calldata commands, bytes[] calldata inputs) external payable virtual;
}
