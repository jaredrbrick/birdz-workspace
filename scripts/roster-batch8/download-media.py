#!/usr/bin/env python3
"""Download chosen audio + photos for roster batch 8, emit manifest entries.

Same shape as batch 7. One wrinkle: the tufted titmouse recording is a
public-domain USFWS .ogg, transcoded to mp3 with ffmpeg (the app serves
audio/<id>.mp3 only).
"""
import json, subprocess, re, os, urllib.parse, time

PICKS = {
    'black_throated_green_warbler': {
        'audio': 'File:Setophaga virens - Black-throated Green Warbler XC101293.mp3',
        'photo': 'File:Black-throated_green_warbler_in_PP_(14050).jpg',
    },
    'hooded_warbler': {
        'audio': 'File:Setophaga citrina - Hooded Warbler XC78878.mp3',
        'photo': 'File:Hooded_Warbler.jpg',
    },
    'louisiana_waterthrush': {
        'audio': 'File:Parkesia motacilla - Louisiana Waterthrush XC408861.mp3',
        'photo': 'File:Louisiana_waterthrush_(Parkesia_motacilla)_Orange_Walk.jpg',
    },
    'eastern_whip_poor_will': {
        'audio': 'File:Antrostomus vociferus - Eastern Whip-poor-will XC103418.mp3',
        # NOT the Wikipedia lead image — that one is a Fuertes painting;
        # the difficulty-curve teach photo should be a real photograph
        'photo': 'File:Eastern Whip-poor-will - 52031959351.jpg',
    },
    'wild_turkey': {
        'audio': 'File:Meleagris gallopavo - Wild Turkey XC104533.mp3',
        'photo': 'File:20260428_tom_wild_turkey_matthaei_botanical_gardens_PD08952.jpg',
    },
    'tufted_titmouse': {
        'audio': 'File:Tufted Titmouse call.ogg',
        'photo': 'File:Tufted_titmouse_(84917).jpg',
    },
    'rock_wren': {
        'audio': 'File:Salpinctes obsoletus - Rock Wren XC571628.mp3',
        'photo': 'File:RockWren.jpg',
    },
}

BASE = os.path.dirname(os.path.abspath(__file__)) + '/media'
os.makedirs(BASE + '/audio', exist_ok=True)
os.makedirs(BASE + '/photos', exist_ok=True)

def api(params):
    url = 'https://commons.wikimedia.org/w/api.php?' + urllib.parse.urlencode(params)
    for attempt in range(8):
        out = subprocess.run(['curl', '-s', '--max-time', '60', '-A', 'BirdzBatch8/1.0', url],
                             capture_output=True, text=True).stdout
        try:
            return json.loads(out)
        except json.JSONDecodeError:
            time.sleep(2 * (attempt + 1))
    raise RuntimeError('api failed: ' + url)

def info(title, width=None):
    p = {'action': 'query', 'titles': title, 'prop': 'imageinfo',
         'iiprop': 'url|size|extmetadata', 'format': 'json'}
    if width: p['iiurlwidth'] = width
    r = api(p)
    page = next(iter(r['query']['pages'].values()))
    ii = page['imageinfo'][0]
    md = ii['extmetadata']
    return {
        'url': ii.get('thumburl') or ii['url'],
        'origurl': ii['url'],
        'duration': ii.get('duration'),
        'license': md.get('LicenseShortName', {}).get('value', ''),
        'artist': re.sub(r'<[^>]+>', '', md.get('Artist', {}).get('value', '')).strip(),
        'desc': ii.get('descriptionurl'),
    }

def dl(url, dest):
    subprocess.run(['curl', '-sL', '--max-time', '180', '-A', 'BirdzBatch8/1.0', '-o', dest, url], check=True)
    return os.path.getsize(dest)

audio_manifest, photo_manifest = {}, {}
for bird, picks in PICKS.items():
    a = info(picks['audio'])
    assert not any(b in a['license'].upper() for b in ('NC', 'ND')), (bird, 'audio', a['license'])
    dest = f'{BASE}/audio/{bird}.mp3'
    if picks['audio'].lower().endswith('.ogg'):
        tmp = f'{BASE}/audio/{bird}.ogg'
        dl(a['origurl'], tmp)
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', tmp,
                        '-codec:a', 'libmp3lame', '-qscale:a', '4', dest], check=True)
        os.remove(tmp)
        size = os.path.getsize(dest)
    else:
        size = dl(a['origurl'], dest)
    audio_manifest[bird] = {
        'file': picks['audio'], 'artist': a['artist'], 'license': a['license'],
        'source': a['desc'], 'sizeBytes': size, 'durationSec': a['duration'],
    }
    time.sleep(1.5)
    p = info(picks['photo'], width=900)
    assert not any(b in p['license'].upper() for b in ('NC', 'ND')), (bird, 'photo', p['license'])
    psize = dl(p['url'], f'{BASE}/photos/{bird}.jpg')
    photo_manifest[bird] = {
        'artist': p['artist'], 'license': p['license'], 'source': p['desc'],
    }
    print(f"{bird}: audio {size}B [{a['license']}] {a['artist']} | photo {psize}B [{p['license']}] {p['artist']}")
    time.sleep(1.5)

json.dump(audio_manifest, open(BASE + '/audio-new.json', 'w'), indent=2)
json.dump(photo_manifest, open(BASE + '/photos-new.json', 'w'), indent=2)
print('manifests written')
