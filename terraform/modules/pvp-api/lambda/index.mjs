// PvP challenge API — async "bird-off" between two players.
// See docs/pvp-design.md. One Lambda behind an HTTP API (JWT-authorized by the
// existing Cognito user pool), reading/writing the existing game-data table.
//
// Server-authoritative: it owns the answer key, scores submitted guesses, decides
// the winner, and credits the winner's seeds — so scores and payouts can't be
// forged. (Phase 1 accepts that a client can read the answer locally; see doc.)

import { DynamoDBClient } from '@aws-sdk/client-dynamodb'
import {
  DynamoDBDocumentClient, PutCommand, QueryCommand, UpdateCommand,
} from '@aws-sdk/lib-dynamodb'
import { randomUUID } from 'node:crypto'

const TABLE = process.env.GAME_DATA_TABLE
const doc = DynamoDBDocumentClient.from(new DynamoDBClient({}), {
  marshallOptions: { removeUndefinedValues: true },
})

// The 60-bird roster (see birdzReact/src/data/birds.ts). The server picks the
// challenge set so a client can't stack the deck. Keep in sync when the roster
// grows — a stale entry only means that bird never appears in a challenge.
const ROSTER = ["black_capped_chickadee","pileated_woodpecker","wood_thrush","barred_owl","ovenbird","eastern_meadowlark","bobolink","horned_lark","american_kestrel","red_winged_blackbird","common_yellowthroat","great_blue_heron","american_bittern","cactus_wren","greater_roadrunner","elf_owl","gambels_quail","clarks_nutcracker","peregrine_falcon","american_dipper","piping_plover","laughing_gull","brown_pelican","osprey","killdeer","western_gull","stellers_jay","white_crowned_sparrow","common_poorwill","sandhill_crane","northern_cardinal","varied_thrush","western_meadowlark","roseate_spoonbill","mountain_bluebird","american_oystercatcher","sage_thrasher","greater_sage_grouse","burrowing_owl","common_loon","belted_kingfisher","common_raven","ruffed_grouse","canada_jay","scaled_quail","pyrrhuloxia","eastern_towhee","dark_eyed_junco","carolina_wren","limpkin","herring_gull","black_oystercatcher","western_kingbird","prothonotary_warbler","scarlet_tanager","white_throated_sparrow","anhinga","ring_billed_gull","phainopepla","pinyon_jay","california_quail","annas_hummingbird","purple_gallinule","green_heron","veery","dickcissel","american_avocet","black_throated_green_warbler","hooded_warbler","louisiana_waterthrush","eastern_whip_poor_will","wild_turkey","tufted_titmouse","rock_wren"]

const ROUNDS = 10
const HINT_COSTS = [5, 10, 15]
const BASE_POINTS = 30
const MIN_POINTS = 1
const SEEDS = { win: 25, lose: 5, tie: 15 }
const TTL_DAYS = 30

const json = (statusCode, body) => ({
  statusCode,
  headers: {
    'content-type': 'application/json',
    'access-control-allow-origin': '*',
    'access-control-allow-headers': 'authorization,content-type',
    'access-control-allow-methods': 'GET,POST,OPTIONS',
  },
  body: JSON.stringify(body),
})

function roundPoints(correct, hintsUsed) {
  if (!correct) return 0
  const cost = HINT_COSTS.slice(0, hintsUsed).reduce((a, b) => a + b, 0)
  return Math.max(BASE_POINTS - cost, MIN_POINTS)
}

// Deterministic winner: higher score, then fewer hints, then faster.
function betterOf(a, b) {
  if (a.score !== b.score) return a.score > b.score ? a : b
  if (a.hintsUsed !== b.hintsUsed) return a.hintsUsed < b.hintsUsed ? a : b
  return a.timeMs <= b.timeMs ? a : b
}

// 'win' | 'lose' | 'tie' from my result vs the opponent's.
function outcomeFor(me, opp) {
  const tie = me.score === opp.score && me.hintsUsed === opp.hintsUsed && me.timeMs === opp.timeMs
  if (tie) return 'tie'
  return betterOf({ ...me, who: 'me' }, { ...opp, who: 'opp' }).who === 'me' ? 'win' : 'lose'
}

function pickChallengeBirds() {
  const pool = [...ROSTER]
  for (let i = pool.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[pool[i], pool[j]] = [pool[j], pool[i]]
  }
  return pool.slice(0, ROUNDS)
}

async function getChallenge(id) {
  const res = await doc.send(new QueryCommand({
    TableName: TABLE,
    KeyConditionExpression: 'userId = :u',
    ExpressionAttributeValues: { ':u': `CHALLENGE#${id}` },
  }))
  const items = res.Items ?? []
  const meta = items.find(i => i.recordKey === 'META')
  const results = items.filter(i => i.recordKey.startsWith('RESULT#'))
  return { meta, results }
}

async function grantSeeds(identityId, amount) {
  // Winner's seeds live at progress.seeds on their PROGRESS item (keyed by
  // identity id). No-op-safe: a missing item just means a guest with no cloud save.
  try {
    await doc.send(new UpdateCommand({
      TableName: TABLE,
      Key: { userId: identityId, recordKey: 'PROGRESS' },
      UpdateExpression: 'SET progress.seeds = if_not_exists(progress.seeds, :z) + :n',
      ConditionExpression: 'attribute_exists(userId)',
      ExpressionAttributeValues: { ':n': amount, ':z': 0 },
    }))
  } catch (err) {
    if (err.name !== 'ConditionalCheckFailedException') throw err
  }
}

