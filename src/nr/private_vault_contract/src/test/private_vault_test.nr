use crate::{
    PrivateVault, 
    test::utils::{self, mint_amount}
};
use aztec::{
    note::constants::MAX_NOTES_PER_PAGE, 
    test::helpers::authwit as authwit_cheatcodes,
    oracle::debug_log::{ debug_log, debug_log_format }
};
use uint_note::uint_note::{UintNote};
use token::Token; // @dev - Import the Token contract (token_contract/src/main.nr)


#[test]
unconstrained fn deposit_success() {
    let (env, private_vault_contract_address, token_contract_address, admin, payer) = utils::setup_contract(false);

    let token = Token::at(token_contract_address);
    let amount = 1000 as u128;

    // @dev - Call the deposit() function
    env.call_private(admin, PrivateVault::at(private_vault_contract_address).deposit(token_contract_address, payer, amount));

    //let private_vault = env.view_public(PrivateVault::at(contract_address).get_admin());
    //assert(private_vault == 1);

    // @dev - Logging the simple messages
    let test_message = "-------------- This is the test of the deposit() --------------";
    debug_log(test_message);
}

#[test]
unconstrained fn withdraw_success() {
    // [TODO]:
}

#[test]
unconstrained fn does_it_fail_to_call_the_initializer() {
    // let mut env = aztec::test::helpers::test_environment::TestEnvironment::new();

    // let admin = env.create_light_account();

    // let initializer_call_interface = PrivateVault::interface().constructor(admin);
    // let private_vault_deployer = env.deploy("@private_vault_contract/PrivateVault");
    // let contract_address =
    //     private_vault_deployer.with_public_initializer(admin, initializer_call_interface);

    // //env.call_private(owner, PrivateVault::at(contract_address).increment());
    // //let private_vault = env.view_public(PrivateVault::at(contract_address).get_counter());
    // //assert(private_vault == 1);

    // // @dev - Log simple messages
    // debug_log("checkpoint reached");

    // // @dev - Log field values with context
    // //debug_log_format("counter_deployer:{0}, contract_address:{1}", [counter_deployer, contract_address]);

    // // @dev - Log single field
    // //debug_log_field(my_field);
}
