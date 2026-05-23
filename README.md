# damanfi/universe

Asset-screening registry for Daman deployments. Reference implementation of `IUniverseWhitelist` from `damanfi/protocol`.

## What's here

`src/UniverseRegistry.sol` is a curator-permissioned implementation of `IUniverseWhitelist`. The curator address is set at deploy and may be rotated by the current curator. The contract takes no opinion on what the universe is or how it was curated; the `sourceTag` field records the provenance.

`script/SeedHLAL.s.sol` is the seed script for the flagship Daman deployment, which screens against the published HLAL (Wahed-FTSE-USA) ETF holdings. Other deployments may seed from any source.

`docs/HLAL_REBALANCE.md` documents the source choice and the rebalance procedure.

`test/UniverseRegistry.t.sol` covers the curator policy, add and remove behavior, source rotation, and revert conditions.

## Build

```
forge install foundry-rs/forge-std --no-commit
forge install damanfi/protocol --no-commit
forge build
forge test -vv
```

The `damanfi-protocol/` remapping in `foundry.toml` points at `lib/damanfi-protocol/src/`.

## Deploy

```
CURATOR_ADDRESS=0xYourCurator \
SOURCE_TAG=HLAL_2026Q2 \
ARC_TESTNET_RPC=https://rpc.testnet.arc.network \
  forge script script/SeedHLAL.s.sol --rpc-url arc_testnet --broadcast
```

## License

Apache-2.0.
