// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {UniverseRegistry} from "../src/UniverseRegistry.sol";
import {IUniverseWhitelist} from "damanfi-protocol/IUniverseWhitelist.sol";

contract UniverseRegistryTest is Test {
    UniverseRegistry registry;
    address curator = address(0xC1);
    address ticker1 = address(0xA1);
    address ticker2 = address(0xA2);
    address ticker3 = address(0xA3);
    bytes32 constant HLAL_2026Q2 = bytes32("HLAL_2026Q2");

    function setUp() public {
        UniverseRegistry impl = new UniverseRegistry();
        bytes memory initData = abi.encodeCall(
            UniverseRegistry.initialize,
            (curator, HLAL_2026Q2, address(this))
        );
        registry = UniverseRegistry(address(new ERC1967Proxy(address(impl), initData)));
    }

    function test_initialState() public view {
        assertEq(registry.curator(), curator);
        assertEq(registry.sourceTag(), HLAL_2026Q2);
        assertGt(registry.lastUpdatedAt(), 0);
        assertEq(registry.listAssets().length, 0);
    }

    function test_addAsset_curatorOnly() public {
        vm.prank(curator);
        registry.addAsset(ticker1, bytes32("hlal_seed"));
        assertTrue(registry.isEligible(ticker1));
        assertEq(registry.listAssets().length, 1);
    }

    function test_addAsset_revertsForNonCurator() public {
        vm.prank(address(0xBEEF));
        vm.expectRevert(abi.encodeWithSelector(IUniverseWhitelist.UnauthorizedCurator.selector, address(0xBEEF)));
        registry.addAsset(ticker1, bytes32("hlal_seed"));
    }

    function test_addAsset_revertsOnZeroAddress() public {
        vm.prank(curator);
        vm.expectRevert(UniverseRegistry.ZeroAddress.selector);
        registry.addAsset(address(0), bytes32("hlal_seed"));
    }

    function test_addAsset_revertsOnDuplicate() public {
        vm.prank(curator);
        registry.addAsset(ticker1, bytes32("hlal_seed"));
        vm.prank(curator);
        vm.expectRevert(abi.encodeWithSelector(IUniverseWhitelist.AssetAlreadyListed.selector, ticker1));
        registry.addAsset(ticker1, bytes32("hlal_seed"));
    }

    function test_removeAsset_swapsAndPops() public {
        vm.startPrank(curator);
        registry.addAsset(ticker1, bytes32("hlal_seed"));
        registry.addAsset(ticker2, bytes32("hlal_seed"));
        registry.addAsset(ticker3, bytes32("hlal_seed"));
        registry.removeAsset(ticker1, bytes32("compliance_drop"));
        vm.stopPrank();
        assertFalse(registry.isEligible(ticker1));
        assertTrue(registry.isEligible(ticker2));
        assertTrue(registry.isEligible(ticker3));
        assertEq(registry.listAssets().length, 2);
    }

    function test_removeAsset_revertsOnUnknown() public {
        vm.prank(curator);
        vm.expectRevert(abi.encodeWithSelector(IUniverseWhitelist.AssetNotListed.selector, ticker1));
        registry.removeAsset(ticker1, bytes32("unknown"));
    }

    function test_rotateCurator() public {
        vm.prank(curator);
        registry.rotateCurator(address(0xC2));
        assertEq(registry.curator(), address(0xC2));
        vm.prank(address(0xC2));
        registry.addAsset(ticker1, bytes32("hlal_seed"));
        assertTrue(registry.isEligible(ticker1));
    }

    function test_setSource_updatesTagAndTimestamp() public {
        uint64 t0 = registry.lastUpdatedAt();
        vm.warp(block.timestamp + 60);
        vm.prank(curator);
        registry.setSource(bytes32("HLAL_2026Q3"));
        assertEq(registry.sourceTag(), bytes32("HLAL_2026Q3"));
        assertGt(registry.lastUpdatedAt(), t0);
    }

    function test_setSource_revertsOnEmpty() public {
        vm.prank(curator);
        vm.expectRevert(UniverseRegistry.EmptySource.selector);
        registry.setSource(bytes32(0));
    }

    function test_initialize_revertsOnZeroCurator() public {
        UniverseRegistry impl = new UniverseRegistry();
        bytes memory bad = abi.encodeCall(
            UniverseRegistry.initialize,
            (address(0), HLAL_2026Q2, address(this))
        );
        vm.expectRevert();
        new ERC1967Proxy(address(impl), bad);
    }

    function test_initialize_revertsOnEmptySource() public {
        UniverseRegistry impl = new UniverseRegistry();
        bytes memory bad = abi.encodeCall(
            UniverseRegistry.initialize,
            (curator, bytes32(0), address(this))
        );
        vm.expectRevert();
        new ERC1967Proxy(address(impl), bad);
    }

    function test_pause_blocksWriteSurfaces() public {
        registry.pause();
        vm.prank(curator);
        vm.expectRevert();
        registry.addAsset(ticker1, bytes32("hlal_seed"));
    }

    function test_pause_keepsReadsOpen() public {
        vm.prank(curator);
        registry.addAsset(ticker1, bytes32("hlal_seed"));
        registry.pause();
        // Reads continue to work during pause.
        assertTrue(registry.isEligible(ticker1));
        assertEq(registry.listAssets().length, 1);
        assertEq(registry.sourceTag(), HLAL_2026Q2);
    }
}
