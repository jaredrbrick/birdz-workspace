# Multiple bases — design

_Drafted 2026-07-12 for Jared's review. His idea: "you should be able to have
more than one base." **DECIDED 2026-07-12** — Jared answered all five questions
(see Decisions below); phase 1 is building. Same pattern as the PvP doc:
options + recommendations + the specific questions._

## Today

One base per player. The game store holds `base: GameBase | null` and
`progress: Progress`; the cloud save is a single `PROGRESS` item = `{ base,
progress }`. A `GameBase` owns its `biomeId`, `fortName`, location, `ecoregionId`,
and installed `items[]`. Everything else — discovered birds, seeds, bond, score —
lives on `progress` at the **player** level. Spawns, visitors, and the shop are
all driven by the single base.

## The shape of the change

`base` (one) → `bases` (many) + an `activeBaseId`. Each base keeps its own biome,
name, location, and items. The active base drives the screen — spawns, visitors,
shop placement — exactly as the single base does today; switching bases just
changes which one is active.

```ts
interface GameBase {
  id: string            // NEW — stable id per base
  biomeId; fortName; builtAt; locationName?; coords?; ecoregionId?; items?
}
// store + PROGRESS item:
bases: GameBase[]
activeBaseId: string
progress: Progress      // unchanged — stays player-level
```

**Migration is clean and additive** (same style as the seeds/bond migrations):
an existing save's single `base` becomes `bases: [{ ...base, id }]` with
`activeBaseId` set to it. Old saves and the `types.ts` contract stay valid.

## Decisions (made 2026-07-12)

These change the data model, so they came first. Jared's answers:

1. **How many bases?** → **Cap of ~3.** Extra slots become a *seed sink* later
   (buy a new plot) — economy hook without unbounded UI.

2. **Bird discovery — shared or per-base?** → **Shared.** Your field guide is
   your life list as a birder. Discovery stays on `progress`.

3. **Seeds — one wallet or per-base?** → **One shared wallet.** Keeps the shop
   coherent and PvP payouts simple. Seeds stay on `progress`.

4. **Bond / relationships?** → **Home-base birds that can visit and, at high
   bond, relocate** (Jared's design, richer than either option offered):
   - Bond points stay **shared per-bird** — one relationship number, never reset.
   - A bird's **home base is the base where the relationship starts** (where it
     became a regular). Each base grows its own cast.
   - Birds you've already met can **appear as visitors at your other bases**
     early in the relationship.
   - As the relationship develops, a bird can **decide to move** to another of
     your bases — even a different biome. Relationship-gated migration.

5. **Building a base — same setup each time?** → **Yes.** Reuse the existing
   SetupBase flow (photo / map / "use my location") for each new base, so every
   base is a real place. A "+ New base" entry from the base screen.

## UI

- **Base switcher:** a control in the fort label (tap the fort name → a small
  list of your bases → switch). Switching sets `activeBaseId`; the spawner/visitor
  hooks already key off the active base's biome + ecoregion, so they just re-run.
- **New base:** "+ New base" → SetupBase → appends to `bases[]` (instead of
  replacing), respecting the cap.
- **Per-base header** already shows biome + region; it now reflects the active base.

## Phasing

1. **Phase 1 (building now):** `bases[]` + `activeBaseId` (cap 3), switcher,
   "+ New base" via SetupBase, per-base items, shared discovery + seeds + bond,
   additive migration. Regulars get a `homeBaseId` (existing regulars migrate to
   the current base) so phase 2 has its anchor. No visits/moves yet.
2. **Phase 2:** decision #4's mechanics — met birds visiting other bases,
   relationship-gated moves to another base/biome — plus a seed-priced base slot
   (decision #1's economy hook).

## Not in scope

Trading/visiting *other players'* bases, or per-base cosmetics beyond items.
All additive later. (Base-to-base bird migration was originally out of scope but
is now phase 2, per decision #4.)

---

**Bottom line:** decisions locked 2026-07-12 (cap 3, shared discovery + seeds,
home-base birds with visit/relocate mechanics, SetupBase reuse). Phase 1 is
building; phase 2 follows.
