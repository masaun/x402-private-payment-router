use crate::{Counter, test::utils};

// @dev - Import debug logging
use dep::aztec::oracle::debug_log::{ debug_log, debug_log_format };

#[test]
unconstrained fn increment_success() {
    let (env, contract_address, owner, _) = utils::setup_contract(false);

    env.call_private(owner, Counter::at(contract_address).increment());

    let counter = env.view_public(Counter::at(contract_address).get_counter());
    assert(counter == 1);

    // @dev - Logging the simple messages
    let test_message = "-------------- This is the test message!!! --------------";
    debug_log(test_message);
}

#[test]
unconstrained fn does_it_fail_to_call_the_initializer() {
    let mut env = aztec::test::helpers::test_environment::TestEnvironment::new();

    let owner = env.create_light_account();

    let initializer_call_interface = Counter::interface().constructor(owner);
    let counter_deployer = env.deploy("@counter_contract/Counter");
    let contract_address =
        counter_deployer.with_public_initializer(owner, initializer_call_interface);

    env.call_private(owner, Counter::at(contract_address).increment());

    let counter = env.view_public(Counter::at(contract_address).get_counter());
    assert(counter == 1);

    // @dev - Log simple messages
    debug_log("checkpoint reached");

    // @dev - Log field values with context
    //debug_log_format("counter_deployer:{0}, contract_address:{1}", [counter_deployer, contract_address]);

    // @dev - Log single field
    //debug_log_field(my_field);
}
