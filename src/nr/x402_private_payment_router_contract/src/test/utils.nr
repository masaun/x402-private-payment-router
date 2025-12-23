use crate::X402PrivatePaymentRouter;
use aztec::{
    protocol_types::address::AztecAddress, test::helpers::test_environment::TestEnvironment,
};

pub unconstrained fn setup_contract(
    with_account_contracts: bool,
) -> (&mut TestEnvironment, AztecAddress, AztecAddress, AztecAddress) {
    // Setup env, generate keys
    let mut env = TestEnvironment::new();
    let (owner, payer) = if with_account_contracts {
        let owner = env.create_contract_account();
        let payer = env.create_contract_account();
        (owner, payer)
    } else {
        let owner = env.create_light_account();
        let payer = env.create_light_account();
        (owner, payer)
    };

    let contract_address = deploy_x402_private_payment_router_contract(&mut env, owner);

    (&mut env, contract_address, owner, payer)
}

pub unconstrained fn deploy_x402_private_payment_router_contract(
    env: &mut TestEnvironment,
    owner: AztecAddress,
) -> AztecAddress {
    let initializer_call_interface = X402PrivatePaymentRouter::interface().constructor(owner);
    let contract_address =
        env.deploy("X402PrivatePaymentRouter").with_public_initializer(owner, initializer_call_interface);

    contract_address
}
