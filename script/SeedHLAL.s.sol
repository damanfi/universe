// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {UniverseRegistry} from "../src/UniverseRegistry.sol";

/// @notice Seed an already-deployed UniverseRegistry proxy with a
///         representative subset of HLAL holdings. Runs AFTER
///         `DeployUniverse.s.sol` has minted the proxy + Timelock.
///         The curator (set at proxy initialize) signs the addAsset
///         calls; PRIVATE_KEY in env is that curator key.
///
/// @dev    Pseudo-asset addresses are deterministic placeholders
///         derived from ticker symbols. On any chain where real
///         tokenized equity addresses are available, replace the
///         placeholder derivation with the actual token contract
///         addresses for each holding. On each rebalance, mint a
///         new source tag, call `setSource(newTag)` from the
///         curator, then call `addAsset` / `removeAsset` to
///         reconcile against the new published HLAL holdings.
contract SeedHLAL is Script {
    string[10] tickers = [
        "AAPL", "MSFT", "NVDA", "GOOGL", "JNJ",
        "XOM", "TSLA", "ABBV", "LLY", "PG"
    ];

    function placeholderAddress(string memory ticker) internal pure returns (address) {
        return address(uint160(uint256(keccak256(bytes(ticker)))));
    }

    function run() external {
        address registryAddr = vm.envAddress("UNIVERSE_REGISTRY_ADDRESS");
        bytes32 sourceTag =
            bytes32(bytes(vm.envOr("SOURCE_TAG", string("HLAL_2026Q2"))));

        UniverseRegistry registry = UniverseRegistry(registryAddr);
        console2.log("seeding UniverseRegistry proxy:", registryAddr);

        vm.startBroadcast();
        for (uint256 i = 0; i < tickers.length; i++) {
            address asset = placeholderAddress(tickers[i]);
            registry.addAsset(asset, sourceTag);
        }
        vm.stopBroadcast();

        console2.log("--- Seeded", tickers.length, "placeholder assets. ---");
    }
}
