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

## Decisions — Jared, 2026-07-31

1. ~~Region size~~ — **answered by the data**: ship L3 (182) as the name
   players see and L2 (51) as the pool family. Both are in one file, so this
   isn't a tradeoff any more. Level IV (~1,000, US-only) exists if "hundreds"
   should later mean "over a thousand".
2. **Spawns: mostly region-locked.** ~80% from your region's L2 pool, ~20%
   widespread birds (robin, crow, house sparrow) so a new player in a thin
   region still has a game on day one. Travel is the point; an empty yard
   isn't.
3. **Outside North America: block base creation.** No generic fallback
   region. See the Hawaii caveat below before this ships.
4. **Map v1: your regions + neighbors.** Regions you've visited plus adjacent
   ones, bases pinned. Whole-continent browsing comes later.
5. **The manual biome override in SetupBase: delete it.** Region becomes a
   pure function of coordinates with no hand-picking, which is the entire
   point of a canonical map.

### Decision 3, settled — the CEC footprint *is* the playable world

Raised as a caveat and answered by Jared 2026-07-31: *"block everything not
covered in the CEC dataset."* No island carve-out, no generic fallback pool.
If `lookupRegion` returns null, base creation is refused.

Measured footprint: Alaska is in (Anchorage → Cook Inlet), as are Canada and
Mexico. **Out**: Hawaii, Puerto Rico, Guam, and everywhere off-continent.
Coastline artifacts are not affected — the 25 km snap runs first, so a
bayfront base still resolves.

The gate needs honest copy: tell the player Birdz covers continental North
America today, not that something went wrong with their location.

## Build order

1. ~~Pipeline script~~ **DONE** — `scripts/regions/build-regions.sh` +
   the built `na-ecoregions-l3.topo.json` and `lookup-test.mjs` are committed.
2. ~~`lookupRegion(lat, lng)` in birdzReact~~ **DONE** (PR #44) —
   `src/utils/regionLookup.ts` + `public/regions/na-ecoregions-l3.topo.json`,
   lazy-fetched and cached. Returns all three nesting levels. Measured
   **0.066 ms/lookup**, 34 ms to fetch and index; coastline snapping within
   25 km. 18 tests. Nothing imports it yet, so the bundle is unchanged.
3. ~~Map the roster's region tags onto L2 families~~ **DONE** (PR #45) —
   `src/data/regionFamilies.ts`. All 50 families joined to the legacy pool
   tags; measured pool sizes **25–47 birds** across the US and Canada.
   `L3_POOL_OVERRIDES` keeps the Mojave/Sonoran/Chihuahuan split that phase 2
   shipped, which the L2 grain would otherwise have re-merged. Same PR drops
   the **"Water" pseudo-region** — Chicago's lakefront was resolving to
   *Water* instead of Central Corn Belt Plains. Index is now 181 regions /
   50 L2 / 15 L1.
4. Setup / spawner / travelers / visitors read the canonical region. Bases
   gain `regionId`/`poolFamily` additively; keep `ecoregionId` mirrored for
   old cached clients, re-derived on load from each base's stored `coords`.
   Delete the manual biome override (decision 5) and gate creation outside
   NA (decision 3, pending the island caveat). Spawner applies the 80/20
   region-locked split (decision 2).
5. Region map UI — replaces the biome-card World Map: your regions, your
   forts, where you've been, what's adjacent to travel to.

## Risks worth naming

- **Roster thinness is now measured, not feared.** Pool sizes came out at
  **25–47 birds** across the US and Canada — healthy. The real gap is
  **Mexico**: it's inside the playable footprint but no bird carries a
  Mexican region tag, so a base in, say, the Neo-Volcanic System sees only
  the 20 universal birds. 19 of the 50 families are empty for the same
  reason (tundra, Sierra Madre, Mexican tropics). Region *names* will outpace
  region *character* until the roster grows; batch 8's pattern (7 birds per
  batch) is the lever, and a Mexico-focused batch is the highest-value one.
- **Licensing**: CEC/EPA ecoregions are US/Canada/Mexico government data,
  published for public use; the EPA page states no restriction. Worth one
  explicit confirmation before it ships in a monetized app.
- ~~**Coastlines**~~ **handled in PR #44**: nearest-region snapping within
  25 km. Verified — Puget Sound water and Key West both resolve, while 30 km
  off the Oregon coast correctly returns null.
