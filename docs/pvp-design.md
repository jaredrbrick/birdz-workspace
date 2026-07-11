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

## Open questions for Jared

1. **Mechanic:** async challenge-a-friend (phase 1) as the starting point — yes?
   And is a daily tournament (phase 2) something you want soon after, or later?
2. **What's the contest?** Same random 10 calls for both players is the simplest.
   Alternatives: themed sets (one biome), or "hardest birds." Any preference?
3. **Stakes:** does winning pay out **seeds** (ties PvP into base building), cosmetic
   bragging rights only, or both? (Seeds keep the single-player economy central.)
4. **Social graph:** share-a-link (no friend system, cheapest) vs. usernames /
   friend list (more infra). Link-first is the low-cost start.
5. **Key choice:** key PvP items by user-pool `sub` or reuse the identity-pool ID
   from single-player? Minor, but it affects the Lambda's DynamoDB access shape.

None of this is built yet — it waits on your answers to #1–#3 especially, since
they set the data model.
