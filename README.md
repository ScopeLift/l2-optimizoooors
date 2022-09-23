# L2 Optimizoooors

<div align="center">
  <img width="400" src="./img/logo.png" alt="L2 Optimizoooors Logo">
</div>

<p align="center">
  <b>Contracts that use as little calldata as possible in order to save gas on L2s.</b>
</p>


<div align="center">
  <img width="150" src="./img/ethereum-badge-light.png" alt="Umbra Logo">
</div>

## Overview

Layer 2 networks share security with mainnet by posting transaction calldata to Layer 1.
As a result, Layer 2 users pay their portion of the mainnet gas costs when executing transactions.
Layer 1 gas can be >25,000x more expensive than Layer 2 gas, so paying for calldata dominates L2 transaction costs.
With custom contracts that use less calldata than standard methods we significantly reduce transactions costs for users.

The frontend for this project can be found [here](https://github.com/ScopeLift/l2-optimizoooors-frontend).

## Benchmarks

This repo contains calldata-optimized routers for three protocols: Aave, Connext, and Superfluid.
Savings for each are shown in the images below.
The same data can be found in [this spreadsheet](https://docs.google.com/spreadsheets/d/1Ix97LDMRnT-ENO5i_nCNk2lVcp6kzua9Mrh7Dk8038E/edit#gid=0).

<p float="left">
  <img src="./img/aave.png" width=350>
  <img src="./img/connext.png" width=350>
  <img src="./img/superfluid.png" width=350>
</p>

## How it Works

Every protocol has a factory contract which deploys the calldata-optimized routers for that protocol.
The factory deploys a unique contract for every combination of methods and parameters that can be hardcoded

For example, with Aave:
- Deposing ETH into Aave has a dedicated contract.
- Withdrawing ETH from Aave has a dedicated contract.
- Depositing USDC into Aave has a dedicated contract.
- And so on.

And similarly for Connext and Superfluid.

This means users don't need to specify a function selector, which saves 4 bytes of calldata.
This also means users don't need to specify a token address, saving another 32 bytes (20 bytes of non-zero calldata).

Aave lets you specify where to send the receipt tokens (on deposit) or the asset itself (on withdraw).
Similarly, Connext lets you specify where to send the asset once bridged.
For both of these we assume the user wants to send the asset to themselves so a recipient address is not required, which again saves 32 bytes (20 bytes of non-zero calldata).

Aave, Connext, and wrapping tokens in Superfluid require you to specify an amount of tokens.
Instead of specifying exact amounts, users specify amounts as percentages of their balance.
If zero bytes of calldata are provided, the full user's balance is used.
Any non-empty calldata provided is considered the numerator of a fraction, such that:

- If one byte of calldata is provided the denominator is 255, which is the max value of a single byte.
- If two bytes of calldata are provided the denominator is 65,535, which is the max value of two bytes.
- And so on.

From there, we compute the amount to use as `userBalance * calldata / denominator`.
This lets you specify nearly any amount of tokens with just a few bytes of calldata.
The tradeoff is precision: you may not be able to send *exactly* one token, and must tolerate a small deviation in the amount.

Some protocols may deem this tradeoff unacceptable, and others require rates or other parameters that don't work with this pattern.
One such case is creating a flow on Superfluid, which requires specifying a flow rate.
In these cases, the user specifies the amount as normal, but with all zero-padding removed.
If you wanted to specify a value of 100e6 with this method, the calldata would be `0x05f5e100`.
This is just 4 bytes, instead of the standard 32 bytes used by ABI-encoding.

## Get in Touch

If you are interested in having gas-optimized routers written for your protocol, please [reach out](https://www.scopelift.co/contact) to us!
