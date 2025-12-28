use aztec::macros::aztec;

pub mod types;
pub mod test;

#[aztec]
pub contract X402PrivatePaymentRouter {
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

    // @dev - Import the PrivateVault contract (private_vault_contract/src/main.nr)
    use private_vault::PrivateVault;

    // @dev - Import the Token contract (token_contract/src/main.nr)
    use token::{Token};

    // @dev - Import the Note library
    use uint_note::uint_note::{UintNote, PartialUintNote};

    // @dev - Import the compression library
    use compressed_string::FieldCompressedString;

    // @dev - Import the contract instance registry
    use contract_instance_registry::ContractInstanceRegistry;

    // @dev - Import the note struct or/and the custom note struct
    //use crate::types::wallet_note::{WalletNote};

    // @dev - Import the note struct or/and the custom note struct
    use crate::types::wallet_set::{WalletSet};

    // @dev - Import the PaymentCommitted event struct from the types module.
    use crate::types::payment_committed_event::{PaymentCommitted};

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
        payment_id: PublicMutable<u128, Context>,  
        //wallets: Map<AztecAddress, PrivateMutable<WalletNote, Context>, Context>  // Private wallets: payer => balance
        wallets: Map<AztecAddress, WalletSet<Context>, Context>,                    // Private wallets: payer => balances
    }

    /****************************
    *   @notice - Constructor   *
    ****************************/
    /// @dev Initialize the contract
    /// @param owner The address of the owner
    #[external("public")]
    #[initializer]
    fn constructor(_admin: AztecAddress) {
        storage.admin.initialize(_admin);
    }

    /*******************************
    *   @notice - Main functions   *
    *******************************/

    /// @dev - Deposit a given amount of funds into a payer's private wallet + Increments the payment ID
    #[external("private")]
    fn deposit(
        token_contract_address: AztecAddress,
        private_vault_contract_address: AztecAddress,
        amount: u128,
    ) {
        // @dev - Create the contract instance of the X402PrivatePaymentRouter contract
        let x402_private_payment_router = X402PrivatePaymentRouter::at(context.this_address());

        // @dev - Create the contract instance of the X402PrivatePaymentRouter contract
        let private_vault = PrivateVault::at(private_vault_contract_address);

        // @dev - Create the contract instance of the Token contract
        let token = Token::at(token_contract_address);

        // @dev - Store the x402PrivatePaymentRouter contract address into a variable
        let X402_PRIVATE_PAYMENT_ROUTER = context.this_address();

        // @dev - Store the PrivateVault contract address into a variable
        let PRIVATE_VAULT = private_vault_contract_address;

        // @dev - Store the Token contract address into a variable
        let TOKEN = token_contract_address;

        // @dev - Store the payer address into the payer variables
        let payer = context.msg_sender().unwrap();

        // @dev - Increase the private balance of the payer's wallet by the deposited amount.
        _increase_wallet_balance(storage.wallets, payer, amount);

        // @dev - Directly transfer a given amount of a given token from a payer's wallet to the PrivateVault contract.
        // @dev - [NOTE]: Instead of internally calling the PrivateVault#deposit() inside the X402PrivatePaymentRouter#deposit(), we directly call the Token#transfer_private_to_private() inside the X402PrivatePaymentRouter#deposit() - This is because the notes created in a transaction aren't available to spend in the same transaction in Aztec Network. (This is only for a private function)
        token.transfer_private_to_private(payer, PRIVATE_VAULT, amount, 0).call(&mut context);
    }

    /// @dev - Withdraw a given payment ID of the funds-deposited from a payer's private wallet
    #[external("private")]
    fn withdraw(
        token_contract_address: AztecAddress,
        private_vault_contract_address: AztecAddress,
        from: AztecAddress,
        amount: u128,
    ) {
        // @dev - Create the contract instance of the X402PrivatePaymentRouter contract
        let x402_private_payment_router = X402PrivatePaymentRouter::at(context.this_address());

        // @dev - Create the contract instance of the X402PrivatePaymentRouter contract
        let private_vault = PrivateVault::at(private_vault_contract_address);

        // @dev - Create the contract instance of the Token contract
        let token = Token::at(token_contract_address);

        // @dev - Store the x402PrivatePaymentRouter contract address into a variable
        let X402_PRIVATE_PAYMENT_ROUTER = context.this_address();

        // @dev - Store the PrivateVault contract address into a variable
        let PRIVATE_VAULT = private_vault_contract_address;

        // @dev - Store the Token contract address into a variable
        let TOKEN = token_contract_address;

        // @dev - Store the payer address into the payer variables
        let payer = context.msg_sender().unwrap();

        // @dev - Decrease the private balance of the payer's wallet by the withdrawn amount.
        _decrease_wallet_balance(
            &mut context,
            storage.wallets, 
            from, 
            amount,
            INITIAL_TRANSFER_CALL_MAX_NOTES,
        );

        // @dev - Withdraw a given amount of a given token from the PrivateVault contract to this contract.
        private_vault
            .withdraw(TOKEN, X402_PRIVATE_PAYMENT_ROUTER, amount)
            .call(&mut context);

        // @dev - Transfer a given amount of a given token from this X402PrivatePaymentRouter contract to a given payer's wallet. 
  token
            .transfer_private_to_private(X402_PRIVATE_PAYMENT_ROUTER, payer, amount, 0)
            .call(&mut context);
    }

    // @dev - Settle a private payment from a payer to a payee
    #[external("private")]
    fn settle_payment(
        token_contract_address: AztecAddress,
        private_vault_contract_address: AztecAddress,
        payee: AztecAddress,
        payment_hash: Field,
        token: AztecAddress,
        amount: u128,
        event_recipient: AztecAddress,
    ) {
        // @dev - Create the contract instance of the X402PrivatePayment contract
        let x402_private_payment_router = X402PrivatePaymentRouter::at(context.this_address());

        // @dev - Create the contract instance of the X402PrivatePaymentRouter contract
        let private_vault = PrivateVault::at(private_vault_contract_address);

        // @dev - Create the contract instance of the Token contract
        let token = Token::at(token_contract_address);

        // @dev - Store the x402PrivatePaymentRouter contract address into a variable
        let X402_PRIVATE_PAYMENT_ROUTER = context.this_address();

        // @dev - Store the PrivateVault contract address into a variable
        let PRIVATE_VAULT = private_vault_contract_address;

        // @dev - Store the Token contract address into a variable
        let TOKEN = token_contract_address;

        // @dev - Create the payer instance, which the msg_sender is stored.
        let payer: AztecAddress = context.msg_sender().unwrap();
    
        // @dev - Decrease the private balance of the payer's wallet by the withdrawn amount. (= This is similar to decreasing an internal balance of a mapping storage).
        _decrease_wallet_balance(
            &mut context,
            storage.wallets, 
            payer, 
            amount,
            INITIAL_TRANSFER_CALL_MAX_NOTES,
        );

        // @dev - Increase the private balance of the payee's wallet. (= This is similar to increasing an internal balance of a mapping storage)
        //_increase_wallet_balance(storage.wallets, payee, amount);

        // @dev - At the first step, withdrawing a given amount of a given token from the PrivateVault contract to this X402PrivatePaymentRouter contract.
        private_vault
            .withdraw(TOKEN, X402_PRIVATE_PAYMENT_ROUTER, amount)
            .call(&mut context);

        // @dev - At the second step, transfering a given amount of a given token from this X402PrivatePaymentRouter contract to a given payee's wallet. 
        token
            .transfer_private_to_private(X402_PRIVATE_PAYMENT_ROUTER, payee, amount, 0)
            .call(&mut context);

        // @dev - Public function: The payment_id is incremented internally.
        x402_private_payment_router.increment_payment_id().enqueue(&mut context); // @dev - enqueue() method should be used for a "public" function called inside the private function.

        // @dev - Emit the PaymentCommitted event in private
        emit_event_in_private(
            PaymentCommitted { payment_hash, amount },
            &mut context, // @dev - [NOTE]: Cannot mutate immutable variable `context`
            event_recipient,
            MessageDelivery.UNCONSTRAINED_ONCHAIN,
        );
    }

    /// @dev - Increments the payment ID
    #[external("public")] // @dev - [NOTE]: .write()/.read() methods can be used in "public" functions.
    #[internal]
    fn increment_payment_id() {
        let current_payment_id: u128 = storage.payment_id.read();
        storage.payment_id.write(current_payment_id + 1)
    }

    /// @dev Retrieves the owner of the contract
    /// @return The owner of the contract
    #[external("public")]
    #[view]
    fn get_admin() -> AztecAddress {
        storage.admin.read()
    }

    /// @dev Retrieves the current payment ID
    /// @dev - This return value can be retrieved on FE - since the "payment_id" is a PublicMutable variable.
    /// @return The current payment ID
    #[external("public")]
    #[view]
    fn get_payment_id() -> u128 {
        storage.payment_id.read()
    }


    /*******************************************
    *   @notice - Contract Library functions   *
    ********************************************/

    /// @notice Updates the given storage pointer `wallets` to increase the (private) balance of `to` wallet by `amount`
    /// @param wallets - The storage pointer to the wallets, which includes the private balances
    /// @param to The address of the recipient
    /// @param amount The amount of tokens to increase the balance by
    #[contract_library_method]
    fn _increase_wallet_balance(
        wallets: Map<AztecAddress, WalletSet<&mut PrivateContext>, &mut PrivateContext>,
        to: AztecAddress,
        amount: u128,
    ) {
        // Increases `amount` to the private balance of `to`, and emits a private balance note to `to` from `from`
        wallets.at(to).add(to, amount).emit(to, MessageDelivery.CONSTRAINED_ONCHAIN);
    }

    /// @notice Decreases the private balance of `account` by `amount` and emits a private balance note with the change to account
    /// @param context The private context
    /// @param private_balances The storage pointer to the private balances
    /// @param account The address of the account to decrease the balance of
    /// @param amount The amount of tokens to decrease the balance by
    /// @param max_notes The maximum number of notes to process in a single call
    #[contract_library_method]
    fn _decrease_wallet_balance(
        context: &mut PrivateContext,
        wallets: Map<AztecAddress, WalletSet<&mut PrivateContext>, &mut PrivateContext>,
        account: AztecAddress,
        amount: u128,
        max_notes: u32,
    ) {
        // Subtracts `amount` from the private balance of `account`
        let change = _subtract_balance(context, wallets, account, amount, max_notes);
        // Increases `change` to the private balance of `account`, and emits a private balance note to account
        wallets.at(account).add(account, change).emit(
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
        wallets: Map<AztecAddress, WalletSet<&mut PrivateContext>, &mut PrivateContext>,
        account: AztecAddress,
        amount: u128,
        max_notes: u32,
    ) -> u128 {
        let subtracted = wallets.at(account).try_sub(amount, max_notes);
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

    // @dev - Deposit a given amount of a given token from this X402PrivatePaymentRouter contract to the PrivateVault contract.
    #[contract_library_method]
    fn _deposit_from_x402_private_payment_router_to_private_vault(
        x402_private_payment_router_contract_address: AztecAddress,
        private_vault_contract_address: AztecAddress,
        token_contract_address: AztecAddress,
        amount: u128,
        context: &mut PrivateContext
    ) {
        // @dev - Create the contract instance of the X402PrivatePayment contract
        let x402_private_payment_router = X402PrivatePaymentRouter::at(x402_private_payment_router_contract_address);

        // @dev - Create the contract instance of the X402PrivatePaymentRouter contract
        let private_vault = PrivateVault::at(private_vault_contract_address);

        // @dev - Create the contract instance of the Token contract
        let token = Token::at(token_contract_address);

        // @dev - Store the x402PrivatePaymentRouter contract address into a variable
        let X402_PRIVATE_PAYMENT_ROUTER = context.this_address();

        // @dev - Store the PrivateVault contract address into a variable
        let PRIVATE_VAULT = private_vault_contract_address;

        // @dev - Store the Token contract address into a variable
        let TOKEN = token_contract_address;

        private_vault
            .deposit(TOKEN, X402_PRIVATE_PAYMENT_ROUTER, amount)
            .call(context);
    }
}