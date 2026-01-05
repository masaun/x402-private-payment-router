# x402 Private Payment Router Contract

## Overview

The x402 Private Payment Router is a privacy-preserving payment infrastructure built on `Aztec Network` (Programming Language: `Noir`) that enables AI agents and users to conduct confidential micropayments. The system leverages Aztec's private execution environment and zero-knowledge proofs to ensure complete transaction privacy while maintaining verifiable settlement on Ethereum L2.

This contract acts as a router that manages private wallet balances, coordinates deposits/withdrawals with a Vault system, and settles payments between parties without revealing transaction details on-chain. It's specifically designed for AI agent payments, automated service subscriptions, and privacy-focused micropayments, etc.

## Key Features

- **Privacy-First Design**: All balance updates and payment settlements occur in private execution, ensuring transaction amounts and participants remain confidential
- **Private Wallet Management**: Each payer maintains a private balance tracked via encrypted notes, similar to UTXOs but fully private
- **Vault Integration**: Integrates with a separate PrivateVault contract for secure custody of deposited tokens
- **Payment Settlement**: Direct settlement from payer to payee with automatic balance tracking and event emission
- **Payment ID Tracking**: Maintains a global payment counter for transaction indexing and reference
- **Note-Based Balance System**: Utilizes Aztec's note system (WalletSet) for gas-optimized balance management
- **Event Emission**: Emits private events for off-chain tracking and auditability while preserving privacy

## Architecture

### System Components

The x402 Private Payment Router system consists of three core smart contracts:

1. **X402PrivatePaymentRouter** (Main Contract)
   - Manages private wallet balances for all users
   - Orchestrates deposits, withdrawals, and payment settlements
   - Maintains global payment ID counter
   - Emits payment commitment events

2. **PrivateVault Contract**
   - Holds actual token custody
   - Provides secure deposit/withdrawal interface
   - Isolates token management from payment logic

3. **Token Contract**
   - Standard Aztec private token implementation
   - Enables private transfers between addresses
   - Used for actual token movement

### Contract Interactions

```
User Wallet
    ↓
[Deposit Flow]
    ↓
X402PrivatePaymentRouter → PrivateVault → Token (transfer)
    ↓
Private Balance Updated (Note added)

[Settlement Flow]
    ↓
X402PrivatePaymentRouter (decrease payer balance, increment payment ID)
    ↓
PrivateVault → Token (transfer to payee)
    ↓
Event Emitted (PaymentCommitted)
```

## User Flow

### Assumption
- We assume that all actors (icl. `user`, `payer`, `payee`) in the following flow are `AI agents`.


### 1. Deposit Flow

```
1. User calls deposit(token_address, vault_address, amount)
2. PrivateVault receives tokens from user via Token.transfer_private_to_private()
3. X402PrivatePaymentRouter increases user's private wallet balance
4. User can now make private payments up to their wallet balance
```

### 2. Payment Settlement Flow

```
1. Payer calls settle_payment(token, vault, payee, amount, payment_hash, event_recipient)
2. Contract decreases payer's private wallet balance (burns notes)
3. PrivateVault transfers tokens directly to payee
4. Payment ID is incremented (public state)
5. PaymentCommitted event is emitted privately to event_recipient
6. Transaction completes without revealing amounts or parties publicly
```
(NOTE: `Payer` must deposit at least the amount of token to be settled - before the `Payer` settle it to a `Payee`)

### 3. Withdrawal Flow

```
1. User calls withdraw(token_address, vault_address, amount)
2. X402PrivatePaymentRouter decreases user's private wallet balance
3. PrivateVault transfers tokens back to user
4. User's private notes are updated to reflect remaining balance
```

## Technical Details

### Technical Stack

- Smart Contract: `Noir`
  - nargo/noirc: `v1.0.0-beta.16`

- Blockchain: `Aztec` Network (Ethereum L2 Rollup)
  - aztec package: `v3.0.0-devnet.2`

### Storage Architecture

- **admin**: `PublicImmutable<AztecAddress>` - Contract administrator address
- **payment_id**: `PublicMutable<u128>` - Global payment counter (only public state)
- **wallets**: `Map<AztecAddress, WalletSet>` - Private balance mapping using note-based system

