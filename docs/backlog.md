# Backlog

## Bugs / Broken Features

| Priority | Issue | Notes |
|----------|-------|-------|
| ~~P0~~ | ~~Poor mobile layout~~ | ~~Done 2026-07-10 (birdzReact PR #4): bottom sheets, navbar tightening, dvh shell; verified 320–1280px~~ |
| ~~P0~~ | ~~Biome detection can fail silently~~ | ~~Done 2026-07-10 (birdzReact PR #6): status checks + retry + Overpass mirror, visible fallback warning, ?debug=1 trace, and a device-geolocation button (iPhone photo uploads lose GPS EXIF)~~ |
| ~~P0~~ | ~~Auth is localStorage only~~ | ~~Done: real Cognito SRP auth in useAuthStore, pre-signup Lambda auto-confirms~~ |
| ~~P1~~ | ~~No audio playback~~ | ~~Done 2026-07-10 (birdzReact PR #7): banner ♪ + identify-screen Play button play /audio/<birdId>.mp3 with graceful fallback.~~ Remaining: 11 of 24 birds lack recordings (Commons only has OGG for them — needs a xeno-canto API key from Jared or an approved ffmpeg transcode); test/staging/prod bucket uploads await Jared's sign-off (`aws s3 sync s3://birdz-dev-site/audio/ s3://birdz-<env>-site/audio/`) |
| ~~P1~~ | ~~Hint scoring misleading~~ | ~~Done: potential score drops on hint reveal; regression-tested~~ |
| ~~P2~~ | ~~Game progress is localStorage only~~ | ~~Done 2026-07-10 (birdzReact PR #5): progress persists to DynamoDB, localStorage is the offline cache~~ |
| P2 | Silent error handling | Affects persistence.ts, biomeDetector.ts, exifExtractor.ts |
| P2 | Leaflet loaded from CDN via window.L | No fallback if load fails |
| P2 | Weak password validation | 4-char minimum, no complexity requirements |

## DevOps / Infrastructure

| Priority | Issue | Notes |
|----------|-------|-------|
| ~~P0~~ | ~~No devops architecture defined~~ | ~~Documented in cicd.md — Terraform + GitHub Actions, S3 + CloudFront, 4 environments~~ |
| ~~P0~~ | ~~Migrate hosting to AWS~~ | ~~All four environments live on S3 + CloudFront~~ |
| ~~P0~~ | ~~Migrate domains to birdzgame.com~~ | ~~Done 2026-07-10: all four envs live on birdzgame.com, DNS + ACM validation fully Terraform-managed (cloudflare provider). AdSense unblocked.~~ |

## Game Design

| Priority | Feature | Notes |
|----------|---------|-------|
| P1 | Biome/ecoregion overhaul | Replace the six hard-coded biomes with real-world ecoregions (richer per-region bird pools, better detection granularity). Referenced in HANDOFF-2026-07-09 as "P1 ecoregion redesign" but the plan itself was never written down — needs a design doc (docs/biome-redesign.md) before implementation. May supersede parts of the biome-detection heuristics. |

## Monetization

| Priority | Feature | Notes |
|----------|---------|-------|
| P1 | AdSense integration | Unblocked by birdzgame.com purchase; needs the domain live first (P0 above). ads.txt at domain root, site verification, apply for review (takes days–weeks, start early), then ad placements in the app. |

## AWS Backend Features

| Priority | Feature | Notes |
|----------|---------|-------|
| ~~P0~~ | ~~CloudFront + S3~~ | ~~Provisioned per environment; deploys via GitHub Actions + OIDC~~ |
| ~~P1~~ | ~~S3~~ | ~~Done 2026-07-10: audio served from existing site buckets under audio/ (no new infra, per audio-hosting-design.md); 13 CC/PD recordings + attribution.json live in dev~~ |
| ~~P1~~ | ~~Cognito~~ | ~~Done: infra provisioned per env and app uses real Cognito SRP auth~~ |
| ~~P1~~ | ~~DynamoDB~~ | ~~Done 2026-07-10 (birdzReact PR #5): app syncs progress via Cognito Identity Pool credentials, one PROGRESS item per user, localStorage offline fallback~~ |

## Testing

| Priority | Feature | Notes |
|----------|---------|-------|
| P2 | Code coverage | Add coverage reporting to the Vitest test suite |

## UX Improvements

| Status | Feature | Completed |
|--------|---------|-----------|
| Done | Hints independently selectable | 2026-03-26 |