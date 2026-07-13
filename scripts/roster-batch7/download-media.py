#!/usr/bin/env python3
"""Download chosen audio + photos, emit manifest entries."""
import json, subprocess, re, os, urllib.parse, time

PICKS = {
    'california_quail': {
        'audio': 'File:Callipepla californica - California Quail XC109825.mp3',
        'photo': 'File:California quail (Callipepla californica) Waitakere.jpg',
    },
    'annas_hummingbird': {
        'audio': "File:Calypte anna - Anna's Hummingbird XC153035.mp3",
        'photo': "File:Anna's hummingbird (41119).jpg",
    },
    'purple_gallinule': {
        'audio': 'File:Porphyrio martinica - Purple Gallinule XC457186.mp3',
        'photo': 'File:Purple Gallinule - Porphyrio martinica, Everglades National Park, Homestead, Florida (38539237780).jpg',
    },
    'green_heron': {
        'audio': 'File:Butorides virescens - Green Heron XC469642.mp3',
        'photo': 'File:Green heron (Butorides virescens), South Padre Island, Texas, USA.jpg',
    },
    'veery': {
        'audio': 'File:Catharus fuscescens - Veery XC78881.mp3',
        'photo': 'File:Veery in CP (43277).jpg',
    },
    'dickcissel': {
        'audio': 'File:Spiza americana - Dickcissel XC82764.mp3',
        'photo': 'File:Spiza americana male 94 231051626 13e01e8125 o.jpg',
    },
    'american_avocet': {
        'audio': 'File:Recurvirostra americana - American Avocet XC99571.mp3',
        'photo': 'File:American avocet (84283).jpg',
    },
}

BASE = os.path.dirname(os.path.abspath(__file__)) + '/media'
os.makedirs(BASE + '/audio', exist_ok=True)
os.makedirs(BASE + '/photos', exist_ok=True)

def api(params):
    url = 'https://commons.wikimedia.org/w/api.php?' + urllib.parse.urlencode(params)
    for attempt in range(8):
        out = subprocess.run(['curl', '-s', '--max-time', '60', url], capture_output=True, text=True).stdout
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
    subprocess.run(['curl', '-sL', '--max-time', '180', '-o', dest, url], check=True)
    return os.path.getsize(dest)

audio_manifest, photo_manifest = {}, {}
for bird, picks in PICKS.items():
    a = info(picks['audio'])
    assert not any(b in a['license'].upper() for b in ('NC', 'ND')), (bird, 'audio', a['license'])
    size = dl(a['origurl'], f'{BASE}/audio/{bird}.mp3')
    audio_manifest[bird] = {
        'file': picks['audio'], 'artist': a['artist'], 'license': a['license'],
        'source': a['desc'], 'sizeBytes': size, 'durationSec': a['duration'],
    }
    p = info(picks['photo'], width=900)
    assert not any(b in p['license'].upper() for b in ('NC', 'ND')), (bird, 'photo', p['license'])
    psize = dl(p['url'], f'{BASE}/photos/{bird}.jpg')
    photo_manifest[bird] = {
        'artist': p['artist'], 'license': p['license'], 'source': p['desc'],
    }
    print(f"{bird}: audio {size}B {a['duration']:.0f}s [{a['license']}] {a['artist']} | photo {psize}B [{p['license']}] {p['artist']}")

json.dump(audio_manifest, open(BASE + '/audio-new.json', 'w'), indent=2)
json.dump(photo_manifest, open(BASE + '/photos-new.json', 'w'), indent=2)
print('manifests written')
