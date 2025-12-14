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
        messages::logs::note,
        note::note_interface::{NoteHash, NoteType},
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
        messages::message_delivery::MessageDelivery
    };

    // @dev - Import note (WalletNote) and custom note struct
    use crate::types::wallet_note::{WalletNote};

    #[storage]
    struct Storage<Context> {
        admin: PublicImmutable<AztecAddress, Context>,
        payment_id: PublicMutable<u128, Context>,  
        wallets: Map<AztecAddress, PrivateMutable<WalletNote, Context>, Context>  // Private wallets: payer => balance
    }

    // @dev - Payment Commitment Note, which the backend will watch (encrypted)
    // #[derive(Eq, Packable)]
    // #[note]
    // @dev - Event
    pub struct PaymentCommitted {
        payment_hash: Field,
        amount: Field,
    }

    // impl PaymentCommitted {
    //     pub fn new(payment_hash: Field, amount: Field) -> Self {
    //         Self { // @dev - "Self" is equivalent to "PaymentCommitted" sturct
    //             payment_hash,
    //             amount,
    //         }
    //     }
    // }


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

    /// @dev - Deposit and increments the payment ID
    #[external("private")]
    pub fn deposit(context: PrivateContext, amount: Field) {
        let payer = context.msg_sender().unwrap();

        let current_balance = storage.wallets.get_balance().at(payer);
        let new_balance = current_balance + amount;

        storage.wallets.get_balance().at(payer).replace(|current_balance| new_balance);
    }

    #[external("private")]
    pub fn authorize_payment(
        mut context: PrivateContext, // @dev - To use "&mut context" in this function. Otherwise, it causes an error: "Cannot mutate immutable variable `context`"
        payment_hash: Field,
        amount: Field,
        event_recipient: AztecAddress,
    ) {
        let x402_private_payment_router = X402PrivatePaymentRouter::at(context.this_address());

        // @dev - Create the payer instance, which the msg_sender is stored.
        let payer: AztecAddress = context.msg_sender().unwrap();
        //let msg_sender: AztecAddress = context.msg_sender().unwrap();

        // @dev - Check if the payer has sufficient balance 
        let current_balance = storage.wallets.get_balance().at(payer);
        //assert_gt(current_balance, amount, "insufficient funds");

        let new_balance = current_balance - amount;

        //assert(new_balance >= 0, "balance underflow");
        assert_eq(payer, storage.wallets.get_owner().at(payer), "unauthorized wallet access");
        let new_wallet_note = WalletNote::new(payer, new_balance);

        storage.wallets.get_balance().at(payer).replace(|current_balance| new_balance).emit(payer, MessageDelivery.CONSTRAINED_ONCHAIN);

        // @dev - Public function: The payment_id is incremented internally.
        x402_private_payment_router.increment_payment_id().enqueue(&mut context); // @dev - enqueue() method should be used for a "public" function called inside the private function.

        // @dev - Emit event in private
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
}








// pub contract Counter {
//     // @param owner The address of the owner
//     // @param counter A numerical value
//     #[storage]
//     struct Storage<Context> {
//         owner: PublicImmutable<AztecAddress, Context>,
//         counter: PublicMutable<u128, Context>,
//     }
//
//     /// @dev Initialize the contract
//     /// @param owner The address of the owner
//     #[external("public")]
//     #[initializer]
//     fn constructor(owner: AztecAddress) {
//         storage.owner.initialize(owner);
//     }
//
//     /// @dev Retrieves the owner of the contract
//     /// @return The owner of the contract
//     #[external("public")]
//     fn get_owner() -> AztecAddress {
//         storage.owner.read()
//     }
//
//     /// @dev Increments the counter
//     #[external("private")]
//     fn increment() {
//         Counter::at(context.this_address()).increment_internal().enqueue(&mut context);
//     }
//
//     /// @dev Retrieves the counter value
//     /// @return The current counter value
//     #[external("public")]
//     #[view]
//     fn get_counter() -> u128 {
//         storage.counter.read()
//     }
//
//     /// @dev Increments the counter
//     #[external("public")]
//     #[internal]
//     fn increment_internal() {
//         let current_value = storage.counter.read();
//         storage.counter.write(current_value + 1);
//     }
// }