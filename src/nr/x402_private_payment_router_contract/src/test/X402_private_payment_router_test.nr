use crate::X402PrivatePaymentRouter;
use crate::test::utils as x402_private_payment_router_utils;
use aztec::{
    note::constants::MAX_NOTES_PER_PAGE, 
    protocol_types::{address::AztecAddress, traits::ToField},
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

// @dev - Import the PrivateVault contract (private_vault_contract/src/main.nr)
use private_vault::{PrivateVault, test::utils as private_vault_utils};

// @dev - Import the Token contract (token_contract/src/main.nr)
use token::{Token, test::utils as token_utils, test::utils::mint_amount};


/**
 * @notice - The smart contract test for the deposit() of the X402PrivatePaymentRouter contract
 */
#[test]
unconstrained fn deposit_success() {
    // @dev - Call the X402PrivatePaymentRouter#deposit() to deposit a given amount of the Token into the X402PrivatePaymentRouter contract
    let (env, x402_private_payment_router_contract_address, private_vault_contract_address, token_contract_address, admin, payer) = call_deposit_function_of_x402_private_payment_router_contract();
}

/**
 * @notice - The smart contract test for the withdraw() of the PrivateVault contract
 */
#[test]
unconstrained fn withdraw_success() {
    // @dev - Call the X402PrivatePaymentRouter#deposit() first to deposit a given amount of the Token into the X402PrivatePaymentRouter contract
    let (
        env, 
        token_contract_address, 
        x402_private_payment_router_contract_address,
        private_vault_contract_address, 
        admin, 
        payer
    ) = call_deposit_function_of_x402_private_payment_router_contract();

    // @dev - Call the X402PrivatePaymentRouter#withdraw() to withdraw a given amount of the Token from the X402PrivatePaymentRouter contract
    call_withdraw_function_of_x402_private_payment_router_contract(
        env, 
        token_contract_address, 
        x402_private_payment_router_contract_address, 
        private_vault_contract_address, 
        payer
    );
}

// unconstrained fn authorized_payment_success() {
//     // // @dev - Check whether a payment ID was properly incremented.
//     // let payment_id = env.view_public(x402_private_payment_router.get_payment_id());
//     // assert(payment_id == 1);
//     // debug_log_format("--------- payment_id: {0} ---------", [payment_id as Field]);
// }



/*********************************
 *   @notice - Helper functions  *
 *********************************/
 
/**
 * @notice - Helper functions for the X402PrivatePaymentRouter#deposit()
 */
pub unconstrained fn call_deposit_function_of_x402_private_payment_router_contract() -> (TestEnvironment, AztecAddress, AztecAddress, AztecAddress, AztecAddress, AztecAddress) {
    let initial_message = "-------------- The initial line of the call_deposit_function_of_x402_private_payment_router_contract() to call the X402PrivatePaymentRouter#deposit()!!! --------------";
    debug_log(initial_message);
    
    // @dev - Setup (Deploy) ALL smart contracts in the SAME TestEnvironment
    // @dev - This is CRITICAL for nested cross-contract calls (X402 -> PrivateVault -> Token) to work in TXE.
    // @dev - Previously, we used token::test::utils::setup_and_mint_to_private_without_minter() which created its own
    // @dev - TestEnvironment, then deployed X402 and PrivateVault on top. This caused the "Function artifact not found"
    // @dev - error because when PrivateVault called Token, TXE couldn't find the Token artifact in the nested context.
    let (mut env, x402_private_payment_router_contract_address, private_vault_contract_address, token_contract_address, admin, payer) = 
        x402_private_payment_router_utils::setup_all_contracts(true);

    // @dev - Debug: Print contract addresses
    debug_log_format("Token contract address: {0}", [token_contract_address.to_field()]);
    debug_log_format("X402 contract address: {0}", [x402_private_payment_router_contract_address.to_field()]);
    debug_log_format("PrivateVault contract address: {0}", [private_vault_contract_address.to_field()]);

    // @dev - Create the contract instance of both contracts the PrivateVault and the Token.
    let token = Token::at(token_contract_address);
    let x402_private_payment_router = X402PrivatePaymentRouter::at(x402_private_payment_router_contract_address);
    let private_vault = PrivateVault::at(private_vault_contract_address);

    // -----------------------------------------------------------------------------------//
    //        Transfer a given amount (transfer_amount) from the admin to the payer       //
    // -----------------------------------------------------------------------------------//
    // @dev - Create the "transferFrom" call interface
    let transfer_amount = (1000 as u128);
    let transfer_private_from_call_interface = token.transfer_private_to_private(admin, payer, transfer_amount, 1);
    authwit_cheatcodes::add_private_authwit_from_call_interface(
        env,
        admin,
        payer,
        transfer_private_from_call_interface,
    );

    // @dev - Transfer tokens using a private call method, which is the new API
    env.call_private(payer, transfer_private_from_call_interface);
    
    // @dev - Get the token balances after the transfer
    let balance_of_admin = token_utils::get_private_balance(env, token_contract_address, admin);
    let balance_of_payer = token_utils::get_private_balance(env, token_contract_address, payer);
    debug_log_format("--------- balance_of_admin: {0} ---------", [balance_of_admin as Field]);
    debug_log_format("--------- balance_of_payer: {0} ---------", [balance_of_payer as Field]);

    // @dev - Check balances
    token_utils::check_private_balance(
        env,
        token_contract_address,
        admin,
        mint_amount - transfer_amount,
    );
    token_utils::check_private_balance(env, token_contract_address, payer, transfer_amount);

    // ---------------------------------------------------------------------//
    //    Calling the deposit() of the X402PrivatePaymentRouter contract    //
    // ---------------------------------------------------------------------//
    let amount_to_be_deposited = (1000 as u128);

    // @dev - [Time Travel]: Advance block to ensure the transfer is processed
    // @dev - Mines an empty block at a given timestamp, causing the next public execution to occur at this time (like `set_next_block_timestamp`), but also allowing for private execution to happen using this empty block as the anchor block.
    let block_timestamp = env.last_block_timestamp() + 3600; // e.g., advance by 1 hour (3600 seconds)
    env.mine_block_at(block_timestamp);

    let token_transfer_message = "-------------- The test of the token.transfer_private_to_private() in the x402_private_payment_router_test.nr has been done!!! --------------";
    debug_log(token_transfer_message);

    // @dev - The X402PrivatePaymentRouter#deposit() internally calls:
    // @dev   1. Token.transfer_private_to_private(payer, X402_PRIVATE_PAYMENT_ROUTER, amount, 0)
    // @dev   2. Insted of internally calling the PrivateVault#deposit() inside the X402PrivatePaymentRouter#deposit(), we directly call the Token#transfer_private_to_private() inside the X402PrivatePaymentRouter#deposit() - This is because the notes created in a transaction aren't available to spend in the same transaction in Aztec Network. (This is only for a private function)
    // @dev      => By doing so, a given amoutn of Token will directry be able to trasnfer a payer to the PrivateVault contract via the X402PrivatePaymentRouter#deposit().
    
    // @dev - To directly transfer from a payer to the PrivateVault contract via the X402PrivatePaymentRouter#deposit(), a payer should authorize the X402PrivatePaymentRouter contract to transfer tokens on their behalf to PrivateVault
    let transfer_payer_to_x402_call_interface = token.transfer_private_to_private(payer, private_vault_contract_address, amount_to_be_deposited, 0);
    authwit_cheatcodes::add_private_authwit_from_call_interface(
        env,
        payer,
        x402_private_payment_router_contract_address,
        transfer_payer_to_x402_call_interface,
    );

    // @dev - Call the X402PrivatePaymentRouter#deposit() -> now payer has tokens to deposit and authwits are set for both internal token transfers
    env.call_private(payer, x402_private_payment_router.deposit(token_contract_address, private_vault_contract_address, amount_to_be_deposited));

    // @dev - Get the token balances after the deposit
    let balance_of_x402_private_payment_router = token_utils::get_private_balance(env, token_contract_address, x402_private_payment_router_contract_address);
    let balance_of_private_vault = token_utils::get_private_balance(env, token_contract_address, private_vault_contract_address);
    let balance_of_payer_after_deposit = token_utils::get_private_balance(env, token_contract_address, payer);
    debug_log_format("--------- balance_of_x402_private_payment_router: {0} ---------", [balance_of_x402_private_payment_router as Field]);
    debug_log_format("--------- balance_of_private_vault: {0} ---------", [balance_of_private_vault as Field]);
    debug_log_format("--------- balance_of_payer_after_deposit: {0} ---------", [balance_of_payer_after_deposit as Field]);

    // @dev - Check balances after calling the X402PrivatePaymentRouter#deposit(), which the payer's private balance should be decreased by 'amount_to_be_deposited' and the PrivateVault contract's private balance should be increased by 'amount_to_be_deposited'.
    // token_utils::check_private_balance(
    //     env,
    //     token_contract_address,
    //     x402_private_payment_router_contract_address,
    //     amount_to_be_deposited,
    // );
    // token_utils::check_private_balance(
    //     env,
    //     token_contract_address,
    //     private_vault_contract_address,
    //     amount_to_be_deposited,
    // );
    // token_utils::check_private_balance(env, token_contract_address, payer, transfer_amount - amount_to_be_deposited);

    // @dev - Check whether a payment ID was not incremented. (The payment ID should be incremented after the authorized_payment() is called)
    let payment_id = env.view_public(x402_private_payment_router.get_payment_id());
    assert(payment_id == 0);
    debug_log_format("--------- payment_id: {0} ---------", [payment_id as Field]);

    // @dev - Logging the simple messages
    let test_message = "-------------- The test of the X402PrivatePaymentRouter#deposit() has been done!!! --------------";
    debug_log(test_message);

    (env, token_contract_address, x402_private_payment_router_contract_address, private_vault_contract_address, admin, payer)
}

/**
 * @notice - Helper functions for the X402PrivatePaymentRouter#withdraw()
 */
pub unconstrained fn call_withdraw_function_of_x402_private_payment_router_contract(
    env: TestEnvironment,
    token_contract_address: AztecAddress,
    x402_private_payment_router_contract_address: AztecAddress,
    private_vault_contract_address: AztecAddress,
    payer: AztecAddress,
) {
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
