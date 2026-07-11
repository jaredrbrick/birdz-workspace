# Base Building & Bird Relationships (Design Note)

Jared's description (2026-07-10, recovering the mechanic dropped from the 07-09
handoff): *"add things to your base that could attract better birdz — I want
birdz to walk around your base like Animal Crossing — we need to be doing more
to make it 'game like' — they should have preferences and want items and have a
relationship stat."*

Four pillars, phased so each ships alone:

## Phase A — Items & attraction

- **Item catalog**: feeders (seed/suet/nectar), bird bath, berry bushes, nest
  box, brush pile… Each item carries attraction tags.
- **Bird preferences**: each species lists preferred items (`prefers:
  ['suet_feeder', 'dead_tree']` on the bird data). Rarer birds require their
  preferences installed before they enter the spawn pool — items are how you
  "attract better birdz".
- **Spawn weighting**: installed items reshape the base's spawn pool — more of
  what you cater to, rare visitors only when their needs are met.
- **Currency**: identifications already award points; split lifetime **score**
  (leaderboard-ish, unchanged) from spendable **seeds** earned per correct ID.
  Items cost seeds.
- Persistence: new `ITEMS` record in the existing game-data table (the
  sort-key design anticipated new record types).

## Phase B — Grounded visitors (the Animal Crossing feel)

- New **visitor** behavior alongside fly-over spawns: birds land and hop/walk
  around the base scene, lingering near their preferred items, with idle
  animations (peck, hop, preen).
- Tappable: shows the bird's card (name if discovered, silhouette if not) —
  the base becomes a living scene rather than a spawn corridor.

## Phase C — Wants & relationships

- **Wants**: a visiting bird occasionally shows a request bubble (an item it
  wishes the base had). Fulfilling it grants a relationship boost.
- **Relationship stat** per species (e.g. 0–5 hearts), grown by: correct
  identifications, fulfilled wants, and repeat visits while preferences are
  installed. Stored as `RELATIONSHIP#<birdId>` records (or folded into
  PROGRESS if small).
- Rewards for high bond: the bird becomes a regular (guaranteed periodic
  visitor), unlocks extra facts/portrait, occasional seed gifts.

## Open questions for Jared

1. **Currency**: OK splitting score (lifetime) from seeds (spendable), or
   should items spend down the existing score?
2. **Art**: items as emoji/CSS in the current style, or is this the moment for
   real sprites?
3. **Scope of relationship**: purely collection/cosmetic, or should high bonds
   affect gameplay (e.g. easier identification hints for befriended birds)?
4. Rough catalog size to launch phase A — ~8 items?

## Dependencies & fit

- DynamoDB persistence: live (PR #5) — no blockers.
- Pairs naturally with the roster expansion (more species = more preference
  variety) and ecoregion phase 2 (regional visitors).
- PvP (also restored from the dropped handoff line) stays separate — it needs
  the server-side API path (persistence-design.md option B).
