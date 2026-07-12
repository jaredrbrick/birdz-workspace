# PvP design — cost-first

_Drafted 2026-07-11. Jared's steer: **pricing is a primary factor in the
recommendation.** This doc leads with cost, then works back to a mechanic and an
architecture that fits it._

## TL;DR

- **Recommended mechanic: asynchronous "challenge" PvP** (you play a fixed set of
  bird calls; a friend plays the *same* set later; scores are compared). It is
  both the **cheapest** option and the only one that actually works at launch
  scale, when two players are almost never online at the same moment.
- **Recommended architecture: API Gateway (HTTP API) + Lambda + the existing
  DynamoDB table**, authorized by the Cognito user-pool JWT we already issue.
  All serverless, all scale-to-zero.
- **Estimated cost at 1,000 daily players: ~$3–5/month. At today's scale (dozens
  of players): effectively $0** — it sits inside the AWS always-free tier.
- **Avoid real-time duels for now.** WebSockets/AppSync cost more per user, add a
  lot of engineering, and — the real dealbreaker — need a live opponent, which a
  new game doesn't have. Revisit only if there's a proven, active player base.

## Why PvP needs new infrastructure at all

Single-player Birdz uses **Option A** from [persistence-design.md](persistence-design.md):
the browser talks *directly* to DynamoDB with Cognito Identity Pool credentials,
scoped by IAM so each user only touches their own rows. That is perfect for
"save my progress" and costs almost nothing.

It cannot do PvP. The moment a score is competitive, the client can't be trusted
to report it — a direct-to-DynamoDB player can just write `score: 9999`. PvP
needs a **server that owns the answer key and computes the score**. That's
**Option B** (API Gateway + Lambda in front of the same table), which
persistence-design.md already anticipated as "the natural place for future
cross-user features." So PvP is the thing that finally justifies standing up the
API tier — and it should be built cost-consciously from the first line.

## Mechanic options (and why cost separates them)

### 1. Async challenge — RECOMMENDED
You start a challenge; the server picks N bird calls (say 10) and an order, and
stores them. You play, the server scores you. You get a share link / pick a
friend; they play the identical set; the server scores them and shows the
head-to-head. No one has to be online together.

- **Infra:** a handful of HTTP requests per challenge. Scale-to-zero.
- **Works at any scale**, including two users in different time zones.

### 2. Daily/weekly tournament (a variation of #1)
Everyone plays the *same* daily set; a leaderboard ranks them. Same backend as
#1 plus one shared "daily challenge" record and a leaderboard query. Cheap.
Great retention hook. Natural phase 2.

### 3. Real-time duel — NOT recommended yet
Two players ID the same calls simultaneously with a live scoreboard.

- **Infra:** persistent WebSocket connections (API Gateway WebSocket API or
  AppSync subscriptions), connection state, matchmaking, presence.
- **Cost:** pays per connection-minute *and* per message, plus a Lambda per
  message — materially more than async, and it never scales to zero while anyone
  is connected.
- **Bigger problem than cost:** matchmaking. With dozens of users, nobody is
  online at the same time, so there's no one to duel. Real-time only becomes fun
  *after* the game is popular — exactly when we can afford to revisit it.

## Cost breakdown

AWS pricing used below (us-east-1, on-demand, as of 2026; the always-free tier is
perpetual, not just the 12-month trial where noted):

| Service | Unit price | Free tier |
|---|---|---|
| **API Gateway HTTP API** | $1.00 / million requests | 1M req/mo for first 12 months |
| **Lambda** | $0.20 / million requests + $0.0000166667/GB-s | 1M req/mo + 400k GB-s/mo, **perpetual** |
| **DynamoDB on-demand** | $1.25 / million writes, $0.25 / million reads | 25 GB storage; (25 WCU/RCU perpetual only on provisioned) |
| **API Gateway WebSocket** | $1.00 / million messages + $0.25 / million connection-minutes | 1M msg/mo for first 12 months |
| **AppSync** | $4.00 / million queries + $2.00 / million real-time updates | 250k queries/mo for first 12 months |

Note we use **HTTP API, not REST API** — REST is $3.50/million, 3.5× more, and we
don't need its extra features.

### Scenario: async challenge at 1,000 daily active players

Assume each player does 5 PvP rounds/day → 150,000 rounds/month. Budget ~6 HTTP
requests per round (start, submit answers, fetch result, plus a couple of
leaderboard/list reads):

| Line item | Volume/mo | Cost/mo |
|---|---|---|
| HTTP API requests | ~0.9M | **$0.90** (or $0 in year 1 free tier) |
| Lambda invocations | ~0.9M, 128 MB, ~50 ms each | **~$0** (inside perpetual free tier) |
| DynamoDB writes | ~0.6M | **$0.75** |
| DynamoDB reads | ~1.5M | **$0.38** |
| **Total** | | **≈ $2–4/month** |

