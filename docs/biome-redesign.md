# Biome → Ecoregion Redesign (Proposal)

Backlog P1. Referenced in HANDOFF-2026-07-09 as the "ecoregion redesign" but the
plan was never written down; this reconstructs it as a concrete proposal for
Jared's review. **No implementation until this doc is agreed.**

## Why

The game has six hard-coded biomes (`forest`, `grassland`, `wetland`, `desert`,
`mountain`, `coastal`) that conflate two different things:

1. **Gameplay mechanics** — spawn rules, background art, fort names. Six classes
   is a fine number here.
2. **Regional identity** — display names, bird pools. Six is wrong here: the
   display names bake in one region per class ("Atlantic Coast", "Sonoran
   Desert"), so a player building a base in Santa Cruz is told they live on the
   **Atlantic** coast. And every forest player from Maine to Oregon sees the
   same four birds.

Detection (now reliable, birdzReact PR #6) also throws away information: OSM
tells us "this is Monterey Bay" and we reduce it to `coastal`.

## Proposal: split the two layers

Keep the six **biome classes** as the mechanical layer. Add a data-driven
**ecoregion** layer on top for identity:

```ts
interface Ecoregion {
  id: string            // 'pacific-coast'
  name: string          // 'Pacific Coast'
  biomeClass: BiomeId   // mechanics + art inherited from the class
  bounds: Bounds[]      // coarse lat/lng boxes, first match wins
  birdPool?: string[]   // optional region-specific bird ids (phase 2)
}
```

- `GameBase` gains optional `ecoregionId` (additive — existing DynamoDB saves
  and `types.ts` API contract stay valid; old saves keep class-level visuals).
- Detection: after the existing coords → biome-class step, a small
  lat/lng-box lookup picks the ecoregion (~15 regions covering North America
  to start, a few KB of data — no GeoJSON bundle, no new APIs). Unmatched
  coords fall back to a class-generic name ("Coastal Shores").
- The confirm screen and base header show the ecoregion name; fort names stay
  per-class.

## Phases

| Phase | Scope | Size |
|-------|-------|------|
| 1 | Ecoregion data + lookup + display names (fixes the "Atlantic Coast in California" bug) | small — one PR |
| 2 | Per-region bird pools: birds gain `regions?: string[]`; spawner prefers region pool, falls back to class pool. Needs ~2–4 new birds per region to feel different (bird data authoring is the real cost) | medium, incremental per region |
| 3 (optional) | Region-flavored palettes/art variants | cosmetic, whenever |

## Explicitly not proposed

- Real ecological datasets (EPA/WWF ecoregion polygons): hundreds of regions
  and MB-scale geometry for a 24-bird game. Coarse boxes + honest fallback
  names achieve the player-facing goal.
- Changing spawn mechanics — six classes keep working as today.

## Open questions for Jared

1. North America only to start (matches current bird data), or should the
   region set cover Europe/global from day one?
2. Phase 2 bird authoring: happy to grow the roster ~2–4 birds per region
   (each needs calls/hints/facts — and ideally a recording, see audio
   sourcing note in backlog)?
3. Should ecoregion affect difficulty/scoring, or stay purely cosmetic?
