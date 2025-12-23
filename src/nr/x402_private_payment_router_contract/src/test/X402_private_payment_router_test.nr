use crate::X402PrivatePaymentRouter;
use crate::test::utils as x402_private_payment_router_utils;
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

// @dev - Import the PrivateVault contract (private_vault_contract/src/main.nr)
use private_vault::PrivateVault;
use private_vault::test::utils as private_vault_utils;

// @dev - Import the Token contract (token_contract/src/main.nr)
use token::Token;
use token::test::utils as token_utils;
use token::test::utils::mint_amount;


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
        x402_private_payment_router_contract_address,
        private_vault_contract_address, 
        token_contract_address, 
        admin, 
        payer
    ) = call_deposit_function_of_x402_private_payment_router_contract();

    // @dev - Call the X402PrivatePaymentRouter#withdraw() to withdraw a given amount of the Token from the X402PrivatePaymentRouter contract
    call_withdraw_function_of_x402_private_payment_router_contract(env, x402_private_payment_router_contract_address, private_vault_contract_address, token_contract_address, payer);
}



/*********************************
 *   @notice - Helper functions  *
 *********************************/
 
/**
 * @notice - Helper functions for the X402PrivatePaymentRouter#deposit()
 */
pub unconstrained fn call_deposit_function_of_x402_private_payment_router_contract() -> (TestEnvironment, AztecAddress, AztecAddress, AztecAddress, AztecAddress, AztecAddress) {
    let initial_message = "-------------- The initial line of the call_deposit_function_of_x402_private_payment_router_contract() to call the X402PrivatePaymentRouter#deposit()!!! --------------";
    debug_log(initial_message);

    // @dev - Setup (Deploy) the smart contracts and get necessary addresses    
    //let (env, private_vault_contract_address, token_contract_address, admin, payer) = utils::setup_contract(false);
    let (mut env, token_contract_address, admin, payer) = token::test::utils::setup_and_mint_to_private_without_minter(true);
    let x402_private_payment_router_contract_address = x402_private_payment_router_utils::deploy_x402_private_payment_router_contract(&mut env, admin);
    let private_vault_contract_address = private_vault::test::utils::deploy_private_vault_contract(&mut env, admin);

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

    // @dev - The PrivateVault#deposit() internally calls token.transfer_private_to_private(from, PRIVATE_VAULT, amount, 0)
    // @dev - So we need to authorize the PrivateVault contract to transfer tokens on behalf of payer
    // @dev - The "auth witness" must be for the token transfer that happens INSIDE the deposit function. 
    // @dev - Since the PrivateVault contract will transfer a Token to the PrivateVault on behalf of the payer when the PrivateVault#deposit() is called, the authorization (= auth witness) will not be needed when the PrivateVault#deposit() will be called.
    // @dev - Since actual caller (msg.sender) would be a payer address and the X402PrivatePaymentRouter contract would be call the deposit() on behalf of the payer (= THe X402PrivatePaymentRouter contract is just the "intermediary" contract), the "fron" address should be a "payer" address and the "to" address should be the PrivateVault contract address. 
    let transfer_in_deposit_call_interface = token.transfer_private_to_private(payer, x402_private_payment_router_contract_address, amount_to_be_deposited, 0);
    authwit_cheatcodes::add_private_authwit_from_call_interface(
        env,
        payer,
        x402_private_payment_router_contract_address,
        transfer_in_deposit_call_interface,
    );

    // @dev - Call the X402PrivatePaymentRouter#deposit() -> now payer has tokens to deposit and authwit is set for the internal token transfer
    env.call_private(payer, x402_private_payment_router.deposit(token_contract_address, payer, amount_to_be_deposited));

    // @dev - Get the token balances after the deposit
    let balance_of_x402_private_payment_router = token_utils::get_private_balance(env, token_contract_address, x402_private_payment_router_contract_address);
    let balance_of_private_vault = token_utils::get_private_balance(env, token_contract_address, private_vault_contract_address);
    let balance_of_payer_after_deposit = token_utils::get_private_balance(env, token_contract_address, payer);
    debug_log_format("--------- balance_of_x402_private_payment_router: {0} ---------", [balance_of_x402_private_payment_router as Field]);
    debug_log_format("--------- balance_of_private_vault: {0} ---------", [balance_of_private_vault as Field]);
    debug_log_format("--------- balance_of_payer_after_deposit: {0} ---------", [balance_of_payer_after_deposit as Field]);

    // @dev - Check balances after calling the X402PrivatePaymentRouter#deposit(), which the payer's private balance should be decreased by 'amount_to_be_deposited' and the PrivateVault contract's private balance should be increased by 'amount_to_be_deposited'.
    token_utils::check_private_balance(
        env,
        token_contract_address,
        x402_private_payment_router_contract_address,
        amount_to_be_deposited,
    );
    token_utils::check_private_balance(
        env,
        token_contract_address,
        private_vault_contract_address,
        amount_to_be_deposited,
    );
    token_utils::check_private_balance(env, token_contract_address, payer, transfer_amount - amount_to_be_deposited);

    // @dev - Logging the simple messages
    let test_message = "-------------- The test of the X402PrivatePaymentRouter#deposit() has been done!!! --------------";
    debug_log(test_message);

    (env, x402_private_payment_router_contract_address, private_vault_contract_address, token_contract_address, admin, payer)


    //----------------------------//
    //    Original Code           //
    //----------------------------//

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
pub unconstrained fn call_withdraw_function_of_x402_private_payment_router_contract(
    env: TestEnvironment,
    x402_private_payment_router_contract_address: AztecAddress,
    private_vault_contract_address: AztecAddress,
    token_contract_address: AztecAddress,
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
