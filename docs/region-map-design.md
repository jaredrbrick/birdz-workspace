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

## Proposed direction

**Dataset: CEC North American ecoregions, Level III** (~180 regions across
US/Canada/Mexico; the EPA publishes the US side; government data, public
domain). Level II (~50) is the fallback if we want bigger/fewer; Level IV
(~1000, US-only) if "hundreds" should be literal later. It's the only
harmonized NA-wide set with real names ("Sonoran Desert", "Blue Ridge") —
and real polygons, which is what makes consistency possible.

**Lookup: ship simplified polygons, point-in-polygon on the client.**
Simplify + quantize to topojson; NA Level III lands around a few hundred KB
gzipped as a lazy chunk (loaded only during base setup / map view). Pure
function of (lat, lng) against a versioned file ⇒ identical for every player,
works offline, zero server cost. Biome detection stays for flavor/art, but
region identity no longer depends on it.

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

1. **Region size**: Level III (~180, county-to-state sized) vs Level II
   (~50, bigger — you said bigger is OK). L3 feels right for "travel to a new
   region" density near home. Which?
2. **Region-locked spawns only?** Should home spawns come *only* from your
   region's pool (stronger travel incentive), or keep some universal birds
   (current behavior, gentler)?
3. **Non-NA players**: generic fallback region (today's behavior), or a
   coarse global layer (WWF ecoregions) later?
4. **Map scope v1**: just your regions + neighbors, or the whole continent
   browsable?

## Build order (once questions are answered)

1. Pipeline script: fetch CEC/EPA shapefiles → simplify → topojson + region
   metadata + pool-family table (build-time, committed artifact).
2. `lookupRegionCanonical(lat, lng)` + versioned region ids on bases; keep
   legacy id mirror.
3. Setup/travelers/visitors read canonical regions.
4. Region map UI page.
5. Region-tagging pass mapping families → the ~180 names players will now see.
