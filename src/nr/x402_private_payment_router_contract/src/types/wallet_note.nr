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


/****************************************
 *   @notice - Notes and Custom Notes   *
 ****************************************/
#[derive(Eq, Serialize, Packable)]
#[note]
pub struct WalletNote {
    owner: AztecAddress,
    balance: Field
}

impl WalletNote {
    pub fn new(owner: AztecAddress, balance: Field) -> Self {
        Self {  // "Self" is equivalent to "WalletNote" struct
            owner,
            balance,
        }
    }

    pub fn get_owner(self: WalletNote) -> AztecAddress {
        self.owner
    }

    pub fn get_balance(self: WalletNote) -> Field {
        self.balance
    }
}