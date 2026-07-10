# Server-Side Persistence Design (Proposal)

Backlog P1: game progress and user data are currently localStorage-only and lost when browser data is cleared. This proposes DynamoDB persistence and the access path from the static SPA to the table.

Draft terraform lives in `terraform/modules/game-data` (not wired into any environment yet — this is a proposal for review).

## Table design

One table per environment, `birdz-<env>-game-data`, on-demand billing, point-in-time recovery on.

| Key | Type | Purpose |
|-----|------|---------|
| `userId` (PK) | S | The user's identity — one partition per user |
| `recordKey` (SK) | S | Namespaces record types within the partition |

Sort-key convention:

| recordKey | Item |
|-----------|------|
| `PROGRESS` | Current game progress (level, score, streaks) — single item |
| `SIGHTING#<birdId>` | One item per identified bird (timestamp, location, score) |
| `SETTINGS` | User preferences |

Single-table keeps all of a user's data in one partition: `Query(userId)` fetches everything in one round trip on login, and item-level writes stay cheap during play.

## Access path: two options

The app is a static SPA on S3 + CloudFront — there is no server. Two ways for the browser to reach DynamoDB:

### Option A — Cognito Identity Pool + fine-grained IAM (recommended)

The existing user pool federates into a new **identity pool**, which vends temporary AWS credentials to the signed-in browser. The authenticated role's policy restricts DynamoDB access with a `dynamodb:LeadingKeys` condition so each user can only read/write items whose `userId` equals their own Cognito identity ID (already drafted in the module).

- **Pros:** no servers, no cold starts, no API code to write or operate; ~zero cost at this scale; the IAM condition is the authorization layer, enforced by AWS itself; a natural extension of the Cognito investment already made.
- **Cons:** client talks to DynamoDB directly, so any cross-user features later (leaderboards, PvP) need something server-side anyway; table schema is coupled to the client; per-item validation is limited to what IAM can express.
- **App changes:** add the AWS SDK v3 DynamoDB client (+ Cognito identity credentials provider) to birdzReact, point it at the table name served via `config.json` (one more `/birdz/<env>/deploy/*` SSM param).

### Option B — API Gateway + Lambda

A small REST/HTTP API (authorized by the existing user pool's JWTs) in front of Lambda functions that read/write the table.

- **Pros:** server-side validation and game-rule enforcement (anti-cheat); schema hidden from the client; the natural place for future cross-user features.
- **Cons:** more moving parts to build and operate (API, Lambda code, deployment of that code, cold starts); overkill for save-my-progress.

### Recommendation

**Start with Option A.** It ships persistence with terraform + client changes only, and nothing about it blocks adding an API later: when leaderboards/PvP/anti-cheat arrive, put API Gateway + Lambda in front of the *same table* for those features and (if desired) drop the direct-access policy at that point.

Note: with Option A the partition key is the Cognito **identity ID** (from the identity pool), not the user pool `sub`. If we later migrate to Option B we can keep keying by identity ID or migrate keys then.

## Rollout status

1. ~~Add an `aws_cognito_identity_pool` (+ authenticated role) to the cognito module, federated from the existing user pool.~~ Done.
2. ~~Wire `module "game_data"` into each environment, passing the authenticated role name.~~ Done (prod applies when the prod branch is next promoted).
3. ~~Add the table name and identity pool ID to the deploy-config SSM values so `config.json` carries them.~~ Done — `config.json` now serves `identityPoolId`, `gameDataTable`, and `region` alongside the user-pool IDs.
4. **Remaining (birdzReact repo):** on login, exchange the user-pool session for identity-pool credentials; load with one `Query`, save with `PutItem`/`UpdateItem`; keep localStorage as offline cache/fallback. Partition key is the Cognito **identity ID** (`cognito-identity.amazonaws.com:sub`), enforced by IAM.
