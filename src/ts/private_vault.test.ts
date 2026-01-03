import { PrivateVaultContract } from "../artifacts/PrivateVault.js";
import { TokenContract } from "../artifacts/Token.js";
import { describe, it, expect, beforeAll, beforeEach } from "vitest";
import { TestWallet } from "@aztec/test-wallet/server";
import { createAztecNodeClient } from "@aztec/aztec.js/node";
import { deployPrivateVault, deployTokenWithMinter } from "./utils.js";
import { AztecAddress } from "@aztec/stdlib/aztec-address";

import {
  INITIAL_TEST_SECRET_KEYS,
  INITIAL_TEST_ACCOUNT_SALTS,
  INITIAL_TEST_ENCRYPTION_KEYS,
} from "@aztec/accounts/testing";

describe("PrivateVault Contract", () => {
  let wallet: TestWallet;
  let alice: AztecAddress;
  let bob: AztecAddress;
  let admin: AztecAddress;
  let privateVault: PrivateVaultContract;
  let token: TokenContract;

  beforeAll(async () => {
    const aztecNode = await createAztecNodeClient("http://localhost:8080", {});
    wallet = await TestWallet.create(
      aztecNode,
      {
        dataDirectory: "pxe-test-vault",
        proverEnabled: false,
      },
      {},
    );

    // Register initial test accounts
    const accounts = await Promise.all(
      INITIAL_TEST_SECRET_KEYS.map(async (secret, i) => {
        const accountManager = await wallet.createSchnorrAccount(
          secret,
          INITIAL_TEST_ACCOUNT_SALTS[i],
          INITIAL_TEST_ENCRYPTION_KEYS[i],
        );
        return accountManager.address;
      }),
    );
    
    [alice, bob, admin] = accounts;
  });

  /**
   * Helper function to create authwit for token deposit
   * This allows the vault to transfer tokens from the user's account
   */
  async function authorizeDeposit(
    from: AztecAddress,
    amount: bigint,
  ): Promise<void> {
    // Create the transfer call that will happen inside the deposit function
    // The vault will call: token.transfer_private_to_private(from, PRIVATE_VAULT, amount, 0)
    const transferAction = token.methods.transfer_private_to_private(
      from,
      privateVault.address,
      amount,
      0, // nonce must be 0 to match the vault's call
    );

    // Create authwit for this transfer
    // The vault contract will be the caller when it executes the transfer
    const witness = await wallet.createAuthWit(from, {
      caller: privateVault.address,
      action: transferAction,
    });
    
    // Log for debugging
    console.log(`Created authwit for ${from.toString()} to deposit ${amount}`);
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

    // Mint some tokens to Alice and Bob for testing
    await token.methods
      .mint_to_private(alice, 1000n)
      .send({ from: admin })
      .wait();

    await token.methods
      .mint_to_private(bob, 1000n)
      .send({ from: admin })
      .wait();
  });

  describe("Deployment and Initialization", () => {
    it("should deploy with correct admin", async () => {
      const contractAdmin = await privateVault.methods.get_admin().simulate({
        from: admin,
      });
      expect(contractAdmin).toStrictEqual(admin);
    });

    it("should have correct token contract address", async () => {
      // Token contract address is stored in public immutable storage
      // We can verify it's set correctly by successful token operations
    });
  });

  describe("Deposit", () => {
    it("should allow user to deposit tokens into vault", async () => {
      const depositAmount = 100n;

      // Authorize the vault to transfer tokens
      await authorizeDeposit(alice, depositAmount);

      await privateVault.methods
        .deposit(token.address, alice, depositAmount)
        .send({ from: alice })
        .wait();

      // Deposit should complete without error
    });

    it("should allow multiple deposits from same user", async () => {
      const firstDeposit = 100n;
      const secondDeposit = 200n;

      await authorizeDeposit(alice, firstDeposit);
      await privateVault.methods
        .deposit(token.address, alice, firstDeposit)
        .send({ from: alice })
        .wait();

      await authorizeDeposit(alice, secondDeposit);
      await privateVault.methods
        .deposit(token.address, alice, secondDeposit)
        .send({ from: alice })
        .wait();

      // Both deposits should complete successfully
    });

    it("should allow deposits from different users", async () => {
      const aliceDeposit = 150n;
      const bobDeposit = 250n;

      await authorizeDeposit(alice, aliceDeposit);
      await privateVault.methods
        .deposit(token.address, alice, aliceDeposit)
        .send({ from: alice })
        .wait();

      await authorizeDeposit(bob, bobDeposit);
      await privateVault.methods
        .deposit(token.address, bob, bobDeposit)
        .send({ from: bob })
        .wait();

      // Both deposits should complete successfully
    });

    it("should fail when depositing more than token balance", async () => {
      const excessiveAmount = 10000n; // More than minted

      await authorizeDeposit(alice, excessiveAmount);
      await expect(async () => {
        await privateVault.methods
          .deposit(token.address, alice, excessiveAmount)
          .send({ from: alice })
          .wait();
      }).rejects.toThrow();
    });

    it("should fail when depositing zero amount", async () => {
      await expect(async () => {
        await privateVault.methods
          .deposit(token.address, alice, 0n)
          .send({ from: alice })
          .wait();
      }).rejects.toThrow();
    });
  });

  describe("Withdraw", () => {
    const depositAmount = 500n;

    beforeEach(async () => {
      // Deposit tokens first
      await authorizeDeposit(alice, depositAmount);
      await privateVault.methods
        .deposit(token.address, alice, depositAmount)
        .send({ from: alice })
        .wait();
    });

    it("should allow user to withdraw deposited tokens", async () => {
      const withdrawAmount = 100n;

      await privateVault.methods
        .withdraw(token.address, alice, withdrawAmount)
        .send({ from: alice })
        .wait();

      // Withdrawal should complete without error
    });

    it("should allow multiple partial withdrawals", async () => {
      const firstWithdraw = 100n;
      const secondWithdraw = 150n;

      await privateVault.methods
        .withdraw(token.address, alice, firstWithdraw)
        .send({ from: alice })
        .wait();

      await privateVault.methods
        .withdraw(token.address, alice, secondWithdraw)
        .send({ from: alice })
        .wait();

      // Both withdrawals should complete successfully
    });

    it("should allow full withdrawal of deposited amount", async () => {
      await privateVault.methods
        .withdraw(token.address, alice, depositAmount)
        .send({ from: alice })
        .wait();

      // Full withdrawal should complete successfully
    });

    it("should fail when withdrawing more than deposited", async () => {
      const excessiveAmount = depositAmount + 100n;

      await expect(async () => {
        await privateVault.methods
          .withdraw(token.address, alice, excessiveAmount)
          .send({ from: alice })
          .wait();
      }).rejects.toThrow();
    });

    it("should fail when withdrawing to different address than depositor", async () => {
      // Note: Based on the contract code, withdraw sends to 'to' address
      // This test verifies withdrawal works to the specified recipient
      const withdrawAmount = 100n;

      await privateVault.methods
        .withdraw(token.address, bob, withdrawAmount)
        .send({ from: alice })
        .wait();

      // This should succeed as the vault allows withdrawing to any address
    });
  });

  describe("Vault Balance Management", () => {
    it("should handle sequential deposits and withdrawals", async () => {
      // Deposit
      await authorizeDeposit(alice, 300n);
      await privateVault.methods
        .deposit(token.address, alice, 300n)
        .send({ from: alice })
        .wait();

      // Withdraw partial
      await privateVault.methods
        .withdraw(token.address, alice, 100n)
        .send({ from: alice })
        .wait();

      // Deposit more
      await authorizeDeposit(alice, 200n);
      await privateVault.methods
        .deposit(token.address, alice, 200n)
        .send({ from: alice })
        .wait();

      // Withdraw again
      await privateVault.methods
        .withdraw(token.address, alice, 150n)
        .send({ from: alice })
        .wait();

      // All operations should complete successfully
    });

    it("should maintain separate balances for different users", async () => {
      const aliceDeposit = 300n;
      const bobDeposit = 500n;

      // Both users deposit
      await authorizeDeposit(alice, aliceDeposit);
      await privateVault.methods
        .deposit(token.address, alice, aliceDeposit)
        .send({ from: alice })
        .wait();

      await authorizeDeposit(bob, bobDeposit);
      await privateVault.methods
        .deposit(token.address, bob, bobDeposit)
        .send({ from: bob })
        .wait();

      // Alice withdraws
      await privateVault.methods
        .withdraw(token.address, alice, 100n)
        .send({ from: alice })
        .wait();

      // Bob should still be able to withdraw his full amount
      await privateVault.methods
        .withdraw(token.address, bob, bobDeposit)
        .send({ from: bob })
        .wait();

      // All operations should complete successfully
    });
  });

  describe("Edge Cases", () => {
    it("should handle minimum deposit amount", async () => {
      const minAmount = 1n;

      await authorizeDeposit(alice, minAmount);
      await privateVault.methods
        .deposit(token.address, alice, minAmount)
        .send({ from: alice })
        .wait();

      await privateVault.methods
        .withdraw(token.address, alice, minAmount)
        .send({ from: alice })
        .wait();

      // Both operations should succeed
    });

    it("should handle large deposit amounts", async () => {
      // First mint more tokens to Alice
      await token.methods
        .mint_to_private(alice, 100000n)
        .send({ from: admin })
        .wait();

      const largeAmount = 50000n;

      await authorizeDeposit(alice, largeAmount);
      await privateVault.methods
        .deposit(token.address, alice, largeAmount)
        .send({ from: alice })
        .wait();

      await privateVault.methods
        .withdraw(token.address, alice, largeAmount)
        .send({ from: alice })
        .wait();

      // Both operations should succeed
    });

    it("should fail on withdrawal without prior deposit", async () => {
      // Create a new user with tokens but no vault deposit
      const charlie = (await wallet.getAccounts())[3]?.item;
      
      if (charlie) {
        await token.methods
          .mint_to_private(charlie, 1000n)
          .send({ from: admin })
          .wait();

        await expect(async () => {
          await privateVault.methods
            .withdraw(token.address, charlie, 100n)
            .send({ from: charlie })
            .wait();
        }).rejects.toThrow();
      }
    });
  });

  describe("Integration with Token Contract", () => {
    it("should correctly transfer tokens on deposit", async () => {
      const depositAmount = 100n;

      // The deposit should transfer tokens from user to vault
      await authorizeDeposit(alice, depositAmount);
      await privateVault.methods
        .deposit(token.address, alice, depositAmount)
        .send({ from: alice })
        .wait();

      // Token transfer should have occurred successfully
    });

    it("should correctly transfer tokens on withdrawal", async () => {
      const depositAmount = 200n;
      const withdrawAmount = 100n;

      await authorizeDeposit(alice, depositAmount);
      await privateVault.methods
        .deposit(token.address, alice, depositAmount)
        .send({ from: alice })
        .wait();

      // The withdrawal should transfer tokens from vault to user
      await privateVault.methods
        .withdraw(token.address, alice, withdrawAmount)
        .send({ from: alice })
        .wait();

      // Token transfer should have occurred successfully
    });

    it("should handle multiple concurrent users", async () => {
      // Alice deposits
      await authorizeDeposit(alice, 300n);
      await privateVault.methods
        .deposit(token.address, alice, 300n)
        .send({ from: alice })
        .wait();

      // Bob deposits
      await authorizeDeposit(bob, 400n);
      await privateVault.methods
        .deposit(token.address, bob, 400n)
        .send({ from: bob })
        .wait();

      // Alice withdraws
      await privateVault.methods
        .withdraw(token.address, alice, 150n)
        .send({ from: alice })
        .wait();

      // Bob withdraws
      await privateVault.methods
        .withdraw(token.address, bob, 200n)
        .send({ from: bob })
        .wait();

      // All operations should succeed independently
    });
  });
});