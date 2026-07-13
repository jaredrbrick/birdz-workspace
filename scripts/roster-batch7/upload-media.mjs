import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3'
import { NodeHttpHandler } from '@smithy/node-http-handler'
import { HttpsProxyAgent } from 'https-proxy-agent'
import { readFileSync, readdirSync } from 'fs'

const proxyAgent = new HttpsProxyAgent(process.env.HTTPS_PROXY, {
  ca: readFileSync('/root/.ccr/ca-bundle.crt'),
})

const ENVS = (process.env.BIRDZ_ENVS || 'dev,test,staging').split(',')
const BASE = new URL('./media', import.meta.url).pathname
const s3 = new S3Client({ region: 'us-east-1', requestHandler: new NodeHttpHandler({ httpsAgent: proxyAgent }) })

const NEW_BIRDS = ['california_quail', 'annas_hummingbird', 'purple_gallinule',
  'green_heron', 'veery', 'dickcissel', 'american_avocet']

async function put(bucket, key, body, contentType) {
  await s3.send(new PutObjectCommand({ Bucket: bucket, Key: key, Body: body, ContentType: contentType }))
  console.log(`  ${bucket}/${key} (${body.length}B)`)
}

for (const env of ENVS) {
  const bucket = `birdz-${env}-site`
  console.log(`== ${bucket} ==`)
  for (const bird of NEW_BIRDS) {
    await put(bucket, `audio/${bird}.mp3`, readFileSync(`${BASE}/audio/${bird}.mp3`), 'audio/mpeg')
    await put(bucket, `photos/${bird}.jpg`, readFileSync(`${BASE}/photos/${bird}.jpg`), 'image/jpeg')
  }
  await put(bucket, 'audio/attribution.json', readFileSync(new URL('./audio-attribution-merged.json', import.meta.url)), 'application/json')
  await put(bucket, 'photos/attribution.json', readFileSync(new URL('./photos-attribution-merged.json', import.meta.url)), 'application/json')
}
console.log('ALL UPLOADS DONE')
