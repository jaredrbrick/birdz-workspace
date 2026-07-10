# Bird-Call Audio Hosting (Proposal)

Backlog P1: birds have call/song descriptions but nothing plays — `ActiveCallBanner` shows ♪ silently.

## Recommendation: no new infrastructure

Serve audio from the **existing per-environment site bucket** under an `audio/` prefix, through the **existing CloudFront distribution**:

- URL shape: `https://<env-domain>/audio/<birdId>.mp3` — same origin as the app, so no CORS setup, no new bucket, no new distribution, no new terraform.
- CloudFront already caches at the edge; audio files are immutable per bird, so long cache TTLs apply naturally.

## What actually needs to happen

1. **Source the audio files** (the real blocker — infra is not). Xeno-canto (xeno-canto.org) offers CC-licensed recordings per species; each file needs its license/attribution recorded. A `audio/attribution.json` manifest alongside the files keeps this auditable.
2. **Decide where files live in git**: they should NOT go in the birdz-workspace or birdzReact repos (binary bloat). Options: a `birdz-audio` assets repo, or upload once to S3 out-of-band and have deploys leave the prefix alone.
3. **Protect the prefix from deploys**: the deploy job runs `aws s3 sync dist/ s3://<bucket> --delete`, which would delete anything not in the build. Add `--exclude "audio/*"` to the sync in all four deploy jobs before uploading any audio.
4. **birdzReact playback** (separate repo): wire `ActiveCallBanner` to an `<audio>` element pointing at `/audio/<birdId>.mp3`, with graceful fallback when a file 404s (not every bird will have audio on day one).

## Why not a separate audio bucket

A dedicated bucket + CloudFront origin path would isolate audio from app deploys, but costs another origin/OAC/policy per environment and forces CORS thought if ever served cross-origin. The `--exclude` flag on the existing sync achieves the same isolation with one workflow line per job.
