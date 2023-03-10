# Muniversal Router

A more universal router than Uniswap's [Universal Router](https://github.com/Uniswap/universal-router) which
additionally supports flash swap, chained V2 swaps on any DEX, enabling risk-free arbitrage.

## About the universal router

Smart contracts allows EOAs to interact with the blockchain programmatically, to some extent. Unlike Cosmos, each
Ethereum transaction can only contain a call to a contract. While the contract called can subsequently call as many
other contracts as EVM allows, the sequence of actions is predefined when the contract is deployed. To change the logic
or to program the transaction differently, usually a new contract has to be written and deployed, which is a lot of
effort and overhead.

While the [Multicall](https://github.com/makerdao/multicall) contract allows multiple contract calls to be executed
sequentially, it has its limitations. On the one hand, using it requires the knowledge and familiarity
with [ABI encoding/decoding](https://docs.soliditylang.org/en/latest/abi-spec.html). On the other hand, it lacks certain
callback functions required by popular contracts, e.g.
[`onERC721Received`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721Receiver.sol),
[`onERC1155Received`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC1155/IERC1155Receiver.sol),
[`uniswapV2Call`](https://github.com/Uniswap/v2-core/blob/master/contracts/interfaces/IUniswapV2Callee.sol).

With the advance of Universal Router from Uniswap, one can program transactions offchain and interact with popular
contracts/protocols using a more friendly interface without the need to deploy his own contract.

## Contract Overview

### Command encoding

Refer to the original repo.

```
   ┌──────┬───────────────────────────────┐
   │ 0x00 │  V3_SWAP_EXACT_IN             │
   ├──────┼───────────────────────────────┤
   │ 0x01 │  V3_SWAP_EXACT_OUT            │
   ├──────┼───────────────────────────────┤
   │ 0x02 │  PERMIT2_TRANSFER_FROM        │
   ├──────┼───────────────────────────────┤
   │ 0x03 │  PERMIT2_PERMIT_BATCH         │
   ├──────┼───────────────────────────────┤
   │ 0x1e-│  -------                      │
   │ 0x3f │                               │
   └──────┴───────────────────────────────┘
```

## Usage

### To Install Dependencies

```console
yarn install
forge install
```

### To Format

```console
yarn run prettier
```

### To Compile and Run Tests

```console
forge build
forge test
```

#### To Update Gas Snapshots

```console
forge snapshot
```
