// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {IWETH9} from "@uniswap/universal-router/contracts/interfaces/external/IWETH9.sol";
import {IUniversalRouter} from "../interfaces/IUniversalRouter.sol";

/// @title Router Immutable Storage contract
/// @notice Used along with the `RouterParameters` struct for ease of cross-chain deployment
contract RouterImmutables {
    /// @dev Original universal router
    IUniversalRouter internal immutable UNIVERSAL_ROUTER;

    /// @dev WETH9 address
    IWETH9 internal immutable WETH9;

    /// @dev Permit2 address
    IAllowanceTransfer internal immutable PERMIT2;

    /// @dev The address of UniswapV3Factory
    address internal immutable UNISWAP_V3_FACTORY;

    /// @dev The bytes corresponding to UniswapV3Pool initcodehash
    bytes32 internal immutable UNISWAP_V3_POOL_INIT_CODE_HASH;

    constructor(
        address universal_router,
        address permit2,
        address weth9,
        address v3Factory,
        bytes32 poolInitCodeHash
    ) {
        UNIVERSAL_ROUTER = IUniversalRouter(universal_router);
        PERMIT2 = IAllowanceTransfer(permit2);
        WETH9 = IWETH9(weth9);
        UNISWAP_V3_FACTORY = v3Factory;
        UNISWAP_V3_POOL_INIT_CODE_HASH = poolInitCodeHash;
    }
}