export async function handler(event) {
  const route = event.routeKey // e.g. "POST /challenges"
  const sub = event.requestContext?.authorizer?.jwt?.claims?.sub
  if (route === 'OPTIONS /{proxy+}') return json(200, {})
  if (!sub) return json(401, { error: 'unauthenticated' })

  const body = event.body ? JSON.parse(event.body) : {}
  const id = event.pathParameters?.id

  try {
    if (route === 'POST /challenges') {
      const challengeId = randomUUID().slice(0, 8)
      const birds = pickChallengeBirds()
      await doc.send(new PutCommand({
        TableName: TABLE,
        Item: {
          userId: `CHALLENGE#${challengeId}`,
          recordKey: 'META',
          birds,
          createdBySub: sub,
          createdByName: (body.username || 'A birder').slice(0, 40),
          createdByIdentityId: body.identityId || null,
          createdAt: Date.now(),
          status: 'open',
          ttlEpoch: Math.floor(Date.now() / 1000) + TTL_DAYS * 86400,
        },
      }))
      return json(201, { id: challengeId, birds })
    }

    if (route === 'GET /challenges/{id}') {
      const { meta, results } = await getChallenge(id)
      if (!meta) return json(404, { error: 'not found' })

      // ?me=<identityId> lets a returning player see whether they've played and,
      // once the opponent has too, their outcome — closing the "did I win?" gap.
      const me = event.queryStringParameters?.me
      const mine = me ? results.find(r => r.recordKey === `RESULT#${me}`) : undefined
      const opponent = mine ? results.find(r => r.recordKey !== mine.recordKey) : undefined
      const yourResult = mine
        ? {
            score: mine.score,
            correctCount: mine.correctCount,
            opponentName: opponent?.name ?? null,
            opponentScore: opponent?.score ?? null,
            outcome: opponent ? outcomeFor(mine, opponent) : 'pending',
          }
        : null

      return json(200, {
        id,
        createdByName: meta.createdByName,
        birds: meta.birds,
        alreadyPlayed: !!mine,
        yourResult,
        results: results.map(r => ({ name: r.name, score: r.score, correctCount: r.correctCount })),
      })
    }

    if (route === 'POST /challenges/{id}/results') {
      const { meta, results } = await getChallenge(id)
      if (!meta) return json(404, { error: 'not found' })

      const key = `RESULT#${body.identityId || sub}`
      if (results.some(r => r.recordKey === key)) {
        return json(409, { error: 'already played' })
      }

      const guesses = Array.isArray(body.guesses) ? body.guesses : []
      const hints = Array.isArray(body.hintsPerRound) ? body.hintsPerRound : []
      let score = 0, correctCount = 0, hintsUsed = 0
      for (let i = 0; i < meta.birds.length; i++) {
        const correct = guesses[i] === meta.birds[i]
        if (correct) correctCount++
        const h = Math.min(Math.max(hints[i] | 0, 0), HINT_COSTS.length)
        hintsUsed += h
        score += roundPoints(correct, h)
      }
      const timeMs = Math.max(body.timeMs | 0, 0)

      const me = {
        recordKey: key, name: (body.username || 'A birder').slice(0, 40),
        identityId: body.identityId || null, score, correctCount, hintsUsed, timeMs,
      }
      await doc.send(new PutCommand({
        TableName: TABLE,
        Item: {
          userId: `CHALLENGE#${id}`, ...me,
          ttlEpoch: meta.ttlEpoch,
        },
      }))

      // Outcome + seed payout once an opponent's result exists.
      const opponent = results.find(r => r.recordKey !== key)
      let outcome = 'pending', seedsAwarded = 0, opponentScore = null
      if (opponent) {
        opponentScore = opponent.score
        const oppEntry = { score: opponent.score, hintsUsed: opponent.hintsUsed, timeMs: opponent.timeMs, who: 'opp' }
        const meEntry = { score, hintsUsed, timeMs, who: 'me' }
        const tie = meEntry.score === oppEntry.score && meEntry.hintsUsed === oppEntry.hintsUsed && meEntry.timeMs === oppEntry.timeMs
        if (tie) {
          outcome = 'tie'; seedsAwarded = SEEDS.tie
          if (me.identityId) await grantSeeds(me.identityId, SEEDS.tie)
          if (opponent.identityId) await grantSeeds(opponent.identityId, SEEDS.tie)
        } else {
          const winner = betterOf(meEntry, oppEntry)
          const iWon = winner.who === 'me'
          outcome = iWon ? 'win' : 'lose'
          seedsAwarded = iWon ? SEEDS.win : SEEDS.lose
          // pay both their due
          if (me.identityId) await grantSeeds(me.identityId, iWon ? SEEDS.win : SEEDS.lose)
          if (opponent.identityId) await grantSeeds(opponent.identityId, iWon ? SEEDS.lose : SEEDS.win)
        }
        await doc.send(new UpdateCommand({
          TableName: TABLE,
          Key: { userId: `CHALLENGE#${id}`, recordKey: 'META' },
          UpdateExpression: 'SET #s = :c',
          ExpressionAttributeNames: { '#s': 'status' },
          ExpressionAttributeValues: { ':c': 'complete' },
        }))
      }

      return json(200, { yourScore: score, correctCount, opponentScore, outcome, seedsAwarded })
    }

    return json(404, { error: 'unknown route' })
  } catch (err) {
    console.error('pvp error', route, err)
    return json(500, { error: 'internal' })
  }
}
