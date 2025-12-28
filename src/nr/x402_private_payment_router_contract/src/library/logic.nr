// @dev - Aztec library
use aztec::{
    context::PrivateContext,
    event::event_emission::emit_event_in_private,
    messages::message_delivery::MessageDelivery,
    oracle::get_contract_instance::get_contract_instance,
    protocol_types::{
        address::AztecAddress,
        contract_instance::ContractInstance,
        public_keys::{IvpkM, NpkM, OvpkM, PublicKeys, TpkM},
        traits::ToField,
    },
};

// @dev - X402PrivatePaymentRouter contract
use X402PrivatePaymentRouter;

/** =================================================== *
 *  LOGIC LIBRARIES for the #[contract_library_method]  *
 * ==================================================== */

// #[contract_library_method]