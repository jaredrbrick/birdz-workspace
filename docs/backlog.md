# Backlog

## Bugs / Broken Features

| Priority | Issue | Notes |
|----------|-------|-------|
| P0 | Poor mobile layout | UI not optimized for small screens |
| P0 | Biome detection can fail silently | Nominatim + Overpass with no retry; falls back to heuristics without telling user; Overpass returning 504 in production |
| P0 | Auth is localStorage only | Plain text passwords, no real sessions |
| P1 | No audio playback | Birds have call/song descriptions but nothing plays; ActiveCallBanner shows ♪ but is silent |
| P1 | Hint scoring misleading | Costs shown but penalty only applied at scoring time, not on reveal |
| P2 | Game progress is localStorage only | Lost if browser data cleared |
| P2 | Silent error handling | Affects persistence.ts, biomeDetector.ts, exifExtractor.ts |
| P2 | Leaflet loaded from CDN via window.L | No fallback if load fails |
| P2 | Weak password validation | 4-char minimum, no complexity requirements |

## DevOps / Infrastructure

| Priority | Issue | Notes |
|----------|-------|-------|
| ~~P0~~ | ~~No devops architecture defined~~ | ~~Documented in cicd.md — Terraform + GitHub Actions, S3 + CloudFront, 4 environments~~ |
| P0 | Migrate hosting to AWS | App currently served from personal PC; needs to move to S3 + CloudFront |

## AWS Backend Features

| Priority | Feature | Notes |
|----------|---------|-------|
| P0 | CloudFront + S3 | Provision S3 bucket and CloudFront distribution to replace personal PC hosting |
| P1 | S3 | Host bird call audio files; wire up playback (also fixes silent audio bug) |
| P1 | Cognito | Replace localStorage auth with real user sessions |
| P1 | DynamoDB | Persist game progress and user data server-side |

## Testing

| Priority | Feature | Notes |
|----------|---------|-------|
| P2 | Code coverage | Add coverage reporting to the Vitest test suite |

## UX Improvements

| Status | Feature | Completed |
|--------|---------|-----------|
| Done | Hints independently selectable | 2026-03-26 |