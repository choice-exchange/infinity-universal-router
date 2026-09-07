// SPDX-License-Identifier: GPL-2.0-or-later
// Copyright (C) 2026 Choice Exchange
pragma solidity ^0.8.24;

import {DeployUniversalRouter} from "../../DeployUniversalRouter.s.sol";
import {RouterParameters} from "../../../src/base/RouterImmutables.sol";

/**
 * Injective EVM testnet (chain 1439).
 *
 * Pre-req: CREATE3_FACTORY must be exported (PancakeSwap's factory is not on Injective;
 * see choice_v2 plan D2 - it is deployed from a dedicated nonce-0 EOA), and PRIVATE_KEY must
 * be a deployer WHITELISTED on that factory or `deploy` reverts `NotWhitelisted`.
 *
 * Step 1: Deploy
 * forge script script/deployParameters/testnet/DeployInjectiveTestnet.s.sol:DeployInjectiveTestnet -vvv \
 *     --rpc-url $RPC_URL \
 *     --broadcast \
 *     --gas-limit 12000000
 *
 * NEVER --slow. This docstring used to say `--slow`, and it contradicted its own next line:
 * forge waits for a receipt, Injective's testnet node has no hash index to find one by, and the
 * run is stranded after its first transaction. The same reason rules out --resume. Confirm with
 * eth_getCode instead, and pass an explicit generous --gas-limit because eth_estimateGas
 * under-reports on Injective.
 *
 * Step 2: `acceptOwnership()` from the deployer. `run()` only *offers* ownership - UniversalRouter
 * is Ownable2Step, and the offer is made in the factory's afterDeploymentExecutionPayload.
 *
 * Step 3: hand it to the timelock - `transferOwnership(timelock)` from the deployer, then
 * `acceptOwnership()` scheduled and executed BY the timelock. 🔴 Not optional and not cosmetic:
 * the owner is who can `pause()` the router, the previously deployed one is owned by the
 * timelock, and a router left owned by the deploy EOA is a hot key that can stop every swap.
 */
contract DeployInjectiveTestnet is DeployUniversalRouter {
    /// @notice contract address will be based on deployment salt
    ///
    /// 🔴 **A CREATE3 salt is an ADDRESS, so redeploying means bumping this.** `Create3Factory`
    /// derives the address from the salt alone; deploying the same salt twice lands on code that
    /// is already there and reverts. There is no env override, deliberately - the address a
    /// deployment lands on should be a reviewed line in a diff, not an environment variable.
    ///
    /// **1.1.0 exists because 1.0.0 carries a known bug in every ordinary user swap.** It was
    /// built from infinity-periphery 9be2647, before upstream's `9b026be` ("Fix: exact output
    /// partial fills", PR #96). `CLRouterBase` is reached by UniversalRouter -> Dispatcher ->
    /// InfinitySwapRouter -> InfinityRouter -> CLRouterBase, and before that fix an exactOutput
    /// swap never checked the pool delivered what was asked: a CL pool that ran out of liquidity
    /// before the price limit filled PARTIALLY, and the only guard - `amountIn > amountInMaximum`
    /// - passed precisely BECAUSE less was delivered. Partial fills on exact output need thin
    /// liquidity, which is what a newly deployed DEX has.
    ///
    /// ⚠️ A new router is a new Permit2 spender. Users must re-approve.
    function getDeploymentSalt() public pure override returns (bytes32) {
        return keccak256("INFINITY-UNIVERSAL-ROUTER/UniversalRouter/1.1.0");
    }

    function setUp() public override {
        params = RouterParameters({
            // canonical Permit2, already deployed on 1439 and 1776
            permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3,
            // wINJ: bank-backed wrapper, same address on both Injective nets
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
            // from contracts/deployments/injective_testnet.json, core M1 step 1
            infiVault: 0x17BDb95424cA07c31C23ecA9925CBA10818CBF6e,
            infiClPoolManager: 0x0d93E2E86e308F54eFca3f225487382cECF57F37,
            infiBinPoolManager: 0x88Af37259DB7775B4625449AeEa11Fc682452143
        });

        // 🔑 REUSE the UnsupportedProtocol 1.0.0 already deployed on 1439, rather than letting
        // `run()` mint a second one. It is a codeless-revert stub with no state and no owner, so
        // a second instance is not wrong - it is just a second address that
        // `contracts/deployments/injective_testnet.json` and `verify-all.sh` would both have to
        // learn, for a contract whose only job is to be pointed at. Keeping it makes the new
        // router's constructor arguments byte-identical to the old one's everywhere except the
        // code being deployed, which is exactly the diff a reviewer wants to see.
        // From contracts/deployments/injective_testnet.json: infinity.unsupportedProtocol.
        unsupported = 0xCB7340356Df545a6DCc10998078F3E0089640E2d;
    }
}
