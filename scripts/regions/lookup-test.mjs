import { readFileSync } from 'fs'
import { feature } from 'topojson-client'

const topo = JSON.parse(readFileSync('eco/l3.topo.json', 'utf8'))
const fc = feature(topo, topo.objects[Object.keys(topo.objects)[0]])
console.log('regions:', fc.features.length)

function inRing(pt, ring) {
  let inside = false
  for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    const [xi, yi] = ring[i], [xj, yj] = ring[j]
    if ((yi > pt[1]) !== (yj > pt[1]) &&
        pt[0] < ((xj - xi) * (pt[1] - yi)) / (yj - yi) + xi) inside = !inside
  }
  return inside
}
function inPoly(pt, coords, type) {
  const polys = type === 'Polygon' ? [coords] : coords
  for (const poly of polys) {
    if (inRing(pt, poly[0]) && !poly.slice(1).some(h => inRing(pt, h))) return true
  }
  return false
}
function lookup(lat, lng) {
  for (const f of fc.features) {
    if (inPoly([lng, lat], f.geometry.coordinates, f.geometry.type)) return f.properties
  }
  return null
}

const CASES = [
  ['Bend, OR', 44.058, -121.315],
  ['Castle Rock, CO (Jared\'s screenshot)', 39.372, -104.856],
  ['Death Valley, CA', 36.505, -117.079],
  ['Miami, FL', 25.775, -80.194],
  ['Great Smoky Mtns, TN', 35.611, -83.489],
  ['Seattle, WA', 47.606, -122.332],
  ['Phoenix, AZ', 33.448, -112.074],
  ['New Orleans, LA', 29.951, -90.071],
  ['Bismarck, ND (prairie potholes)', 46.808, -100.783],
  ['Mid-Pacific (should be null)', 30.0, -150.0],
]
const t0 = Date.now()
for (const [name, lat, lng] of CASES) {
  const p = lookup(lat, lng)
  console.log(`${name.padEnd(38)} → ${p ? `${p.NA_L3NAME}  [L2 ${p.NA_L2NAME}]` : 'none (outside NA)'}`)
}
console.log(`\n${CASES.length} lookups in ${Date.now() - t0}ms (linear scan, unindexed)`)
