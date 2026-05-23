## Universe seed source: HLAL (Wahed-FTSE-USA)

The flagship Daman deployment seeds `UniverseRegistry` against the published holdings of the Wahed-FTSE-USA screened ETF, ticker HLAL. Holdings are disclosed by the ETF sponsor on each rebalance window.

The HLAL constituents derive from FTSE Russell's published methodology. Daman's procurement-folder documentation (private) records the screening provenance and any deltas between published methodology and the procurement-grade standard for compliance buyers.

## Rebalance procedure

1. Pull the latest published HLAL holdings.
2. Compute the delta vs. the on-chain set: additions, removals.
3. Mint a new source tag (e.g. `HLAL_2026Q3`).
4. Call `setSource(newTag)` on the deployed registry.
5. Call `addAsset(asset, newTag)` for additions, `removeAsset(asset, reason)` for removals.

The pseudo-address derivation in `script/SeedHLAL.s.sol` is for development and demonstration. Replace with live tokenized-equity contract addresses on the target chain before production use.

## Alternate sources

The contract is curation-agnostic. Other deployments may seed from any source: thematic indices, sector lists, sanctions screens, ESG indices, custom screener output. The contract takes no opinion on the source; the `sourceTag` field records the provenance for downstream auditors.
