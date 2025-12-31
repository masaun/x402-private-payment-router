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

/** =================================================== *
 *  LOGIC LIBRARIES for the #[contract_library_method]  *
 * ==================================================== */

#[contract_library_method]
pub fn create_private_contract_instances(
    x402_private_payment_router_contract_address: AztecAddress,
    token_contract_address: AztecAddress,
    private_vault_contract_address: AztecAddress,
) -> (ContractInstance, ContractInstance, ContractInstance) {
    // @dev - Create the contract instance of the X402PrivatePaymentRouter contract
    let x402_private_payment_router: ContractInstance = get_contract_instance(x402_private_payment_router_contract_address);

    // @dev - Create the contract instance of the X402PrivatePaymentRouter contract
    let private_vault: ContractInstance = get_contract_instance(private_vault_contract_address);

    // @dev - Create the contract instance of the Token contract
    let token: ContractInstance = get_contract_instance(token_contract_address);

    (x402_private_payment_router, private_vault, token)
}