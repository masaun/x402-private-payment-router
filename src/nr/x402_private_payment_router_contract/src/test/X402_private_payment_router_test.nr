use crate::{X402PrivatePaymentRouter, test::utils};

// [TODO]: Rewrite the test for the X402PrivatePaymentRouter contract.
#[test]
unconstrained fn increment_success() {
    let (env, contract_address, owner, _) = utils::setup_contract(false);

    env.call_private(owner, X402PrivatePaymentRouter::at(contract_address).increment());

    let X402_private_payment_router = env.view_public(X402PrivatePaymentRouter::at(contract_address).get_counter());
    assert(X402_private_payment_router == 1);
}

#[test]
unconstrained fn does_it_fail_to_call_the_initializer() {
    let mut env = aztec::test::helpers::test_environment::TestEnvironment::new();

    let owner = env.create_light_account();

    let initializer_call_interface = X402PrivatePaymentRouter::interface().constructor(owner);
    let X402_private_payment_router_deployer = env.deploy("@X402_private_payment_router_contract/X402PrivatePaymentRouter");
    let contract_address =
        X402_private_payment_router_deployer.with_public_initializer(owner, initializer_call_interface);

    env.call_private(owner, X402PrivatePaymentRouter::at(contract_address).increment());
    let X402_private_payment_router = env.view_public(X402PrivatePaymentRouter::at(contract_address).get_counter());
    assert(X402_private_payment_router == 1);
}
