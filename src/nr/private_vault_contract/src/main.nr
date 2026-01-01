use aztec::macros::aztec;

pub mod types;
pub mod test;

#[aztec]
pub contract PrivateVault {
    // aztec library imports
    use aztec::{
        context::{PrivateContext, PublicContext},
        keys::getters::{get_nsk_app, get_public_keys},
        macros::{
            functions::{external, initializer, internal, view}, 
            storage::storage,
            notes::{
                note,
                custom_note
            },
        },
        //messages::logs::note,
        note::{
            note_emission::OuterNoteEmission,
            note_getter_options::{NoteGetterOptions, SortOrder},
            note_interface::{NoteProperties, NoteHash, NoteType},
            note_viewer_options::NoteViewerOptions,
            retrieved_note::RetrievedNote
        },
        protocol_types::{
            address::AztecAddress,
            constants::{
                GENERATOR_INDEX__NOTE_HASH, GENERATOR_INDEX__NOTE_NULLIFIER,
                GENERATOR_INDEX__PARTIAL_NOTE_VALIDITY_COMMITMENT,
            },
            hash::poseidon2_hash_with_separator,
            traits::{Deserialize, Hash, Packable, Serialize, ToField},
        },
        state_vars::{
            PublicImmutable, PublicMutable, DelayedPublicMutable,
            PrivateImmutable, PrivateMutable, PrivateSet, 
            Map
        },
        oracle::random::random,
        event::{
            event_emission::emit_event_in_private,
            event_selector::EventSelector,
            event_interface::EventInterface,
        },
        messages::message_delivery::MessageDelivery
    };

    // @dev - Import the Token contract (token_contract/src/main.nr)
    use token::Token;

    // @dev - Import the Note library
    use uint_note::uint_note::{UintNote, PartialUintNote};

    // @dev - Import the note struct or/and the custom note struct
    use crate::types::vault_wallet_set::{VaultWalletSet};

    /*********************************
    *   @notice - Global constants   *
    *********************************/
    // gas-optimized max notes for initial transfer call
    global INITIAL_TRANSFER_CALL_MAX_NOTES: u32 = 2;

    /************************
    *   @notice - Storage   *
    *************************/
    #[storage]
    struct Storage<Context> {
        admin: PublicImmutable<AztecAddress, Context>,
        token_contract_address: PublicImmutable<AztecAddress, Context>,
        vault_wallets: Map<AztecAddress, VaultWalletSet<Context>, Context>,  // Private wallets: payer => balances
    }

    /****************************
    *   @notice - Constructor   *
    ****************************/
    /// @dev Initialize the contract
    /// @param owner The address of the owner
    #[external("public")]
    #[initializer]
    fn constructor(_admin: AztecAddress, token_contract_address: AztecAddress) {
        storage.admin.initialize(_admin);
        storage.token_contract_address.initialize(token_contract_address);
    }

    /*******************************
    *   @notice - Main functions   *
    *******************************/

    /// @dev - Deposit a given amount of funds into a payer's private wallet + Increments the payment ID
    #[external("private")]
    fn deposit(
        token_contract_address: AztecAddress,
        from: AztecAddress,
        amount: u128,
    ) {
        // @dev - Create the contract instance of the PrivateVault contract
        let private_vault = PrivateVault::at(context.this_address());

        // @dev - Create the contract instance of the Token contract
        let token = Token::at(storage.token_contract_address.read());

        // @dev - Store the PrivateVault contract address into a variable
        let PRIVATE_VAULT = context.this_address();

        // @dev - Increase the private balance of the payer's wallet by the deposited amount.
        _increase_vault_wallet_balance(storage.vault_wallets, PRIVATE_VAULT, amount);

        // @dev - Transfer a given amount of a given token from a payer's wallet to this contract (or, the Vault contract). 
        token.transfer_private_to_private(from, PRIVATE_VAULT, amount, 0).call(&mut context);
    }

    /// @dev - Withdraw a given payment ID of the funds-deposited from a payer's private wallet
    #[external("private")]
    fn withdraw(
        token_contract_address: AztecAddress,
        to: AztecAddress,
        amount: u128,
    ) {
        // @dev - Create the contract instance of the PrivateVault contract
        let private_vault = PrivateVault::at(context.this_address());

        // @dev - Create the contract instance of the Token contract
        let token = Token::at(storage.token_contract_address.read());

        // @dev - Store the PrivateVault contract address into a variable
        let PRIVATE_VAULT = context.this_address();

        // @dev - Decrease the private balance of the payer's wallet by the withdrawn amount.
        // _decrease_vault_wallet_balance(
        //     &mut context,
        //     storage.vault_wallets, 
        //     PRIVATE_VAULT, 
        //     amount,
        //     INITIAL_TRANSFER_CALL_MAX_NOTES,
        // );

        // @dev - Transfer a given amount of a given token from this vault contract to a payer's wallet. 
        token.transfer_private_to_private(PRIVATE_VAULT, to, amount, 0).call(&mut context);
    }

    /// @dev Retrieves the owner of the contract
    /// @return The owner of the contract
    #[external("public")]
    #[view]
    fn get_admin() -> AztecAddress {
        storage.admin.read()
    }


    /*******************************************
    *   @notice - Contract Library functions   *
    ********************************************/
    /// @notice Updates the given storage pointer `wallets` to increase the (private) balance of `to` wallet by `amount`
    /// @param wallets - The storage pointer to the wallets, which includes the private balances
    /// @param to The address of the recipient
    /// @param amount The amount of tokens to increase the balance by
    #[contract_library_method]
    fn _increase_vault_wallet_balance(
        vault_wallets: Map<AztecAddress, VaultWalletSet<&mut PrivateContext>, &mut PrivateContext>,
        to: AztecAddress,
        amount: u128,
    ) {
        // Increases `amount` to the private balance of `to`, and emits a private balance note to `to` from `from`
        vault_wallets.at(to).add(to, amount).emit(to, MessageDelivery.CONSTRAINED_ONCHAIN);
    }

    /// @notice Decreases the private balance of `account` by `amount` and emits a private balance note with the change to account
    /// @param context The private context
    /// @param private_balances The storage pointer to the private balances
    /// @param account The address of the account to decrease the balance of
    /// @param amount The amount of tokens to decrease the balance by
    /// @param max_notes The maximum number of notes to process in a single call
    #[contract_library_method]
    fn _decrease_vault_wallet_balance(
        context: &mut PrivateContext,
        vault_wallets: Map<AztecAddress, VaultWalletSet<&mut PrivateContext>, &mut PrivateContext>,
        account: AztecAddress,
        amount: u128,
        max_notes: u32,
    ) {
        // Subtracts `amount` from the private balance of `account`
        let change = _subtract_balance(context, vault_wallets, account, amount, max_notes);
        // Increases `change` to the private balance of `account`, and emits a private balance note to account
        vault_wallets.at(account).add(account, change).emit(
            account,
            MessageDelivery.CONSTRAINED_ONCHAIN,
        );
    }

    /// @notice Subtracts balance from private balance
    /// @dev Subtracts amount from private balance and returns the change to the owner, recursively if necessary
    /// @param context The private context
    /// @param private_balances The storage pointer to the private balances
    /// @param account The address of the account to subtract the balance from
    /// @param amount The amount of tokens to subtract
    /// @param max_notes The maximum number of notes to process in a single call
    /// @return The change to return to the owner
    #[contract_library_method]
    fn _subtract_balance(
        context: &mut PrivateContext,
        vault_wallets: Map<AztecAddress, VaultWalletSet<&mut PrivateContext>, &mut PrivateContext>,
        account: AztecAddress,
        amount: u128,
        max_notes: u32,
    ) -> u128 {
        let subtracted = vault_wallets.at(account).try_sub(amount, max_notes);
        if subtracted >= amount {
            // We have achieved our goal of nullifying notes that add up to more than amount, so we return the change.
            subtracted - amount
        } else {
            // Failing to subtract any amount means that the owner was unable to produce more notes that could be nullified.
            assert(subtracted > 0, "Balance too low");

            // try_sub failed to nullify enough notes to reach the target amount, so we compute the amount remaining
            // and try again.
            let remaining = amount - subtracted;

            // @dev - [TODO]: Add the logic for changing the Token contract's balance.
            // Token::at(context.this_address())
            //     .recurse_subtract_balance_internal(account, remaining)
            //     .call(context)

            remaining
        }
    }
}
