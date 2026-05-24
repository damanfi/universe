// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

import {UniverseRegistry} from "../src/UniverseRegistry.sol";

/// @notice Atomic deployer for the UniverseRegistry on Arc testnet.
///
/// Flow:
///   1. Deploy the TimelockController (Safe address from env is the
///      proposer + executor + admin).
///   2. Deploy the UniverseRegistry implementation.
///   3. Deploy the ERC1967 proxy with the TimelockController as
///      initial owner and the configured curator address.
///   4. Verify on-chain that proxy ownership sits at the Timelock.
///
/// The Safe is deployed out-of-band before this script runs and
/// passed via SAFE_ADDRESS env. The deployer EOA holds no authority
/// over the proxy past this script.
contract DeployUniverse is Script {
    function run() external {
        address deployer = vm.addr(vm.envUint("PRIVATE_KEY"));
        address safe = vm.envAddress("SAFE_ADDRESS");
        address curator = vm.envAddress("CURATOR_ADDRESS");
        bytes32 sourceTag =
            bytes32(bytes(vm.envOr("SOURCE_TAG", string("HLAL_2026Q2"))));
        uint256 timelockDelay = vm.envOr("TIMELOCK_DELAY_SECONDS", uint256(86400));

        console2.log("deployer EOA:", deployer);
        console2.log("Safe multisig:", safe);
        console2.log("curator:", curator);

        vm.startBroadcast();

        address[] memory proposers = new address[](1);
        proposers[0] = safe;
        address[] memory executors = new address[](1);
        executors[0] = safe;
        TimelockController timelock = new TimelockController(timelockDelay, proposers, executors, safe);
        console2.log("Timelock:", address(timelock));

        UniverseRegistry impl = new UniverseRegistry();
        UniverseRegistry registry = UniverseRegistry(address(new ERC1967Proxy(
            address(impl),
            abi.encodeCall(UniverseRegistry.initialize, (curator, sourceTag, address(timelock)))
        )));
        console2.log("UniverseRegistry impl:", address(impl));
        console2.log("UniverseRegistry proxy:", address(registry));

        vm.stopBroadcast();

        require(registry.owner() == address(timelock), "registry owner is not Timelock");

        console2.log("--- Ownership verified. Timelock controls UniverseRegistry. ---");
        console2.log("Persist these addresses to .deployments/arc-testnet.json:");
        console2.log("  timelock:", address(timelock));
        console2.log("  universeRegistry.proxy:", address(registry));
    }
}