### Scenario: same load, real-time duels
WebSocket connection-minutes (1,000 players × ~20 min/day × 30 ≈ 600k conn-min →
$0.15) are cheap, but live score sync is chatty: ~100 messages/round × 150k
rounds = 15M messages → **$15/month just in messages**, plus a Lambda per message
and the matchmaking/presence system to build and run. **~5–10× the async cost for
a feature that barely functions at launch.**

### Today's real scale
At dozens of daily players the async design is **$0** — every line sits inside a
free tier. Cost only becomes a rounding-error line on the AWS bill somewhere
north of ~100k rounds/month. This is the whole argument for async: it's free
until the game is a genuine success, and still only a few dollars after.

## Recommended architecture (Option B, async)

```
Browser ──JWT──▶ API Gateway (HTTP API, JWT authorizer = existing user pool)
                     │
                     ▼
                 Lambda (Node, one small handler)
                     │
                     ▼
        DynamoDB  (existing birdz-<env>-game-data table)
```

- **Auth:** the HTTP API's built-in JWT authorizer validates the Cognito
  **user-pool** access token the SPA already has. No new auth infra, no cost.
  (Single-player still keys by identity-pool ID; a Lambda can map or we key PvP
  items by user-pool `sub` — decide at build time, noted as an open question.)
- **Compute:** one Lambda with a few routes (`POST /challenges`,
  `POST /challenges/{id}/answers`, `GET /challenges/{id}`, `GET /leaderboard`).
  Node 20, 128 MB, arm64 (cheapest). Cold starts are fine for async play.
- **Storage:** reuse the existing single table with new item types — no new table
  to provision or pay for:
  - `PK = CHALLENGE#<id>`, `SK = META` → call set + answer key (server-only) +
    creator + status
  - `PK = CHALLENGE#<id>`, `SK = RESULT#<userId>` → a player's score/answers
  - optional `PK = DAILY#<yyyy-mm-dd>`, `SK = SCORE#<score>#<userId>` for the
    tournament leaderboard (sorted by sort key)
- **Anti-cheat:** the answer key lives only in the `META` item and is never sent
  to the client; the client submits guesses, the Lambda scores them. Add a
  server-side time budget per question to blunt "look it up" cheating.
- **Deploy:** extend the existing Terraform (new `apigateway`/`lambda` module per
  env) and the GitHub Actions pipeline to build+publish the Lambda zip. Fits the
  current 4-env promote flow.

## Phasing

1. **Phase 1 — async challenge.** The API tier + challenge create/play/compare +
   a share link. This is the whole recommendation; everything else is optional.
2. **Phase 2 — daily tournament + leaderboard.** Reuses the same backend; adds one
   shared daily record and a leaderboard query. Strong retention, still cheap.
3. **Phase 3 (only if the game takes off) — real-time duels.** Add WebSocket/AppSync
   and matchmaking. Gate this behind actual concurrent-user numbers, since both
   the cost and the fun depend on having a live opponent.

## Decisions (Jared, 2026-07-11) — all resolved

- ✅ **Mechanic:** async challenge-a-friend (phase 1).
- ✅ **Invite:** share-a-link, no friend/username system.
- ✅ **Named challenger:** the invite surfaces the challenger's display name
  ("<username> challenged you to a bird-off").
- ✅ **Stakes:** **the winner is shown clearly and gets seeds.** Both players see
  who won; the winner's game save is credited seeds server-side.
- ✅ **Contest set:** same 10 random calls for both players (default; themed sets
  are a later nicety).

Direction is fully locked. The build-ready spec follows.

---

# Phase 1 — build spec

## The player experience

1. **Create.** From the base (a new "Challenge a friend" button), the player taps
   create. The server picks 10 birds, makes a challenge, and returns a share link
   (`birdzgame.com/pvp/<id>`). The creator sees "Send this to a friend — first to
   the best score wins seeds" and can play their own round immediately.
2. **Play.** Both players play the **same 10 calls in the same order**, reusing the
   existing identify UI (call playback, hints, search-to-guess) run as a 10-round
   sequence with a running tally instead of a single round.
3. **Invite.** The friend opens the link → a landing card: "🐦 <username>
   challenged you to a bird-off! 10 calls. Best score wins." → Play (as guest or
   signed in).
4. **Result.** When a player finishes, they see their score. Once **both** have
   played, each sees the outcome: **You won! / You lost. / Tie.** with both
   scores, the opponent's name, and — for the winner — **+N seeds**.

## Scoring & seeds

- **Score per round:** reuse the existing hint-aware scoring (`scoreForHints`) so
  fewer hints = more points, keeping it consistent with single-player. Sum over 10
  rounds = challenge score.
- **Winner:** higher total score. **Tiebreakers** in order: fewer hints used, then
  faster total time. Still tied → both treated as winners (both paid).
- **Seed payout (server-authoritative, tunable):**
  - Winner: **+25 seeds** (≈ half of a Brush Pile; meaningful but not
    economy-breaking — one correct single-player ID is ~10–15 seeds).
  - Loser: **+5 seeds** (participation, so a challenge is never a pure loss).
  - Tie: both **+15**.
