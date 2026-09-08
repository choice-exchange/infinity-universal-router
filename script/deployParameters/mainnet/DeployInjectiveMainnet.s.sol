// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 Choice Exchange
pragma solidity ^0.8.24;

import {DeployUniversalRouter} from "../../DeployUniversalRouter.s.sol";
import {RouterParameters} from "../../../src/base/RouterImmutables.sol";

/**
 * Injective EVM MAINNET (chain 1776).
 *
 * 🔴 Pre-req: CREATE3_FACTORY must be exported. `run()` falls back to PancakeSwap's factory
 * address when it is unset, and that address is not a contract on Injective - so a forgotten
 * export fails as "call to non-contract address" rather than deploying anywhere wrong. Export
 * 0xa4753315E17b79A6f0Dc7739650D019dDD807Df5. PRIVATE_KEY must be a deployer WHITELISTED on
 * that factory or `deploy` reverts NotWhitelisted.
 *
 * Step 1: Deploy
 * forge script script/deployParameters/mainnet/DeployInjectiveMainnet.s.sol:DeployInjectiveMainnet -vvv \
 *     --rpc-url $RPC_URL \
 *     --broadcast \
 *     --gas-limit 12000000
 *
 * ⛔ NEVER --slow and never --resume, on either Injective network. `--slow` makes forge wait for
 * a receipt between transactions and this script sends more than one. `--resume` offers to
 * replay work that already landed, because a mined transaction can answer with a null receipt.
 * Confirm with eth_getCode instead, and pass an explicit generous --gas-limit: eth_estimateGas
 * under-reports on Injective and the shortfall is silent.
 *
 * Step 2: `acceptOwnership()` from the deployer. `run()` only *offers* ownership - UniversalRouter
 * is Ownable2Step and the offer is made in the factory's afterDeploymentExecutionPayload.
 *
 * Step 3: hand it to the timelock - `transferOwnership(0x8a3c2cDa...)` from the deployer, then
 * `acceptOwnership()` scheduled and executed BY the timelock. 🔴 Not optional and not cosmetic:
 * the owner is who can `pause()` the router, so a router left owned by the deploy EOA is a hot
 * key that can stop every swap on the DEX.
 */
contract DeployInjectiveMainnet is DeployUniversalRouter {
    /// @notice contract address will be based on deployment salt
    ///
    /// 🔴 **A CREATE3 salt is an ADDRESS, so redeploying means bumping this.** `Create3Factory`
    /// derives the address from the salt alone; deploying the same salt twice lands on code that
    /// is already there and reverts. There is no env override, deliberately - the address a
    /// deployment lands on should be a reviewed line in a diff, not an environment variable.
    ///
    /// **1.2.0 on mainnet is a fresh salt, not a re-use of testnet's.** Salts are namespaced by
    /// the FACTORY, and mainnet's factory is a different address, so 1.2.0 here is unclaimed. It
    /// matches testnet's version deliberately: the same source deployed to both nets should
    /// carry the same version, and 1.2.0 is the first salt whose bytecode carries upstream's
    /// `9b026be` exact-output partial-fill fix. Before it, an exactOutput swap never checked the
    /// pool delivered what was asked - a CL pool that ran out of liquidity before the price limit
    /// filled PARTIALLY and the only guard passed precisely BECAUSE less was delivered. Thin
    /// liquidity is what a newly deployed DEX has, so mainnet must never start below 1.2.0.
    ///
    /// ⛔ Testnet's 1.1.0 is BURNT and the lesson generalises: this repo resolves
    /// `infinity-periphery/` to ITS OWN nested submodule, so moving the pin in
    /// choice_v2_contracts does not move what `CLRouterBase` actually compiles from. A "fixed"
    /// redeploy came out byte-identical to the buggy router it replaced.
    /// `check-fork-pins.sh` enforces every copy at any depth; run it before broadcasting.
    function getDeploymentSalt() public pure override returns (bytes32) {
        return keccak256("INFINITY-UNIVERSAL-ROUTER/UniversalRouter/1.2.0");
    }

    function setUp() public override {
        params = RouterParameters({
            // canonical Permit2, verified on 1776 by eth_getCode (9,152 bytes)
            permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3,
            // wINJ: bank-backed wrapper, same address on both Injective nets. Verified on 1776:
            // 5,954 bytes, symbol() "WINJ", decimals() 18.
            weth9: 0x0000000088827d2d103ee2d9A6b781773AE03FfB,
            // No PancakeSwap v2 / v3 / StableSwap deployment exists on Injective.
            // UNSUPPORTED_PROTOCOL is remapped to the UnsupportedProtocol contract in run(),
            // so those command branches revert instead of pointing at a wrong address.
            v2Factory: UNSUPPORTED_PROTOCOL,
            v3Factory: UNSUPPORTED_PROTOCOL,
            v3Deployer: UNSUPPORTED_PROTOCOL,
            v2InitCodeHash: BYTES32_ZERO,
            v3InitCodeHash: BYTES32_ZERO,
            stableFactory: UNSUPPORTED_PROTOCOL,
            stableInfo: UNSUPPORTED_PROTOCOL,
            // 🔴 PREDICTED, not yet deployed. These are the CREATE3 addresses the infinity-core
            // mainnet deploy will land on, derived from salt + factory alone by executing the
            // DEPLOYED testnet factory's bytecode at the mainnet factory address. The same
            // method reproduces testnet's own timelock 0xfE9811111C... exactly, which is the
            // control that makes them trustworthy rather than merely computed. All three were
            // checked EMPTY on 1776 when this file was written.
            //
            // ⚠️ They hold only if the factory is deployed from 0x02E0d5Fd... at nonce 0 and the
            // core salts do not move. This script runs in Phase 2, AFTER core has landed - so
            // re-read them from contracts/deployments/injective_mainnet.json and confirm they
            // match these three constants before broadcasting. A mismatch means a salt moved,
            // and a router wired to an empty address is a router that reverts on every swap.
            infiVault: 0xB67dd13b30ed21310be170968301eF83827B1Cad,
            infiClPoolManager: 0x6A4085Bb379e5213Df84Dc2dD52562559602b029,
            infiBinPoolManager: 0xfc6dd227f928Bf3396ff38Da00e19718f9CE7d7e
        });

        // 🔑 LEFT ZERO ON PURPOSE, unlike testnet. There is no UnsupportedProtocol on 1776, so
        // `run()` mints one and logs its address. Record that address in the mainnet address
        // book as infinity.unsupportedProtocol and add it to verify-all.sh in the same change
        // that deploys this router - it is a codeless-revert stub with no state and no owner,
        // but it is still an address the book has to learn exactly once.
        unsupported = address(0);
    }
}
