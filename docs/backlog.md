# Backlog

_Last groomed: 2026-07-30. Open items first; everything shipped is
archived at the bottom._

## Open

| Priority | Item | Status / notes |
|----------|------|----------------|
| P0 | Retention hooks ("Duolingo for birds") — remaining | Recent-visitors list SHIPPED 2026-07-30 (#35). Remaining: **spawn cadence** (Jared: wait-based mechanic is right but too fast — what if a bird only came every ~6h?) and daily-loop/streak mechanics. Note: spawns are client-side timers today (birds only come while the app is open), so real scarcity needs offline/wall-clock visits (computed from elapsed time on return, landing in the visit log), or sessions would usually be empty; also needs a carve-out so new players can still practice enough to learn calls. Needs a short design pass with Jared before building |
| P1 | Location integrity: photo or GPS ping only | Jared 2026-07-30: a **photo or device location ping should be the ONLY way to report a location** — retire the world-map picker path for base placement. Pairs with region consistency below |
| P2 | Regions at scale ("hundreds") | Jared 2026-07-30: "we should have hundreds honestly"; consistency matters most, bigger regions are OK. Today: 18 NA ecoregions via hand-tuned lat/lng boxes — hundreds means a real dataset (e.g. EPA/WWF ecoregions) + generated lookup, and enough roster depth per region to keep pools distinct |
| P1 | AdSense (Google side) | ads.txt + public pages live. **Review requested — awaiting Google** (days–weeks); ad placements wire up after approval. Blocked on Google |
| P2 | PvP phase 1.5 (remaining polish) | Result-return view SHIPPED 2026-07-12 (reopening a challenge shows win/lose). Left: a "my challenges" list (needs a by-user index — GSI or USER# pointer items) and rematch. Opaque-audio blind play dropped per Jared (audio URLs already public in single-player, so it adds no real protection) |
| P2 | S3 lifecycle rules (cost audit, 2026-07-13) | All 5 buckets have versioning on with **no lifecycle rules** — old versions of every deployed file accumulate forever (invisible at 37 MB, the classic "S3 bill makes no sense" cause at scale). Add via Terraform (static-site module + bootstrap): site buckets (dev/test/staging/prod) expire noncurrent versions after **30 days** (Jared approved) + delete expired object delete markers + abort incomplete multipart uploads after 7 days; terraform-state bucket keeps a generous window (90–365 days — it's the safety net). Skip Intelligent-Tiering/Glacier (per-object monitoring fee, sub-128KB objects excluded — wrong fit for a static site). Audit aside worth doing sometime: daily-use IAM user/role instead of the root user |
| P2 | Ecoregion phase 3: region art | Region-flavored palettes/art. Waits on real art direction (emoji-first decision stands until the project makes money) |
| P2 | Roster growth (post-67) | 67 birds after batch 7 (2026-07-13, Jared: "keep adding more birds"). Every region pool now has tagged birds (prairie-potholes got its first); thinnest pools are appalachians (4) and mojave-desert (4) |
| P2 | 13 birds still silent | cactus_wren, gambels_quail, brown_pelican, varied_thrush, roseate_spoonbill, american_oystercatcher, sage_thrasher, greater_sage_grouse, scaled_quail, black_oystercatcher, western_kingbird, phainopepla, pinyon_jay — zero commercially-safe recordings. **Do NOT auto-recheck (Jared, 2026-07-11 — token waste); revisit only when Jared asks** (batch 7 birds are NOT on this list — all 7 have staged audio) |

## Shipped (archive)

**2026-07-30:**

- **Base cap 5 + cheaper plots (#36) — live dev/test/staging**: MAX_BASES 3→5, SLOT_COSTS [0,250,500]→[0,50,100,200,300] per Jared ("more bases from the start, maybe 5"; old prices "too expensive"). Both one-line tunable; guard test ensures every plot below the cap has a price. **Curve is Claude's proposal — Jared may want different numbers**
- **Recent visitors list (#35) — first slice of the retention P0, live dev/test/staging**: base sidebar opens with the newest 6 visits (deduped per bird) — relative times, ✈️ for travelers, ??? until the bird is identified. New permanent `Progress.visitLog` (capped 50) written by a `recordVisit` store action that folds the spawner's visit-bond grant and the log entry into one write. 202 tests + headless drive (organic veery visit through the real spawner) green. This list is the landing surface for future offline/wall-clock visits
- **Difficulty curve (#34) — P0 from playtest, live dev/test/staging**: a bird's first identify session shows its photo ("🐣 New bird!"), the next two blur it progressively (7px → 16px+grayscale), 4th+ is sound-only — teach first, then quiz. New permanent `Progress.encounters` per-bird count (history is capped at 50 so it couldn't serve), backfilled for old saves from history + discovered (≥1) + mastered (≥3). Generic alt text so the name doesn't leak; hints/scoring/PvP untouched. 191 tests + headless drive green. **Promoting test/staging also carried #32/#33 (prerender + crawlability) and the roster expansion to those envs for the first time (they'd been dev-only); Terraform applied the spa-router CloudFront function to test/staging too. Prod untouched — needs Jared's "promote prod" (that promotion now carries #32–#34 + roster; AdSense re-review waits on it)**

**2026-07-13:**

- **Roster batch 7 (#31) — COMPLETE, live in prod**: 60 → 67 — California Quail, Anna's Hummingbird, Purple Gallinule, Green Heron, Veery, Dickcissel, American Avocet. Targets the thinnest region pools (pacific-coast & california-grasslands 3→5, everglades 3→5, appalachians 3→4) and prairie-potholes finally has a tagged bird. Green Heron chosen over White Ibis (ibis has zero commercially-safe recordings). Media: **Jared ran the S3 upload himself** (session creds were proxy placeholders) — all 7 birds serve audio + photos on all 4 envs, manifests at 54 audio / 67 photos, verified over HTTP. 47+7=54 birds now have audio

**2026-07-10 — the big day (birdzReact PRs #5–#12, all live in prod):**

- DynamoDB persistence (#5): cloud saves via Cognito Identity Pool, localStorage as offline cache
- Biome detection reliability + iPhone fix (#6): retries, Overpass mirror, honest fallback UI, `?debug=1` trace, device-geolocation button (iOS strips GPS EXIF from uploads)
- Bird-call audio (#7): banner ♪ + identify-screen playback, CC/PD recordings with in-app attribution; 27 of 30 birds have audio in all envs
- Bundled Leaflet (#8): unpkg CDN dependency removed
- Error surfacing + coverage (#9): localStorage failures warn; CI runs coverage (45% lines baseline)
- Ecoregion phase 1 (#10): 18 NA regions, "Pacific Coast" instead of "Atlantic Coast" in California; generic fallbacks elsewhere
- Roster batch 1 (#11): killdeer, western gull, Steller's jay, white-crowned sparrow, common poorwill, sandhill crane — every biome pool ≥4 birds
- Base building phase A (#12): 8-item shop, seeds economy (split from score), rare birds gated behind preferred items, catered birds spawn 2×

**2026-07-11:**

- Base building phase B (#13): grounded visitors — catered birds land, hop, and wander near their items; tap for name card (or ??? + identify nudge)
- ads.txt (#14): Jared's AdSense publisher ID served at the domain root
- Base building phase C (#15): 💭 wants, 0–5 relationship hearts, regulars with seed gifts — **base building complete (all 3 phases)**
- Roster batch 2 + ecoregion phase 2 (#16): 6 region-flavored birds (36 total, 30 with audio) and region-gated pools — Pacific vs Atlantic coasts, Sonoran vs Mojave vs Chihuahuan deserts finally feel different
- Roster batch 3 (#17): sagebrush country (Sage Thrasher, Greater Sage-Grouse) + Burrowing Owl, Common Loon, Belted Kingfisher, Common Raven — 42 birds, 33 with audio
- Roster batch 4 (#18): Appalachian/boreal/Chihuahuan fills — Ruffed Grouse, Canada Jay, Scaled Quail, Pyrrhuloxia, Eastern Towhee, Dark-eyed Junco — 48 birds, 38 with audio
- Roster batch 5 (#19): eastern/coastal/wetland fills — Carolina Wren, Limpkin, Herring Gull, Black Oystercatcher, Western Kingbird, Prothonotary Warbler — 54 birds, 42 with audio (fills appalachians, everglades, gulf-bayous, great-lakes, pacific-coast, great-plains)
- Roster batch 6 (#20): **60-bird target hit** — Scarlet Tanager, White-throated Sparrow, Anhinga (NPS Everglades recording), Ring-billed Gull, Phainopepla, Pinyon Jay — 60 birds, 46 with audio
- Public pages (#21): /guide (full 60-bird field guide from birds.ts), /privacy (AdSense cookie disclosure + opt-out links), /about — AdSense review readiness; landing links all three
- Guest Mode (#22): "play as a guest" on landing — full game, localStorage-only saves (zero cloud traffic), signup-upsell banner, guest→account migration when cloud is empty; single-flight hydrate fixes a signup migration race
- Bird data audit (#23): reviewed all 60 birds (Jared's ask re: original weaker-model entries). Data held up well; fixed Osprey fishing-success overstatement, Brown Pelican "only pelican that dives" error, and tagged Eastern Meadowlark to great-plains so California grasslands get the Western only
- Photo reveal (#24): real bird photo shown on the identify result screen (correct guess or give-up) with a credit line. All 60 birds have a curated commercially-safe Wikimedia photo (CC0/PD/CC-BY/CC-BY-SA), hosted in S3 photos/ like audio; deploy sync excludes photos/*. Caught + fixed a promote bug where git merge didn't advance the submodule pin (envs shipped stale code until pins were forced to f8801d7)
- Audio recheck (no PR, out-of-pipeline S3 sync): burrowing_owl gained a call (CC BY-SA, XC909267) and mountain_bluebird upgraded from a low-quality clip to a Yellowstone NPS public-domain recording — 47 of 60 birds now have audio
- **PvP phase 1 (backend PRs terraform + client #25) — LIVE in all envs**: async "bird-off" — Challenge a friend on the base → share link → both play the same 10 calls → win/lose/tie + seeds (winner 25 / loser 5 / tie 15). First server-side compute in the stack: API Gateway HTTP API + Lambda (JWT-authed by the user pool) + the existing DynamoDB table; server owns the answer key + scoring + seed grant. Seed payout verified landing on real cloud saves. Real account required to play (invite returns guests via signup)
- PvP result-return view (Lambda GET `?me=` + client PR #26): reopening a challenge you've played shows the outcome (win/lose/tie, both scores) instead of the play button — closes the creator's "did I win?" gap. Verified live two-player on dev + prod

**2026-07-12 (afternoon):**

- **Prod promoted** — multiple bases phases 1+2 (#27/#28) live on birdzgame.com per Jared's go; prod bundle verified identical to staging
- **Dead CSS-module animations + iPhone Base layout (#29)**: Jared's screenshot (clipped "blue dot" bird, Challenge button overlapping the fort label, stats digits cut off by the bottom sheet) led to a root cause: every animation referenced from a *.module.css was localized to a hashed name while the keyframes sat in a global animations.css — birds never actually flew, visitors never hopped. Keyframes now live in the modules that use them; flight moved to the sprite root; a calling bird pauses mid-flight (call fires 30–60% into the crossing so it's on-screen); mobile fort label ellipsizes short of the Challenge button; bottom sheet adds env(safe-area-inset-bottom) with stats pinned. Verified headless at 390×844
- **Visitor card guess-call button (#30, Jared's ask)**: the "???" card's passive hint is now a 🎧 "Guess its call" button (triggerVisitorCall → identify screen, normal scoring/bond flow), and the card pins to the visitor's near edge instead of hanging off the viewport
- **#29 + #30 promoted to prod** same day (Jared's go) — all four envs serve the same bundle; verified the guess button in prod's served JS

**2026-07-12:**

- AdSense CMP consent banner: **done by Jared in his AdSense account** (Privacy & messaging, Google's certified CMP). Loads via the AdSense tag once ad placements ship post-approval — no code change needed
- Multiple-bases design finalized: Jared answered all 5 decisions (cap 3; shared discovery + seeds; bond shared with home-base birds that can visit and later relocate; SetupBase reused per base). Phase 1 started
- **Multiple bases phase 1 (#27)**: bases[] + activeBaseId (cap 3), fort-label base switcher, "+ New base" via SetupBase, per-base items, progress.birdHomes (phase 2 anchor), additive migration with legacy `base` mirror for old cached clients; world-map build now routes through SetupBase. 172 tests green; verified headless end-to-end (migration, switcher, geolocation build, per-base items, cloud save shape in dev DynamoDB). Deployed: dev + test + staging; **prod promotion awaiting Jared's go** (permission gate)
- **Multiple bases phase 2 (#28) — MULTIPLE BASES COMPLETE**: travelers (birds at ≥1 heart visit your other bases regardless of biome/items, ✈️ card shows home fort, works on an empty base), relocation (visiting regular has 20% chance to move in, 🏡 announced, birdHomes updates; regular perks now home-base-only), seed-priced plots (SLOT_COSTS 0/250/500, gated in switcher + SetupBase). 182 tests; verified headless incl. a live Wood Thrush traveling forest→coast. Deployed dev + test + staging; prod pending with phase 1

**Earlier (2026-05 → 2026-07-09):**

- Domain migration to birdzgame.com — DNS + ACM fully Terraform-managed (Cloudflare provider)
- AWS hosting: S3 + CloudFront × 4 envs, GitHub Actions OIDC pipeline, SSM deploy config (no PATs)
- Real Cognito SRP auth (pre-signup auto-confirm); password policy 8+ with complexity
- Mobile layout (PR #4), hint scoring fix (#3), bird lifecycle fixes (#1, #2), CI on every PR
- Hints independently selectable (2026-03-26)
