# Multiple bases — design

_Drafted 2026-07-12 for Jared's review. His idea: "you should be able to have
more than one base." **No code until the decisions below are made** — they set
the data model. Same pattern as the PvP doc: options + recommendations + the
specific questions._

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

## Decisions I need (the crux)

These change the data model, so they come first. Recommendations in **bold**.

1. **How many bases?**
   - Options: unlimited · a flat cap · a cap that unlocks with progress (e.g., 1
     free, more at score/discovery milestones or bought with seeds).
   - **Rec: start with a small cap of ~3**, and make extra slots a *seed sink*
     later (buy a new plot). Gives the economy something to do and a progression
     hook, without unbounded UI.

2. **Bird discovery — shared or per-base?**
   - **Rec: shared.** Your field guide is your life list as a birder; re-discovering
     the same chickadee at each base would feel like busywork. Discovery stays on
     `progress`.

3. **Seeds — one wallet or per-base?**
   - **Rec: one shared wallet.** A single economy keeps the shop coherent; per-base
     seeds would fragment it and complicate PvP payouts. Seeds stay on `progress`.

4. **Bond / relationships — shared or per-base?** (the interesting one)
   - Bond is currently per-bird at the player level. With multiple bases there are
     two feels:
     - **Shared bond** (simpler): you have one relationship with "the Northern
       Cardinal" regardless of where you meet it.
     - **Per-base regulars** (more Animal-Crossing, which you asked for): a bird
       becomes a *regular at the base it frequents* — your forest base has its
       crew, your coast base has another.
   - **Rec: bond points stay shared per-bird, but "regular" status is per-base.**
     You keep one relationship number, but each base grows its own cast of
     regulars — closest to the Animal-Crossing feel without resetting affection.

5. **Building a base — same setup each time?**
   - **Rec: yes** — reuse the existing SetupBase flow (photo / map / "use my
     location") for each new base, so every base is a real place. A "+ New base"
     entry from the base screen or world map.

## UI

- **Base switcher:** a control in the fort label (tap the fort name → a small
  list of your bases → switch). Switching sets `activeBaseId`; the spawner/visitor
  hooks already key off the active base's biome + ecoregion, so they just re-run.
- **New base:** "+ New base" → SetupBase → appends to `bases[]` (instead of
  replacing), respecting the cap.
- **Per-base header** already shows biome + region; it now reflects the active base.

## Phasing

1. **Phase 1:** `bases[]` + `activeBaseId`, switcher, "+ New base", per-base items,
   shared discovery + seeds, migration. Bond stays shared (no regression). This is
   the whole feature at its simplest.
2. **Phase 2 (optional):** per-base regulars (decision #4's richer half), and a
   seed-priced base slot (decision #1's economy hook).

## Not in scope

Trading/visiting *other players'* bases, base-to-base bird migration, or
per-base cosmetics beyond items. All additive later.

---

**Bottom line:** the build is straightforward and the migration is safe; it's
gated only on decisions #1–#4. If you're happy with the bolded recommendations
(cap 3, shared discovery + seeds, shared bond with per-base regulars), say so and
I'll build phase 1.
