# Backlog

## Bugs / Broken Features

| Priority | Issue | Notes |
|----------|-------|-------|
| ~~P0~~ | ~~Poor mobile layout~~ | ~~Done 2026-07-10 (birdzReact PR #4): bottom sheets, navbar tightening, dvh shell; verified 320–1280px~~ |
| P0 | Biome detection can fail silently | Nominatim + Overpass with no retry; falls back to heuristics without telling user; Overpass returning 504 in production |
| ~~P0~~ | ~~Auth is localStorage only~~ | ~~Done: real Cognito SRP auth in useAuthStore, pre-signup Lambda auto-confirms~~ |
| P1 | No audio playback | Birds have call/song descriptions but nothing plays; ActiveCallBanner shows ♪ but is silent |
| ~~P1~~ | ~~Hint scoring misleading~~ | ~~Done: potential score drops on hint reveal; regression-tested~~ |
| P2 | Game progress is localStorage only | Lost if browser data cleared |
| P2 | Silent error handling | Affects persistence.ts, biomeDetector.ts, exifExtractor.ts |
| P2 | Leaflet loaded from CDN via window.L | No fallback if load fails |
| P2 | Weak password validation | 4-char minimum, no complexity requirements |

## DevOps / Infrastructure

| Priority | Issue | Notes |
|----------|-------|-------|
| ~~P0~~ | ~~No devops architecture defined~~ | ~~Documented in cicd.md — Terraform + GitHub Actions, S3 + CloudFront, 4 environments~~ |
| ~~P0~~ | ~~Migrate hosting to AWS~~ | ~~All four environments live on S3 + CloudFront~~ |
| P0 | Migrate domains to birdzgame.com | Domain purchased 2026-07-10 (Spaceship). Add zone to Cloudflare, manage DNS with Terraform cloudflare provider (env CNAMEs + ACM validation records — removes today's manual validation step), cut CloudFront/ACM over from birdz.3569081.xyz. Gates AdSense. |

## Monetization

| Priority | Feature | Notes |
|----------|---------|-------|
| P1 | AdSense integration | Unblocked by birdzgame.com purchase; needs the domain live first (P0 above). ads.txt at domain root, site verification, apply for review (takes days–weeks, start early), then ad placements in the app. |

## AWS Backend Features

| Priority | Feature | Notes |
|----------|---------|-------|
| ~~P0~~ | ~~CloudFront + S3~~ | ~~Provisioned per environment; deploys via GitHub Actions + OIDC~~ |
| P1 | S3 | Host bird call audio files; wire up playback (also fixes silent audio bug) |
| ~~P1~~ | ~~Cognito~~ | ~~Done: infra provisioned per env and app uses real Cognito SRP auth~~ |
| P1 | DynamoDB | Persist game progress server-side — infra live in all four envs (tables, identity pools, row-scoped roles); app integration remains (persistence-design.md step 4) |

## Testing

| Priority | Feature | Notes |
|----------|---------|-------|
| P2 | Code coverage | Add coverage reporting to the Vitest test suite |

## UX Improvements

| Status | Feature | Completed |
|--------|---------|-----------|
| Done | Hints independently selectable | 2026-03-26 |