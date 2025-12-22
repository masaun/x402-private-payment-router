use crate::{
    X402PrivatePaymentRouter, 
    test::utils::{self, mint_amount}
};
use aztec::{
    note::constants::MAX_NOTES_PER_PAGE, 
    protocol_types::address::AztecAddress,
    test::helpers::{
        authwit as authwit_cheatcodes,
        test_environment::TestEnvironment,
    },
    oracle::debug_log::{ 
        debug_log,
        debug_log_format,
        debug_log_format_slice,
        debug_log_format_with_level,
        debug_log_with_level,
    }    
};
use uint_note::uint_note::{UintNote};

// @dev - Import the Token contract (token_contract/src/main.nr)
use token::{
    Token,
    test::utils::{self, mint_amount}
};


/**
 * @notice - The smart contract test for the deposit() of the X402PrivatePaymentRouter contract
 */
#[test]
unconstrained fn deposit_success() {
    // @dev - Call the X402PrivatePaymentRouter#deposit() to deposit a given amount of the Token into the X402PrivatePaymentRouter contract
    let (env, private_vault_contract_address, token_contract_address, admin, payer) = call_deposit_function_of_x402_private_payment_router_contract();
}

/**
 * @notice - The smart contract test for the withdraw() of the PrivateVault contract
 */
#[test]
unconstrained fn withdraw_success() {
    // @dev - Call the X402PrivatePaymentRouter#deposit() first to deposit a given amount of the Token into the X402PrivatePaymentRouter contract
    let (
        env, 
        private_vault_contract_address, 
        token_contract_address, 
        admin, 
        payer
    ) = call_deposit_function_of_x402_private_payment_router_contract();

    // @dev - Call the X402PrivatePaymentRouter#withdraw() to withdraw a given amount of the Token from the X402PrivatePaymentRouter contract
    call_withdraw_function_of_x402_private_payment_router_contract(env, private_vault_contract_address, token_contract_address, payer);
}



/*********************************
 *   @notice - Helper functions  *
 *********************************/
 
/**
 * @notice - Helper functions for the X402PrivatePaymentRouter#deposit()
 */
pub unconstrained fn call_deposit_function_of_x402_private_payment_router_contract() -> (TestEnvironment, AztecAddress, AztecAddress, AztecAddress, AztecAddress) {
    // [TODO]:

    // let (env, contract_address, owner, payer) = utils::setup_contract(false);

    // // @dev - Create the X402PrivatePaymentRouter contract instance.
    // let x402_private_payment_router = X402PrivatePaymentRouter::at(contract_address);

    // // @dev - A payer would deposit some amount.
    // let deposited_amount: u128 = 1000;
    // env.call_private(payer, x402_private_payment_router.deposit(deposited_amount));

    // // @dev - Check whether a payment ID was properly incremented.
    // let payment_id = env.view_public(x402_private_payment_router.get_payment_id());
    // assert(payment_id == 1);
}

/**
 * @notice - Helper functions for the X402PrivatePaymentRouter#withdraw()
 */
pub unconstrained fn call_withdraw_function_of_x402_private_payment_router_contract() -> (TestEnvironment, AztecAddress, AztecAddress, AztecAddress, AztecAddress) {
    // [TODO]:
}






/****************************************
 *   @notice - Test in case of failure  *
 ****************************************/

#[test]
unconstrained fn does_it_fail_to_call_the_initializer() {
    // let mut env = aztec::test::helpers::test_environment::TestEnvironment::new();

    // // @dev - Create the X402PrivatePaymentRouter contract instance.
    // let x402_private_payment_router = X402PrivatePaymentRouter::at(contract_address);

    // let owner = env.create_light_account();
    // let payer = env.create_light_account();

    // let initializer_call_interface = X402PrivatePaymentRouter::interface().constructor(owner);
    // let x402_private_payment_router_deployer = env.deploy("@x402_private_payment_router_contract/X402PrivatePaymentRouter");
    // let contract_address =
    //     x402_private_payment_router_deployer.with_public_initializer(owner, initializer_call_interface);

    // // @dev - A payer would deposit some amount.
    // let deposited_amount: u128 = 1000;
    // env.call_private(payer, x402_private_payment_router.deposit(deposited_amount));

    // // @dev - Check whether a payment ID was properly incremented.
    // let payment_id = env.view_public(x402_private_payment_router.get_payment_id());
    // assert(payment_id == 1);
}
