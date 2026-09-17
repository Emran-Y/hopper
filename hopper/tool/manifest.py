#!/usr/bin/env python3
"""Writes dist/downloads/manifest.json — what the website's Download section shows (sizes, SHA-256)."""
import hashlib, json, os, sys, datetime, re
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
d = os.path.join(root, 'dist', 'downloads')
version = re.search(r'^version:\s*([\d.]+)', open(os.path.join(root, 'pubspec.yaml')).read(), re.M).group(1)
meta = {
 'Hopper-Mac.zip':                ('macOS',   'Mac (Apple silicon & Intel)',        'macOS 12 or newer'),
 'Hopper-android-arm64-v8a.apk':  ('Android', 'Android · 64-bit ARM (recommended)', 'Every phone since ~2017 (Samsung, Pixel, OnePlus…)'),
 'Hopper-android-armeabi-v7a.apk':('Android', 'Android · 32-bit ARM',               'Older or budget phones'),
 'Hopper-android-x86_64.apk':     ('Android', 'Android · x86_64',                   'Emulators, Chromebooks'),
 'android-setup.sh':              ('Setup',   'One-time Android setup script',      'Run once on a Mac/PC with adb, phone plugged in — enables automatic sending'),
}
out = []
for name, (plat, label, note) in meta.items():
    p = os.path.join(d, name)
    if not os.path.exists(p): continue
    b = open(p, 'rb').read()
    out.append({'file': name, 'platform': plat, 'label': label, 'note': note, 'bytes': len(b), 'sha256': hashlib.sha256(b).hexdigest()})
json.dump({'version': version, 'built': datetime.date.today().isoformat(), 'files': out}, open(os.path.join(d, 'manifest.json'), 'w'), indent=1)
print('✓ manifest:', ', '.join(o['file'] for o in out))
