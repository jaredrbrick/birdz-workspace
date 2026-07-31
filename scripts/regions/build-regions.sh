#!/usr/bin/env bash
# Build the canonical region map from the CEC/EPA North American ecoregions.
#
# Proven end to end 2026-07-30: 2,548 raw polygons → 182 Level III regions,
# 563 KB topojson / 178 KB gzipped, ~3.4s. See docs/region-map-design.md.
#
#   npm i mapshaper topojson-client   # not committed; build-time only
#   ./build-regions.sh
set -euo pipefail

cd "$(dirname "$0")"
SRC_URL="https://dmap-prod-oms-edc.s3.us-east-1.amazonaws.com/ORD/Ecoregions/cec_na/NA_CEC_Eco_Level3.zip"
WORK="${TMPDIR:-/tmp}/birdz-regions"
mkdir -p "$WORK"

if [ ! -f "$WORK/NA_CEC_Eco_Level3.shp" ]; then
  echo "→ downloading CEC Level III ecoregions (~34 MB)"
  curl -sL --max-time 600 -o "$WORK/l3.zip" "$SRC_URL"
  unzip -o -q "$WORK/l3.zip" -d "$WORK"
fi

# The source is an equal-area projection with one polygon per mapped patch:
# reproject to WGS84 (what the app's coords are in) and dissolve patches into
# one feature per Level III region, carrying the L2/L1 names that become the
# pool-family grouping. `keep-shapes` stops small regions vanishing at 2%.
echo "→ dissolving + simplifying"
npx mapshaper-xl 6gb "$WORK/NA_CEC_Eco_Level3.shp" \
  -proj wgs84 \
  -dissolve NA_L3CODE copy-fields=NA_L3NAME,NA_L2NAME,NA_L1NAME \
  -simplify 2% keep-shapes \
  -clean \
  -o format=topojson na-ecoregions-l3.topo.json

echo "→ built na-ecoregions-l3.topo.json ($(du -h na-ecoregions-l3.topo.json | cut -f1), \
$(gzip -9 -c na-ecoregions-l3.topo.json | wc -c | awk '{printf "%.0f KB", $1/1024}') gzipped)"
echo "→ sanity-check lookups:"
node lookup-test.mjs