### Note System

The contract uses a `WalletSet` to manage private balances:
- Each deposit creates new `UintNote` entries
- Withdrawals and payments consume (nullify) existing notes
- Change is automatically returned as new notes
- Maximum of 2 notes processed per initial transfer call (`INITIAL_TRANSFER_CALL_MAX_NOTES`)

### Balance Management

**_increase_wallet_balance**: Adds amount to user's private balance
- Creates new encrypted note
- Emits note to recipient address
- Uses `MessageDelivery.CONSTRAINED_ONCHAIN` for security

**_decrease_wallet_balance**: Subtracts amount from user's private balance
- Nullifies existing notes totaling >= amount
- Returns change as new note
- Recursively processes multiple notes if needed

**_subtract_balance**: Core subtraction logic
- Uses `try_sub()` to nullify notes up to max_notes limit
- Returns change or recursively continues if more notes needed
- Ensures minimum progress to prevent infinite loops

### Events

**PaymentCommitted Event**:
```noir
struct PaymentCommitted {
    payment_hash: Field,
    amount: u128,
}
```

Emitted privately during settlement to enable off-chain tracking while maintaining privacy.

## Project Structure

```
x402-private-payment-router/
├── src/
│   ├── nr/                                          # Noir smart contracts
│   │   ├── x402_private_payment_router_contract/  # Main router contract
│   │   │   ├── src/
│   │   │   │   ├── main.nr                        # Core contract logic
│   │   │   │   ├── types/                         # Custom types
│   │   │   │   │   ├── wallet_set.nr              # WalletSet implementation
│   │   │   │   │   └── payment_committed_event.nr # Event definitions
│   │   │   │   ├── library/                       # Shared utilities
│   │   │   │   └── test/                          # Noir unit tests
│   │   │   └── Nargo.toml                         # Noir project config
│   │   ├── private_vault_contract/                # Token custody vault
│   │   └── token_contract/                        # Private token implementation
│   ├── ts/                                         # TypeScript integration tests
│   │   ├── x402_private_payment_router.test.ts
│   │   ├── private_vault.test.ts
│   │   └── utils.ts
│   └── artifacts/                                  # Generated TypeScript bindings
│       ├── X402PrivatePaymentRouter.ts
│       ├── PrivateVault.ts
│       └── Token.ts
├── target/                                         # Compiled contract artifacts
│   ├── x402_private_payment_router_contract-X402PrivatePaymentRouter.json
│   ├── private_vault_contract-PrivateVault.json
│   └── token_contract-Token.json
├── scripts/                                        # Utility scripts
│   ├── check-aztec-version.ts
│   └── start-sandbox.ts
├── benchmarks/                                     # Performance benchmarks
├── pxe-test-vault/                                # Test PXE data for vault
├── pxe-test-x402/                                 # Test PXE data for router
├── package.json                                   # Node.js dependencies
├── Nargo.toml                                     # Workspace config
├── tsconfig.json                                  # TypeScript config
└── vitest.config.ts                              # Test configuration
```

### Key Directories

- **src/nr/**: Contains all Noir smart contract source code
- **src/ts/**: Integration tests written in TypeScript
- **src/artifacts/**: Auto-generated TypeScript contract interfaces
- **target/**: Compiled contract JSON artifacts with circuit definitions
- **pxe-test-*/**: Persistent PXE (Private eXecution Environment) databases for testing
- **scripts/**: Development and deployment utilities

<br>

## Remarks

- This repo is originally forked from the [aztec-workshop](https://github.com/0xShaito/aztec-workshop) repo.

<br>

## Setup

1. Install Aztec by following the instructions from [their documentation](https://docs.aztec.network/developers/getting_started).
2. Install the dependencies by running: `yarn install`
3. Ensure you have Docker installed and running (required for Aztec sandbox)

<br>

## Build

The complete build pipeline includes cleaning, compiling Noir contracts, and generating TypeScript artifacts:

```bash
yarn ccc
```

This runs:
- `yarn clean` - Removes all build artifacts
- `yarn compile` - Compiles Noir contracts using aztec-nargo
- `yarn codegen` - Generates TypeScript bindings from compiled contracts

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
