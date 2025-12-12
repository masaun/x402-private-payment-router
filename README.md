# x402 Private Payment Router contract

## Overview
- This repo is the x402 private payment router contract in `Noir`, which enable a AI agent (seller/buyer) to privately make a payment through `Aztec Network`.

<br>

## Technical Stack

- Smart Contract: `Noir`
  - nargo/noirc: `v1.0.0-beta.11`

- Blockchain: `Aztec` Network (Ethereum L2 Rollup)
  - aztec package: `v3.0.0-devnet.2`

<br>

## Remarks

- This repo is originally forked from the [aztec-workshop](https://github.com/0xShaito/aztec-workshop) repo.

<br>

## Setup

1. Install Aztec by following the instructions from [their documentation](https://docs.aztec.network/developers/getting_started).
2. Install the dependencies by running: `yarn install`
3. Ensure you have Docker installed and running (required for Aztec sandbox)

<br>

## Smart Contract Test
### Noir tests only
Test your contract logic directly:

```bash
yarn test:nr
```

<br>

## e2e Test
### TypeScript integration tests only
Test contract interactions through TypeScript:

```bash
yarn test:js
```

<br>

## Resources

- [Aztec Documentation](https://docs.aztec.network/)
- [Noir Language Documentation](https://noir-lang.org/)
- [Aztec Sandbox Quickstart](https://docs.aztec.network/developers/getting_started)
- [Aztec Contracts Guide](https://docs.aztec.network/aztec/smart_contracts_overview)
