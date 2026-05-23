// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {UniverseRegistry} from "../src/UniverseRegistry.sol";

/// @notice Reference seed script for the flagship Daman deployment.
/// @dev Pseudo-asset addresses are deterministic placeholders derived
///      from ticker symbols. On any chain where real tokenized equity
///      addresses are available, replace the placeholder derivation
///      with the actual token contract addresses for each holding.
///      The source tag (`HLAL_2026Q2`) is a snapshot pointer; on each
///      rebalance, deploy a new tag and call `setSource` followed by
///      `addAsset` / `removeAsset` to reconcile against the new
///      published HLAL ETF holdings.
contract SeedHLAL is Script {
    // Representative seed subset. The full HLAL holdings list updates
    // on the published Wahed-FTSE-USA ETF rebalance schedule; this
    // subset demonstrates the screening surface end to end. Replace
    // with the live holdings before any production deployment.
    string[10] tickers = [
        "AAPL", "MSFT", "NVDA", "GOOGL", "JNJ",
        "XOM", "TSLA", "ABBV", "LLY", "PG"
    ];

    function placeholderAddress(string memory ticker) internal pure returns (address) {
        return address(uint160(uint256(keccak256(bytes(ticker)))));
    }

    function run() external {
        address curator = vm.envAddress("CURATOR_ADDRESS");
        bytes32 sourceTag = bytes32(bytes(vm.envOr("SOURCE_TAG", string("HLAL_2026Q2"))));

        vm.startBroadcast();
        UniverseRegistry registry = new UniverseRegistry(curator, sourceTag);
        for (uint256 i = 0; i < tickers.length; i++) {
            address asset = placeholderAddress(tickers[i]);
            registry.addAsset(asset, sourceTag);
        }
        vm.stopBroadcast();
    }
}
