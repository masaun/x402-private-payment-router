import { X402PrivatePaymentRouterContract } from "../artifacts/X402PrivatePaymentRouter.js";
import { PrivateVaultContract } from "../artifacts/PrivateVault.js";
import { TokenContract } from "../artifacts/Token.js";
import { describe, it, expect, beforeAll, beforeEach } from "vitest";
import { TestWallet } from "@aztec/test-wallet/server";
import { createAztecNodeClient } from "@aztec/aztec.js/node";
import { 
  deployX402PrivatePaymentRouter, 
  deployPrivateVault,
  deployTokenWithMinter 
} from "./utils.js";
import { AztecAddress } from "@aztec/stdlib/aztec-address";

import {
  INITIAL_TEST_SECRET_KEYS,
  INITIAL_TEST_ACCOUNT_SALTS,
  INITIAL_TEST_ENCRYPTION_KEYS,
} from "@aztec/accounts/testing";

describe("X402PrivatePaymentRouter Contract", () => {
  let wallet: TestWallet;
  let alice: AztecAddress;
  let bob: AztecAddress;
  let admin: AztecAddress;
  let x402Router: X402PrivatePaymentRouterContract;
  let privateVault: PrivateVaultContract;
  let token: TokenContract;

  beforeAll(async () => {
    const aztecNode = await createAztecNodeClient("http://localhost:8080", {});
    wallet = await TestWallet.create(
      aztecNode,
      {
        dataDirectory: "pxe-test-x402",
        proverEnabled: false,
      },
      {},
    );

    // Register initial test accounts
    await Promise.all(
      INITIAL_TEST_SECRET_KEYS.map(async (secret, i) => {
        await wallet.createSchnorrAccount(
          secret,
          INITIAL_TEST_ACCOUNT_SALTS[i],
          INITIAL_TEST_ENCRYPTION_KEYS[i],
        );
      }),
    );
    
    // Get the registered accounts
    const accounts = await wallet.getAccounts();
    [alice, bob, admin] = [accounts[0].item, accounts[1].item, accounts[2].item];
  });

  /**
   * Helper function to authorize token deposit through vault
   * The x402Router calls privateVault.deposit, which transfers tokens from user to vault
   */
  async function authorizeDeposit(
    from: AztecAddress,
    amount: bigint,
  ): Promise<void> {
    // The vault will transfer tokens: token.transfer_private_to_private(from, vault, amount, 0)
    const action = token.methods.transfer_private_to_private(
      from,
      privateVault.address,
      amount,
      0,
    );

    // Create authwit allowing the vault to make this transfer
    const intent = {
      caller: privateVault.address,
      action: action,
    };

    await wallet.createAuthWit(from, intent);
  }

  /**
   * Helper function to authorize token withdrawal through vault
   * The x402Router calls privateVault.withdraw, which transfers tokens from vault to user
   */
  async function authorizeWithdrawal(
    to: AztecAddress,
    amount: bigint,
  ): Promise<void> {
    // The vault will transfer tokens: token.transfer_private_to_private(vault, to, amount, 0)
    const action = token.methods.transfer_private_to_private(
      privateVault.address,
      to,
      amount,
      0,
    );

    // Create authwit allowing the vault to make this transfer
    // Note: The vault itself needs to authorize this transfer
    const intent = {
      caller: privateVault.address,
      action: action,
    };

    await wallet.createAuthWit(privateVault.address, intent);
  }

  beforeEach(async () => {
    // Deploy Token contract with admin as minter
    token = await deployTokenWithMinter(
      wallet,
      "Test Token",
      "TST",
      18n,
      admin, // minter
      admin, // upgrade authority
    );

    // Deploy PrivateVault contract
    privateVault = await deployPrivateVault(
      wallet,
      admin,
      token.address,
    );

    // Deploy X402PrivatePaymentRouter contract
    x402Router = await deployX402PrivatePaymentRouter(
      wallet,
      admin,
    );

    // Mint some tokens to Alice for testing
    await token.methods
      .mint_to_private(alice, 1000n)
      .send({ from: admin })
      .wait();
  });

  describe("Deployment and Initialization", () => {
    it("should deploy with correct admin", async () => {
      const contractAdmin = await x402Router.methods.get_admin().simulate({
        from: admin,
      });
      expect(contractAdmin).toStrictEqual(admin);
    });

    it("should initialize payment_id to 0", async () => {
      const paymentId = await x402Router.methods.get_payment_id().simulate({
        from: admin,
      });
      expect(paymentId).toBe(0n);
    });
  });

  describe("Deposit", () => {
    it("should allow user to deposit tokens", async () => {
      const depositAmount = 100n;

      await authorizeDeposit(alice, depositAmount);
      await x402Router.methods
        .deposit(token.address, privateVault.address, depositAmount)
        .send({ from: alice })
        .wait();

      // Verify deposit was successful by checking if we can settle payment
      // (wallet balance tracking is private, so we verify indirectly)
    });

    it("should fail when depositing more than balance", async () => {
      const excessiveAmount = 10000n; // More than minted

      await authorizeDeposit(alice, excessiveAmount);
      await expect(async () => {
        await x402Router.methods
          .deposit(token.address, privateVault.address, excessiveAmount)
          .send({ from: alice })
          .wait();
      }).rejects.toThrow();
    });
  });

  describe("Withdraw", () => {
    beforeEach(async () => {
      // Deposit first
      await authorizeDeposit(alice, 500n);
      await x402Router.methods
        .deposit(token.address, privateVault.address, 500n)
        .send({ from: alice })
        .wait();
    });

    it("should allow user to withdraw deposited tokens", async () => {
      const withdrawAmount = 100n;

      await authorizeWithdrawal(alice, withdrawAmount);
      await x402Router.methods
        .withdraw(token.address, privateVault.address, withdrawAmount)
        .send({ from: alice })
        .wait();

      // Withdrawal should succeed without error
    });

    it("should fail when withdrawing more than deposited", async () => {
      const excessiveAmount = 1000n;

      await authorizeWithdrawal(alice, excessiveAmount);
      await expect(async () => {
        await x402Router.methods
          .withdraw(token.address, privateVault.address, excessiveAmount)
          .send({ from: alice })
          .wait();
      }).rejects.toThrow();
    });
  });

  describe("Settle Payment", () => {
    const paymentAmount = 200n;
    const paymentHash = 123456n;

    beforeEach(async () => {
      // Deposit tokens first
      await authorizeDeposit(alice, 500n);
      await x402Router.methods
        .deposit(token.address, privateVault.address, 500n)
        .send({ from: alice })
        .wait();
    });

    it("should settle payment from payer to payee", async () => {
      await x402Router.methods
        .settle_payment(
          token.address,
          privateVault.address,
          bob, // payee
          paymentAmount,
          paymentHash,
          alice, // event recipient
        )
        .send({ from: alice })
        .wait();

      // Verify payment ID was incremented
      const newPaymentId = await x402Router.methods
        .get_payment_id()
        .simulate({ from: admin });
      expect(newPaymentId).toBe(1n);
    });

    it("should increment payment_id after settlement", async () => {
      const initialPaymentId = await x402Router.methods
        .get_payment_id()
        .simulate({ from: admin });

      await x402Router.methods
        .settle_payment(
          token.address,
          privateVault.address,
          bob,
          paymentAmount,
          paymentHash,
          alice,
        )
        .send({ from: alice })
        .wait();

      const newPaymentId = await x402Router.methods
        .get_payment_id()
        .simulate({ from: admin });
      
      expect(newPaymentId).toBe(initialPaymentId + 1n);
    });

    it("should fail when settling payment with insufficient balance", async () => {
      const excessiveAmount = 1000n;

      await expect(async () => {
        await x402Router.methods
          .settle_payment(
            token.address,
            privateVault.address,
            bob,
            excessiveAmount,
            paymentHash,
            alice,
          )
          .send({ from: alice })
          .wait();
      }).rejects.toThrow();
    });

    it("should handle multiple sequential payments", async () => {
      // First payment
      await x402Router.methods
        .settle_payment(
          token.address,
          privateVault.address,
          bob,
          100n,
          12345n,
          alice,
        )
        .send({ from: alice })
        .wait();

      // Second payment
      await x402Router.methods
        .settle_payment(
          token.address,
          privateVault.address,
          bob,
          100n,
          67890n,
          alice,
        )
        .send({ from: alice })
        .wait();

      const paymentId = await x402Router.methods
        .get_payment_id()
        .simulate({ from: admin });
      
      expect(paymentId).toBe(2n);
    });
  });

  describe("Payment ID Management", () => {
    it("should start with payment_id of 0", async () => {
      const paymentId = await x402Router.methods
        .get_payment_id()
        .simulate({ from: admin });
      expect(paymentId).toBe(0n);
    });

    it("should increment payment_id after each settlement", async () => {
      // Deposit first
      await authorizeDeposit(alice, 500n);
      await x402Router.methods
        .deposit(token.address, privateVault.address, 500n)
        .send({ from: alice })
        .wait();

      // First settlement
      await x402Router.methods
        .settle_payment(
          token.address,
          privateVault.address,
          bob,
          100n,
          111n,
          alice,
        )
        .send({ from: alice })
        .wait();

      let paymentId = await x402Router.methods
        .get_payment_id()
        .simulate({ from: admin });
      expect(paymentId).toBe(1n);

      // Second settlement
      await x402Router.methods
        .settle_payment(
          token.address,
          privateVault.address,
          bob,
          100n,
          222n,
          alice,
        )
        .send({ from: alice })
        .wait();

      paymentId = await x402Router.methods
        .get_payment_id()
        .simulate({ from: admin });
      expect(paymentId).toBe(2n);
    });
  });

  describe("Integration Tests", () => {
    it("should handle full payment flow: deposit -> settle -> withdraw", async () => {
      const depositAmount = 1000n;
      const paymentAmount = 300n;
      const remainingAmount = 200n;

      // Step 1: Deposit
      await authorizeDeposit(alice, depositAmount);
      await x402Router.methods
        .deposit(token.address, privateVault.address, depositAmount)
        .send({ from: alice })
        .wait();

      // Step 2: Settle payment
      await x402Router.methods
        .settle_payment(
          token.address,
          privateVault.address,
          bob,
          paymentAmount,
          555n,
          alice,
        )
        .send({ from: alice })
        .wait();

      // Step 3: Withdraw remaining funds
      await authorizeWithdrawal(alice, remainingAmount);
      await x402Router.methods
        .withdraw(token.address, privateVault.address, remainingAmount)
        .send({ from: alice })
        .wait();

      // Verify payment ID
      const paymentId = await x402Router.methods
        .get_payment_id()
        .simulate({ from: admin });
      expect(paymentId).toBe(1n);
    });
  });
});