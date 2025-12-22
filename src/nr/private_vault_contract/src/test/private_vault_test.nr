use crate::{
    PrivateVault, 
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
use token::Token; // @dev - Import the Token contract (token_contract/src/main.nr)


/**
 * @notice - The smart contract test for the deposit() of the PrivateVault contract
 */
#[test]
unconstrained fn deposit_success() {
    // @dev - Call the PrivateVault#deposit() to deposit a given amount of the Token into the PrivateVault contract
    let (env, private_vault_contract_address, token_contract_address, admin, payer) = call_deposit_function_of_private_vault_contract();
}

/**
 * @notice - The smart contract test for the withdraw() of the PrivateVault contract
 */
#[test]
unconstrained fn withdraw_success() {
    // @dev - Call the PrivateVault#deposit() first to deposit a given amount of the Token into the PrivateVault contract
    let (
        env, 
        private_vault_contract_address, 
        token_contract_address, 
        admin, 
        payer
    ) = call_deposit_function_of_private_vault_contract();

    // @dev - Call the PrivateVault#withdraw() to withdraw a given amount of the Token from the PrivateVault contract
    call_withdraw_function_of_private_vault_contract(env, private_vault_contract_address, token_contract_address, payer);
}


/****************************************************************
 *   @notice - Helper functions for the PrivateVault#deposit()  *
 ****************************************************************/
pub unconstrained fn call_deposit_function_of_private_vault_contract() -> (TestEnvironment, AztecAddress, AztecAddress, AztecAddress, AztecAddress) {
    let initial_message = "-------------- The initial line of the call_deposit_of_private_vault() to call the PrivateVault#deposit()!!! --------------";
    debug_log(initial_message);

    // @dev - Setup (Deploy) the smart contracts and get necessary addresses    
    //let (env, private_vault_contract_address, token_contract_address, admin, payer) = utils::setup_contract(false);
    let (mut env, token_contract_address, admin, payer) = utils::setup_and_mint_to_private_without_minter(true);
    let private_vault_contract_address = utils::deploy_private_vault_contract(&mut env, admin);

    // @dev - Create the contract instance of both contracts the PrivateVault and the Token.
    let private_vault = PrivateVault::at(private_vault_contract_address);
    let token = Token::at(token_contract_address);

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
    let balance_of_admin = utils::get_private_balance(env, token_contract_address, admin);
    let balance_of_payer = utils::get_private_balance(env, token_contract_address, payer);
    debug_log_format("--------- balance_of_admin: {0} ---------", [balance_of_admin as Field]);
    debug_log_format("--------- balance_of_payer: {0} ---------", [balance_of_payer as Field]);

    // @dev - Check balances
    utils::check_private_balance(
        env,
        token_contract_address,
        admin,
        mint_amount - transfer_amount,
    );
    utils::check_private_balance(env, token_contract_address, payer, transfer_amount);

    // ---------------------------------------------------------------------//
    //        Calling the deposit() of the PrivateVault contract            //
    // ---------------------------------------------------------------------//
    let amount_to_be_deposited = (1000 as u128);

    // @dev - [Time Travel]: Advance block to ensure the transfer is processed
    // @dev - Mines an empty block at a given timestamp, causing the next public execution to occur at this time (like `set_next_block_timestamp`), but also allowing for private execution to happen using this empty block as the anchor block.
    let block_timestamp = env.last_block_timestamp() + 3600; // e.g., advance by 1 hour (3600 seconds)
    env.mine_block_at(block_timestamp);

    let token_transfer_message = "-------------- The test of the token.transfer_private_to_private() has been done!!! --------------";
    debug_log(token_transfer_message);

    // @dev - The PrivateVault#deposit() internally calls token.transfer_private_to_private(from, PRIVATE_VAULT, amount, 0)
    // @dev - So we need to authorize the PrivateVault contract to transfer tokens on behalf of payer
    // @dev - The "auth witness" must be for the token transfer that happens INSIDE the deposit function. 
    // @dev - Since the PrivateVault contract will transfer a Token to the PrivateVault on behalf of the payer when the PrivateVault#deposit() is called, the authorization (= auth witness) will not be needed when the PrivateVault#deposit() will be called.
    // @dev - Since actual caller (msg.sender) would be a payer address and the X402PrivatePaymentRouter contract would be call the deposit() on behalf of the payer (= THe X402PrivatePaymentRouter contract is just the "intermediary" contract), the "fron" address should be a "payer" address and the "to" address should be the PrivateVault contract address. 
    let transfer_in_deposit_call_interface = token.transfer_private_to_private(payer, private_vault_contract_address, amount_to_be_deposited, 0);
    authwit_cheatcodes::add_private_authwit_from_call_interface(
        env,
        payer,
        private_vault_contract_address,
        transfer_in_deposit_call_interface,
    );

    // @dev - Call the PrivateVault#deposit() -> now payer has tokens to deposit and authwit is set for the internal token transfer
    env.call_private(payer, private_vault.deposit(token_contract_address, payer, amount_to_be_deposited));

    // @dev - Get the token balances after the deposit
    let balance_of_private_vault = utils::get_private_balance(env, token_contract_address, private_vault_contract_address);
    let balance_of_payer_after_deposit = utils::get_private_balance(env, token_contract_address, payer);
    debug_log_format("--------- balance_of_private_vault: {0} ---------", [balance_of_private_vault as Field]);
    debug_log_format("--------- balance_of_payer_after_deposit: {0} ---------", [balance_of_payer_after_deposit as Field]);

    // @dev - Check balances after calling the PrivateVault#deposit(), which the payer's private balance should be decreased by 'amount_to_be_deposited' and the PrivateVault contract's private balance should be increased by 'amount_to_be_deposited'.
    utils::check_private_balance(
        env,
        token_contract_address,
        private_vault_contract_address,
        amount_to_be_deposited,
    );
    utils::check_private_balance(env, token_contract_address, payer, transfer_amount - amount_to_be_deposited);

    // @dev - Logging the simple messages
    let test_message = "-------------- The test of the PrivateVault#deposit() has been done!!! --------------";
    debug_log(test_message);

    (env, private_vault_contract_address, token_contract_address, admin, payer)
}


/****************************************************************
 *  @notice - Helper functions for the PrivateVault#withdraw()  *
 ****************************************************************/
pub unconstrained fn call_withdraw_function_of_private_vault_contract(
    env: TestEnvironment,
    private_vault_contract_address: AztecAddress,
    token_contract_address: AztecAddress,
    payer: AztecAddress,
) {
    // @dev - Reconstruct contract instances from addresses
    let private_vault = PrivateVault::at(private_vault_contract_address);
    let token = Token::at(token_contract_address);

    // ----------------------------------------------------- //
    //        Calling the PrivateVault#withdraw()            //
    // ----------------------------------------------------- //
    let amount_to_be_withdrawn = (1000 as u128);
    let deposited_amount = utils::get_private_balance(env, token_contract_address, private_vault_contract_address);

    // @dev - Call the PrivateVault#withdraw() -> now payer has tokens to withdraw and authwit is set for the internal token transfer
    env.call_private(payer, private_vault.withdraw(token_contract_address, payer, amount_to_be_withdrawn));

    // @dev - [Time Travel]: Advance block to ensure the transfer is processed
    // @dev - Mines an empty block at a given timestamp, causing the next public execution to occur at this time (like `set_next_block_timestamp`), but also allowing for private execution to happen using this empty block as the anchor block.
    let block_timestamp = env.last_block_timestamp() + 3600; // e.g., advance by 1 hour (3600 seconds)
    env.mine_block_at(block_timestamp);

    let token_transfer_message = "-------------- [Time Travel]: The block is advanced to the future block --------------";
    debug_log(token_transfer_message);

    // @dev - Get the token balances after the deposit
    let balance_of_private_vault = utils::get_private_balance(env, token_contract_address, private_vault_contract_address);
    let balance_of_payer_after_withdrawn = utils::get_private_balance(env, token_contract_address, payer);
    debug_log_format("--------- balance_of_private_vault: {0} ---------", [balance_of_private_vault as Field]);
    debug_log_format("--------- balance_of_payer_after_withdrawn: {0} ---------", [balance_of_payer_after_withdrawn as Field]);

    // @dev - Check balances after calling the PrivateVault#withdraw(), which the payer's private balance should be increased by 'amount_to_be_withdrawn' and the PrivateVault contract's private balance should be decreased by 'amount_to_be_withdrawn'.
    // @dev - [TODO]: Balances were not changed after withdrawal process, which is problem to be resolved in the next.
    utils::check_private_balance(env, token_contract_address, private_vault_contract_address, deposited_amount - amount_to_be_withdrawn);
    utils::check_private_balance(env, token_contract_address, payer,amount_to_be_withdrawn);

    // @dev - Logging the simple messages
    let test_message = "-------------- The test of the PrivateVault#withdraw() has been done!!! --------------";
    debug_log(test_message);
}