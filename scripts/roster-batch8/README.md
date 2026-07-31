# Roster batch 8 media (67 → 74 birds)

Staged media for birdzReact PR #41: Black-throated Green Warbler, Hooded
Warbler, Louisiana Waterthrush, Eastern Whip-poor-will, Wild Turkey, Tufted
Titmouse (all appalachians + eastern-forest fills) and Rock Wren (the one
Mojave candidate with commercially-safe audio — see
docs/roster-batch8-candidates.md for the full research trail).

The bird DATA ships with the app; audio and photos live in S3 out of band
(deploy sync excludes `audio/*` and `photos/*`), so they need a one-time
upload per environment bucket.

## To run the upload (needs real AWS credentials — Jared)

```bash
# 1. Media is already staged in ./media/{audio,photos}; to re-fetch from
#    Commons deterministically (titles pinned in the script):
python3 download-media.py

# 2. Upload to the env buckets:
npm i @aws-sdk/client-s3 https-proxy-agent @smithy/node-http-handler
BIRDZ_ENVS=dev,test,staging,prod node upload-media.mjs
```

The canonical merged attribution manifests (all 74 birds) are checked in
here: `audio-attribution-merged.json` (61 birds with audio) and
`photos-attribution-merged.json` (74 photos). The upload script pushes them
to `audio/attribution.json` and `photos/attribution.json`.

All licenses verified commercially safe: five CC BY-SA XC recordings, one
CC BY-SA 4.0 (rock wren), and a **public-domain USFWS tufted titmouse**
(transcoded ogg→mp3). Photos: six CC BY-SA / CC BY, all visually verified
to show the right species. Gotcha caught this batch: the Wikipedia lead
image for Eastern Whip-poor-will is a Fuertes *painting* — swapped for a
real photograph (CC BY 2.0), since the difficulty curve teaches from these
photos.
