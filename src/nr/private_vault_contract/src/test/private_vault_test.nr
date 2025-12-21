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
    let initial_message = "-------------- The initial line!!! --------------";
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
    
    // @dev - Check balances
    utils::check_private_balance(
        env,
        token_contract_address,
        admin,
        mint_amount - transfer_amount,
    );
    utils::check_private_balance(env, token_contract_address, payer, transfer_amount);


    // ---------------------------- The original test code ---------------------------- //
    // ---------------------------- The original test code ---------------------------- //
    // ---------------------------- The original test code ---------------------------- //


    let amount = (1000 as u128);

    // // @dev - Authorize the PrivateVault contract to transfer tokens on behalf of payer
    // authwit_cheatcodes::add_private_authwit_from_call_interface(
    //     env,
    //     admin,
    //     admin,
    //     token.transfer_private_to_private(admin, payer, amount + 1000, 0)
    // );

    // // @dev - First, transfer tokens from admin (who has initial supply) to payer
    // env.call_private(admin, token.transfer_private_to_private(admin, payer, amount + 1000, 0));

    // // @dev - Check balances after calling the token.transfer_private_to_private(), which transferring a given amount of a given token from admin to the payer's wallet.
    // utils::check_private_balance(env, token_contract_address, payer, amount + 1000);


    // @dev - [Time Travel]: Advance block to ensure the transfer is processed
    // @dev - Mines an empty block at a given timestamp, causing the next public execution to occur at this time (like `set_next_block_timestamp`), but also allowing for private execution to happen using this empty block as the anchor block.
    let block_timestamp = env.last_block_timestamp() + 3600; // e.g., advance by 1 hour (3600 seconds)
    env.mine_block_at(block_timestamp);

    let token_transfer_message = "-------------- The test of the token.transfer_private_to_private() has been done!!! --------------";
    debug_log(token_transfer_message);

    // @dev - The deposit() function internally calls token.transfer_private_to_private(from, PRIVATE_VAULT, amount, 0)
    // @dev - So we need to authorize the PrivateVault contract to transfer tokens on behalf of payer
    // @dev - The "auth witness" must be for the token transfer that happens INSIDE the deposit function. 
    // @dev - Since the X402PrivatePaymentRouter contract will transfer a Token to the PrivateVault on behalf of the payer when the X402PrivatePaymentRouter#deposit() is called, the authorization (= auth witness) will not be needed when the X402PrivatePaymentRouter#deposit() will be called.
    // @dev - Since actual caller (msg.sender) would be a payer address and the X402PrivatePaymentRouter contract would be call the deposit() on behalf of the payer (= THe X402PrivatePaymentRouter contract is just the "intermediary" contract), the "fron" address should be a "payer" address and the "to" address should be the PrivateVault contract address. 
    let transfer_in_deposit_call_interface = token.transfer_private_to_private(payer, private_vault_contract_address, amount, 0);
    authwit_cheatcodes::add_private_authwit_from_call_interface(
        env,
        payer,
        private_vault_contract_address,
        transfer_in_deposit_call_interface,
    );

    // @dev - Call the deposit() function (now payer has tokens to deposit and authwit is set for the internal token transfer)
    env.call_private(payer, private_vault.deposit(token_contract_address, payer, amount));

    // // @dev - Check balances after calling the deposit(), which the payer's private balance should be decreased by 'amount'
    // // utils::check_private_balance(
    // //     env,
    // //     token_contract_address,
    // //     owner,
    // //     mint_amount - transfer_amount,
    // // );
    // // utils::check_private_balance(env, token_contract_address, recipient, transfer_amount);

    // @dev - Logging the simple messages
    let test_message = "-------------- The test of the deposit() has been done!!! --------------";
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
