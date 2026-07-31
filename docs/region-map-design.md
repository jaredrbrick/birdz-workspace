# Region map — design draft (2026-07-30)

Jared's framing: *"ideally users will go to different regions, we need the idea
of a region map, it should be consistent between people in places."* Earlier
the same day: hundreds of regions eventually; bigger regions are fine;
consistency matters most; location comes only from photo GPS or a device ping
(#37, shipped).

## Goals

1. **Canonical**: one shared division of the world into named regions. Two
   players standing in the same place always get the same region — region
   assignment is a pure function of coordinates, not of per-player detection
   luck.
2. **Travel loop**: regions are the reason to physically go places. Your bases
   pin you to regions; travel + a new base = new birds.
3. **A map you can look at**: see the regions, where you've been, where your
   forts are, what's out there.

## Where today falls short

- Region = `lookupEcoregion(lat, lng, biomeClass)` over 18 hand-tuned lat/lng
  boxes, gated by a *fuzzily detected* biome (Overpass/Nominatim with
  confidence fallbacks). Same spot can resolve differently per player/run —
  exactly the inconsistency Jared is calling out.
- 18 regions ≠ "hundreds", and boxes overlap/gap at edges.

## Proposed direction — PROTOTYPED 2026-07-30, it works

**Dataset: CEC North American ecoregions, Level III.** Built end to end; real
numbers, not estimates (`scripts/regions/build-regions.sh` reproduces it):

| | |
|---|---|
| Source | CEC/EPA `NA_CEC_Eco_Level3.zip`, 34 MB, US government data |
| Raw polygons | 2,548 patches → **182 Level III regions** |
| Output | topojson, 563 KB raw / **178 KB gzipped** |
| Build time | **3.4 s** (mapshaper: reproject → dissolve → simplify 2% → clean) |
| Lookup | ray-cast point-in-polygon, **~3 ms per lookup** unindexed (a bbox pre-filter makes it trivial) |

**Three nested levels ship in the same file** — this is what makes the roster
problem disappear: **L1 = 16**, **L2 = 51**, **L3 = 182**. Players see the L3
name ("Blue Ridge", "Mojave Basin and Range"); spawn pools hang off L2 (51
families, close to today's 18 hand-made pools in spirit but principled). No
hand-authored mapping table needed — the grouping is in the data.

Lookup accuracy spot-check (all correct, including the null case):

| Point | Resolved |
|---|---|
| Bend, OR | Eastern Cascades Slopes and Foothills |
| **Castle Rock, CO** (Jared's screenshot) | **Southwestern Tablelands** |
| Death Valley, CA | Mojave Basin and Range |
| Great Smoky Mtns, TN | Blue Ridge |
| Seattle, WA | Strait of Georgia/Puget Lowland |
| New Orleans, LA | Mississippi Alluvial Plain |
| Mid-Pacific | none (outside NA) |

**That Castle Rock row is the bug in miniature**: the live app called that base
a *desert* ("Desert Station"), but Castle Rock is semiarid shortgrass prairie.
The canonical map gets it right, deterministically, for every player.

**Lookup: ship simplified polygons, point-in-polygon on the client.** 178 KB
gzipped as a lazy chunk (loaded only during base setup / map view) — smaller
than the AWS SDK chunk already shipping. Pure function of (lat, lng) against a
versioned file ⇒ identical for every player, works offline, zero server cost.
Biome detection stays for flavor/art, but region identity no longer depends on
it — which also removes the Overpass/Nominatim failure modes from the thing
that decides your birds.

**Bird pools: regions map to pool families.** We can't hand-curate 180 bird
pools. Keep the existing 18 pool ids as *families*; a generated
`l3RegionId → poolFamily` table assigns every canonical region to a pool.
Players see the fine-grained region name on the map; spawns draw from the
family pool. Deepen individual regions into their own pools over time (roster
growth continues to matter).

**Map UI:** render the same topojson as an SVG map — regions colored by state
(unvisited / visited / has-fort), tap for name + pool preview. This replaces
the current biome-card "World Map" page as the travel surface.

**Migration:** bases already store `coords` — re-derive each base's region
from the canonical map at load (one-time, additive field; keep the legacy
`ecoregionId` for old clients). Bases built before coords existed keep legacy
behavior.

## Open questions for Jared

1. ~~Region size~~ — **answered by the data**: ship L3 (182) as the name
   players see and L2 (51) as the pool family. Both are in one file, so this
   isn't a tradeoff any more. Level IV (~1,000, US-only) exists if "hundreds"
   should later mean "over a thousand".
2. **Region-locked spawns only?** Should home spawns come *only* from your
   region's pool (stronger travel incentive), or keep some universal birds
   (current behavior, gentler)? **This is the real design decision left.**
3. **Non-NA players**: generic fallback region (today's behavior), or a
   coarse global layer (WWF ecoregions) later?
4. **Map scope v1**: just your regions + neighbors, or the whole continent
   browsable?
5. **The manual biome override** in SetupBase's confirm step lets a player
   claim any biome regardless of location — it contradicts GPS-only placement
   and would let someone pick their region by hand. Delete it, or keep it only
   when detection confidence is `fallback`?

## Build order

1. ~~Pipeline script~~ **DONE** — `scripts/regions/build-regions.sh` +
   the built `na-ecoregions-l3.topo.json` and `lookup-test.mjs` are committed.
2. `lookupRegionCanonical(lat, lng)` in birdzReact (lazy-import the topojson,
   bbox pre-filter + point-in-polygon), returning `{ l3Id, l3Name, l2Id }`.
   Bases gain `regionId`/`poolFamily` additively; keep `ecoregionId` mirrored
   for old cached clients. Re-derive on load from each base's stored `coords`.
3. Map the 74-bird roster's existing region tags onto L2 families (mechanical:
   today's 18 pool ids each map to one or more of the 51 L2 names).
4. Setup / spawner / travelers / visitors read the canonical region.
5. Region map UI — replaces the biome-card World Map: your regions, your
   forts, where you've been, what's adjacent to travel to.

## Risks worth naming

- **Roster thinness is now visible.** 74 birds across 182 named regions means
  a player in, say, "Klamath Mountains" sees the L2 pool, not a bespoke one.
  That's fine and honest, but region *names* will outpace region *character*
  until the roster grows. Batch 8's pattern (7 birds/batch) is the lever.
- **Licensing**: CEC/EPA ecoregions are US/Canada/Mexico government data,
  published for public use; the EPA page states no restriction. Worth one
  explicit confirmation before it ships in a monetized app.
- **Coastlines**: at 2% simplification a bayfront base can land just outside
  its polygon. Mitigation: nearest-region fallback within a small radius
  rather than "outside NA".
