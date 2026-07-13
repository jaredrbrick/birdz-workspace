# Roster batch 7 media (60 → 67 birds)

Staged media for birdzReact PR #31: California Quail, Anna's Hummingbird,
Purple Gallinule, Green Heron, Veery, Dickcissel, American Avocet.

The bird DATA ships with the app; audio and photos live in S3 out of band
(deploy sync excludes `audio/*` and `photos/*`), so they need a one-time
upload per environment bucket.

## To run the upload (needs real AWS credentials)

```bash
# 1. Download the 7 mp3s + 7 photos from Wikimedia Commons (~6 MB total,
#    deterministic — file titles are pinned in the script):
python3 download-media.py          # writes ./media/{audio,photos}/

# 2. Upload to the env buckets (uses @aws-sdk/client-s3; set BIRDZ_ENVS
#    to a comma list, default dev,test,staging):
npm i @aws-sdk/client-s3 https-proxy-agent @smithy/node-http-handler
BIRDZ_ENVS=dev,test,staging,prod node upload-media.mjs
```

`download-media.py` writes fresh manifests, but the canonical merged
attribution manifests (all 67 birds) are checked in here:
`audio-attribution-merged.json` (54 birds with audio) and
`photos-attribution-merged.json` (67 photos). The upload script pushes
these to `audio/attribution.json` and `photos/attribution.json`.

All licenses were verified commercially safe (CC BY / CC BY-SA, no NC/ND);
per-file artist + license live in the manifests. Photos were visually
verified to show the right species (quail is the male; avocet is
non-breeding plumage, which matches the "fades gray-white" fact).

The 2026-07-12 session that staged this could not run the upload itself:
its AWS credentials are proxy placeholders and the S3 write was
permission-gated. Everything else (data, PR, deploys) shipped; the app
degrades gracefully until this runs (phonetic-only calls, hidden photo).
