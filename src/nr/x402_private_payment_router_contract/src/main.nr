use aztec::macros::aztec;
pub mod test;

#[aztec]
pub contract X402PrivatePaymentRouter {
    // aztec library imports
    use aztec::{
        macros::{
            functions::{external, internal, view, initializer }, 
            storage::storage,
            notes::{
                note,
                custom_note
            },
        },
        protocol_types::{
            address::AztecAddress,
            traits::{Packable, ToField}
        },
        event::event_emission::emit_event_in_private,
        state_vars::{
            PublicImmutable, PublicMutable, DelayedPublicMutable,
            PrivateImmutable, PrivateMutable, PrivateSet, 
            Map
        },
        oracle::random::random,
        messages::message_delivery::MessageDelivery
    };

    #[storage]
    struct Storage<Context> {
        admin: PublicMutable<AztecAddress, Context>,
        wallets: Map<AztecAddress, PublicMutable<Field, Context>, Context>  // Private wallets: payer => balance
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

    #[external("private")]
    pub fn deposit(payer: AztecAddress, amount: Field) {
        let current_balance = storage.wallets.at(payer).get_note();
        let new_balance = current_balance + amount;

        storage.wallets.at(payer).replace(|current_balance| new_balance);
    }

    #[external("private")]
    pub fn authorize_payment(
        payer: AztecAddress,
        payment_hash: Field,
        amount: Field,
        event_recipient: AztecAddress,
    ) {
        // check sender owns wallet
        let current_wallet_note = storage.wallets.at(payer).get_note();
        assert(current_wallet_note >= amount, "insufficient funds");

        let new_wallet_note = PaymentCommitted::new(payment_hash, amount);
        let new_balance = current_wallet_note - amount;
        
        storage.wallets.at(payer).replace(|current_wallet_note| new_wallet_note).emit(msg_sender, MessageDelivery.CONSTRAINED_ONCHAIN);

        // @dev - Emit event in private
        emit_event_in_private(
            PaymentCommitted { payment_hash, amount },
            &mut context,
            event_recipient,
            MessageDelivery.UNCONSTRAINED_ONCHAIN,
        );
        //PaymentCommitted { payment_hash, amount }.emit();
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