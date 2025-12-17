use aztec::macros::aztec;

pub mod types;
//pub mod test; // [NOTE]: Temporarily commented out to avoid compilation error.

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
    //use crate::types::payment_committed_event::{PaymentCommitted};

    /*********************************
    *   @notice - Global constants   *
    *********************************/
    // gas-optimized max notes for initial transfer call
    global INITIAL_TRANSFER_CALL_MAX_NOTES: u32 = 2;

    /******************************
    *   @notice - Event structs   *
    *******************************/
    // @dev - Define the PaymentCommitted event to be called in the private function.
    // @dev - [NOTE]: Since the PaymentCommitted event is called in the private function, the PaymentCommitted event must be defined inside this contract. (It can not be imported from the types module)
    struct PaymentCommitted {
        payment_hash: Field,
        amount: Field,
    }

    // @dev - Implement Serialize for the PaymentCommitted event
    global PAYMENT_COMMITTED_LEN: u32 = 2;
    impl Serialize for PaymentCommitted {
        type N = PAYMENT_COMMITTED_LEN;

        fn serialize(self) -> [Field; PAYMENT_COMMITTED_LEN] { // @dev - [Field; 2] is expected to be returned.
            [self.payment_hash, self.amount]
        }
    }

    // Implement EventInterface for the PaymentCommitted event
    impl EventInterface for PaymentCommitted {
        fn get_event_type_id() -> EventSelector {
            // The string must match your event's name and field types
            EventSelector::from_signature("PaymentCommitted(Field,Field)")
        }
    }

    #[storage]
    struct Storage<Context> {
        admin: PublicImmutable<AztecAddress, Context>,
        payment_id: PublicMutable<u128, Context>,  
        //wallets: Map<AztecAddress, PrivateMutable<WalletNote, Context>, Context>  // Private wallets: payer => balance
        wallets: Map<AztecAddress, WalletSet<Context>, Context>,                    // Private wallets: payer => balances
    }

    /// @dev Initialize the contract
    /// @param owner The address of the owner
    #[external("public")]
    #[initializer]
    fn constructor(_admin: AztecAddress) {
        storage.admin.initialize(_admin);
    }

    /// @dev Retrieves the owner of the contract
    /// @return The owner of the contract
    #[external("public")]
    fn get_admin() -> AztecAddress {
        storage.admin.read()
    }

    /// @dev - Deposit a given amount of funds into a payer's private wallet + Increments the payment ID
    #[external("private")]
    fn deposit(
        to: AztecAddress,
        amount: u128,
    ) {
        let x402_private_payment_router = X402PrivatePaymentRouter::at(context.this_address());

        let payer = context.msg_sender().unwrap();

        // @dev - Increase the private balance of the payer's wallet by the deposited amount.
        _increase_wallet_balance(storage.wallets, to, amount);
    }

    /// @dev - Withdraw a given payment ID of the funds-deposited from a payer's private wallet
    #[external("private")]
    fn withdraw(
        from: AztecAddress,
        amount: u128,
    ) {
        let x402_private_payment_router = X402PrivatePaymentRouter::at(context.this_address());

        let payer = context.msg_sender().unwrap();

        // @dev - Increase the private balance of the payer's wallet by the deposited amount.
        _decrease_wallet_balance(
            &mut context,
            storage.wallets, 
            from, 
            amount,
            INITIAL_TRANSFER_CALL_MAX_NOTES,
        );
    }

    #[external("private")]
    fn authorize_payment(
        payment_hash: Field,
        amount: Field,
        event_recipient: AztecAddress,
    ) {
        let x402_private_payment_router = X402PrivatePaymentRouter::at(context.this_address());

        // @dev - Create the payer instance, which the msg_sender is stored.
        let payer: AztecAddress = context.msg_sender().unwrap();
        //let msg_sender: AztecAddress = context.msg_sender().unwrap();

        // @dev - Fetch the wallet note of the payer from the storage mapping.
        //let current_wallet_note = storage.wallets.at(payer).get_note().content;
        //let current_wallet_note = x402_private_payment_router.get_wallet_note(payer).return_type();

        // @dev - Check if the payer has sufficient balance 
        //let current_balance = current_wallet_note.balance;
        //let current_balance = current_wallet_note.get_balance();

        //let new_balance = current_balance - amount;
        
        //let new_wallet_note = WalletNote::new(payer, new_balance);

        //storage.wallets.at(payer).replace(|current_wallet_note| new_wallet_note).emit(payer, MessageDelivery.CONSTRAINED_ONCHAIN);

        // @dev - Public function: The payment_id is incremented internally.
        x402_private_payment_router.increment_payment_id().enqueue(&mut context); // @dev - enqueue() method should be used for a "public" function called inside the private function.

        // @dev - Emit the PaymentCommitted event in private
        emit_event_in_private(
            PaymentCommitted { payment_hash, amount },
            &mut context, // @dev - [NOTE]: Cannot mutate immutable variable `context`
            event_recipient,
            MessageDelivery.UNCONSTRAINED_ONCHAIN,
        );
        //PaymentCommitted { payment_hash, amount }.emit();
    }

    /// @dev Retrieves the current payment ID
    /// @dev - This return value can be retrieved on FE - since the "payment_id" is a PublicMutable variable.
    /// @return The current payment ID
    #[external("public")]
    #[view]
    fn get_payment_id() -> u128 {
        storage.payment_id.read()
    }

    /// @dev - Increments the payment ID
    #[external("public")] // @dev - [NOTE]: .write()/.read() methods can be used in "public" functions.
    #[internal]
    fn increment_payment_id() {
        let current_payment_id: u128 = storage.payment_id.read();
        storage.payment_id.write(current_payment_id + 1)
    }

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



    /// @dev - Retrieves the wallet note for a given payer
    /// @dev - [NOTE]: Basically, the return value of the private functions should be seen by anoone. Hence, "view" function should be defined for a private function.
    // #[external("private")]
    // #[view]
    // //fn get_wallet_note(payer: AztecAddress) -> OuterNoteEmission<UintNote> {
    // fn get_wallet_note(payer: AztecAddress) -> WalletNote {
    //     storage.wallets.at(payer).get_note()
    // }
}