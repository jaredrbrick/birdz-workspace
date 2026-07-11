# Backlog

_Last groomed: 2026-07-10 (evening). Open items first; everything shipped is
archived at the bottom._

## Open

| Priority | Item | Status / notes |
|----------|------|----------------|
| P1 | Bird roster batches 3+ | 36 birds now; target ~60. Batch 3 should include Great Basin sagebrush specialists (sage thrasher, sage sparrow — its pool is thinnest at 1) |
| P1 | AdSense | ads.txt live at birdzgame.com/ads.txt (2026-07-11, PR #14). **Awaiting Google's review** (days–weeks); ad placements wire up after approval |
| P2 | PvP | Needs the server-side API path first (persistence-design.md option B: API Gateway + Lambda). Design discussion before any code |
| P2 | Ecoregion phase 3: region art | Region-flavored palettes/art. Waits on real art direction (emoji-first decision stands until the project makes money) |
| P2 | 6 birds still silent | cactus_wren, gambels_quail, brown_pelican, varied_thrush, roseate_spoonbill, american_oystercatcher — zero commercially-safe recordings anywhere today; recheck occasionally. mountain_bluebird has audio but low quality (only non-NC option) — upgrade when possible |

## Shipped (archive)

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

**Earlier (2026-05 → 2026-07-09):**

- Domain migration to birdzgame.com — DNS + ACM fully Terraform-managed (Cloudflare provider)
- AWS hosting: S3 + CloudFront × 4 envs, GitHub Actions OIDC pipeline, SSM deploy config (no PATs)
- Real Cognito SRP auth (pre-signup auto-confirm); password policy 8+ with complexity
- Mobile layout (PR #4), hint scoring fix (#3), bird lifecycle fixes (#1, #2), CI on every PR
- Hints independently selectable (2026-03-26)
