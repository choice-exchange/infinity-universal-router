// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {DeployUniversalRouter} from "../../DeployUniversalRouter.s.sol";
import {RouterParameters} from "../../../src/base/RouterImmutables.sol";

/**
 * Injective EVM testnet (chain 1439).
 *
 * Pre-req: CREATE3_FACTORY must be exported (PancakeSwap's factory is not on Injective;
 * see choice_v2 plan D2 - it is deployed from a dedicated nonce-0 EOA).
 *
 * Step 1: Deploy
 * forge script script/deployParameters/testnet/DeployInjectiveTestnet.s.sol:DeployInjectiveTestnet -vvv \
 *     --rpc-url $RPC_URL \
 *     --broadcast \
 *     --slow
 *
 * Never use --resume on Injective: receipts can come back null for a mined tx.
 * Confirm with eth_getCode.
 */
contract DeployInjectiveTestnet is DeployUniversalRouter {
    /// @notice contract address will be based on deployment salt
    function getDeploymentSalt() public pure override returns (bytes32) {
        return keccak256("INFINITY-UNIVERSAL-ROUTER/UniversalRouter/1.0.0");
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

        // no UnsupportedProtocol on Injective yet; run() deploys one when this is address(0)
        unsupported = address(0);
    }
}
