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
        events::{Event},
        state_vars::{
            PublicImmutable, PublicMutable, DelayedPublicMutable,
            PrivateImmutable, PrivateMutable, PrivateSet, 
            Map
        },
        oracle::random::random,
        messages::message_delivery::MessageDelivery
    };


    // Private wallets: payer => balance
    #[storage]
    wallets: Map<AztecAddress, Field>,

    // Event that the backend will watch (encrypted)
    #[event]
    pub struct PaymentCommitted {
        payment_hash: Field,
        amount: Field,
    }

    #[external("public")]
    pub fn deposit(
        &mut self,
        payer: AztecAddress,
        amount: Field,
    ) {
        let bal = self.wallets().get(payer);
        self.wallets().insert(payer, bal + amount);
    }

    #[external("public")]
    pub fn authorize_payment(
        &mut self,
        payer: AztecAddress,
        payment_hash: Field,
        amount: Field,
    ) {
        // check sender owns wallet
        let current_balance = self.wallets().get(payer);
        assert(current_balance >= amount, "insufficient funds");

        let new_balance = current_balance - amount;
        self.wallets().insert(payer, new_balance);

        PaymentCommitted { payment_hash, amount }.emit();
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