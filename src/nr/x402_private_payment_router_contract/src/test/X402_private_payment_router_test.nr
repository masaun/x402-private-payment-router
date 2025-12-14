use crate::{X402PrivatePaymentRouter, test::utils};

// [TODO]: Rewrite the test for the X402PrivatePaymentRouter contract.
#[test]
unconstrained fn increment_success() {
    let (env, contract_address, owner, payer) = utils::setup_contract(false);

    // @dev - Create the X402PrivatePaymentRouter contract instance.
    let x402_private_payment_router = X402PrivatePaymentRouter::at(contract_address);

    // @dev - A payer would deposit some amount.
    let deposited_amount: u128 = 1000;
    env.call_private(payer, x402_private_payment_router.deposit(deposited_amount));

    // @dev - Check whether a payment ID was properly incremented.
    let payment_id = env.view_public(x402_private_payment_router.get_payment_id());
    assert(payment_id == 1);
}

#[test]
unconstrained fn does_it_fail_to_call_the_initializer() {
    let mut env = aztec::test::helpers::test_environment::TestEnvironment::new();

    // @dev - Create the X402PrivatePaymentRouter contract instance.
    let x402_private_payment_router = X402PrivatePaymentRouter::at(contract_address);

    let owner = env.create_light_account();
    let payer = env.create_light_account();

    let initializer_call_interface = X402PrivatePaymentRouter::interface().constructor(owner);
    let x402_private_payment_router_deployer = env.deploy("@x402_private_payment_router_contract/X402PrivatePaymentRouter");
    let contract_address =
        x402_private_payment_router_deployer.with_public_initializer(owner, initializer_call_interface);

    // @dev - A payer would deposit some amount.
    let deposited_amount: u128 = 1000;
    env.call_private(payer, x402_private_payment_router.deposit(deposited_amount));

    // @dev - Check whether a payment ID was properly incremented.
    let payment_id = env.view_public(x402_private_payment_router.get_payment_id());
    assert(payment_id == 1);
}