- **How seeds land:** the scoring Lambda does a DynamoDB `UpdateItem ... ADD
  seeds :n` on the winner's own `PROGRESS` item (source of truth). The result
  response echoes `seedsAwarded`; the client shows it and **re-hydrates its save
  from the cloud** so the total is correct with no double-count. Guests (no cloud
  save) get the seeds credited to localStorage via the response value.

## Anti-cheat — what phase 1 does and doesn't protect

- **Protected:** score forgery. You can't POST "I won, pay me" — the server holds
  the answer key, scores your submitted guesses itself, and decides the winner and
  the payout. This is the protection that matters for a seed economy.
- **Accepted for phase 1:** a technical user could read the answer from the
  client, because the identify UI needs the bird's data to render calls/hints and
  the audio file is served at `/audio/<birdId>.mp3` (the URL names the bird). True
  blind play needs opaque audio URLs — deferred as a phase-1.5 hardening if
  cheating a *friend* in a casual game ever proves to be a real problem.

## Data model (existing `birdz-<env>-game-data` table)

- **Challenge meta** — `PK = CHALLENGE#<id>`, `SK = META`
  `{ birds: [10 birdIds, ordered], createdBy, createdByUserId, createdAt,
     status: 'open'|'complete', ttlEpoch }`
  The `birds` array is the answer key — returned to clients **without names is not
  feasible in phase 1** (see anti-cheat), so clients do receive it; the server
  never *trusts* it back.
- **Per-player result** — `PK = CHALLENGE#<id>`, `SK = RESULT#<userId>`
  `{ username, score, correctCount, hintsUsed, timeMs, completedAt }`
- **TTL:** set `ttlEpoch` ~30 days out (DynamoDB TTL auto-expires stale
  challenges — no cleanup job, no storage creep).
- **Keying:** PvP items key by user-pool `sub` (from the JWT the API authorizer
  already validates). Seed grants cross-reference the single-player `PROGRESS`
  item, which is keyed by identity-pool id — the Lambda maps sub→identityId via a
  tiny `USER#<sub>` pointer written on first PvP call, or we accept keying PvP by
  identityId too. **Decision: key everything by identity id** for a single
  consistent key, obtained by having the client send its identity id in the create
  call (it already has it for cloud saves). Simplest; no mapping table.

## API (API Gateway HTTP API + one Lambda, JWT authorizer = existing user pool)

| Route | Does |
|---|---|
| `POST /challenges` | Pick 10 random birds, write `META`, return `{ id, shareUrl }` |
| `GET /challenges/{id}` | Return meta for playing + both results so far (for the result screen) |
| `POST /challenges/{id}/results` | Score the submitted guesses, write `RESULT`, if both done decide winner + grant seeds, return `{ yourScore, opponentScore?, outcome, seedsAwarded }` |

Node 20, arm64, 128 MB. No cold-start concern for async play. One handler,
switch on route.

## Client changes (birdzReact)

- **PvP session hook** — wraps the identify flow to run 10 sequential rounds over
  a fixed bird list, accumulating score/hints/time (generalizes
  `useIdentificationSession`, which today is single-target).
- **Routes:** `/app/pvp/new` (create + share), `/pvp/:id` (public invite landing →
  play), `/app/pvp/:id/result` (outcome). The invite route is **public** (like
  `/guide`) so a link works before login; playing prompts guest/sign-in.
- **API client** — small `pvp.ts` util calling the three endpoints with the
  Cognito access token (mirrors `cloudSave.ts`).
- **Entry point** — "Challenge a friend" button on the base screen.
- **Result screen** — win/lose/tie, both scores, opponent name, seed award; re-hydrate
  save after a win.

## Infra & rollout

- **Terraform:** new `apigateway` + `lambda` module per env (4 envs), JWT authorizer
  pointed at the existing user pool, IAM for the Lambda to read/write the game-data
  table. API base URL flows to the client via `config.json` (one more SSM
  deploy-config value, same mechanism as `gameDataTable`).
- **Pipeline:** the deploy workflow gains a step to build + publish the Lambda zip
  (or Terraform packages it). Fits the existing 4-env promote flow.
- **Tests:** Lambda unit tests for scoring/tiebreak/seed grant; client tests for
  the 10-round session and result rendering; a verify pass driving create → play →
  result end-to-end.

## Build order (smallest shippable slices)

1. Terraform the API+Lambda+routes with a stub scorer; wire `config.json`. (Infra
   only — nothing user-facing yet.)
2. Lambda: create + score + seed grant + tiebreaks, with unit tests.
3. Client: PvP session (10 rounds) + create/share + invite landing + result.
4. Verify end-to-end on dev, then ship through the pipeline.

## Explicitly out of scope for phase 1

Friends/usernames graph, real-time, daily tournament/leaderboard (phase 2), themed
challenge sets, opaque-audio blind play, rematch/history. All are additive on top
of this backend.
