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
    event::{
        event_emission::emit_event_in_private,
        event_selector::EventSelector,
        event_interface::EventInterface,
    },
    messages::message_delivery::MessageDelivery
};


/*******************************
 *   @notice - Event structs   *
 *******************************/
global PAYMENT_COMMITTED_LEN: u32 = 2;

// @dev - Event: PaymentCommitted event, which the backend will watch (encrypted)
pub struct PaymentCommitted {
    pub payment_hash: Field,
    pub amount: u128,
}

// @dev - Implement Serialize for the PaymentCommitted event
impl Serialize for PaymentCommitted {
    type N = PAYMENT_COMMITTED_LEN;

    fn serialize(self) -> [Field; PAYMENT_COMMITTED_LEN] { // @dev - [Field; 2] is expected to be returned.
        [self.payment_hash, self.amount as Field]          // @dev - Since the return type is [Field; 2], we convert u128 to Field (for a given "amount").
    }
}

// Implement EventInterface for the PaymentCommitted event
impl EventInterface for PaymentCommitted {
    fn get_event_type_id() -> EventSelector {
        // The string must match your event's name and field types
        EventSelector::from_signature("PaymentCommitted(Field,Field)")
    }
}