#!/usr/bin/env python3
"""Checks the print-model manifest written by `blender -b -P tools/blender/print_export.py -- verify`.
Run: python3 game/tests/test_print_models.py   (exit 0 = pass)"""
import json, os, sys
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DIST = os.path.join(ROOT, 'dist/print')
man = json.load(open(os.path.join(DIST, 'manifest.json')))
by = {os.path.basename(r['file']): r for r in man}
fails = []
def need(cond, msg):
    if not cond: fails.append(msg)
for r in man:
    n = r['file']
    need(r['manifold'], f'{n}: not a single watertight manifold shell ({r["nonmanifold_edges"]} bad edges, {r["components"]} parts, vol {r["volume"]})')
    need(r['volume'] > 0, f'{n}: volume <= 0')
    need(r['stl_exists'], f'{n}: missing STL')
    need(max(r['bbox'][:2]) <= 220.5 and r['bbox'][2] <= 250, f'{n}: exceeds 220x220x250 bed {r["bbox"]}')
def has(prefix, count=1):
    got = [k for k in by if k.startswith(prefix)]
    need(len(got) >= count, f'expected >= {count} files starting with {prefix}, got {got}')
has('hero_'); [has(x) for x in ('rat_mouse', 'rat_sewer', 'rat_trooper', 'rat_officer', 'rat_panzer', 'rat_boss', 'squad_plate')]
has('weapon_', 5); has('prop_crate'); has('prop_barrel'); has('prop_cheese_wheel'); has('prop_key_gold')
has('e1m6_castle_full'); has('e1m6_castle_tile', 4); has('e1m1_room'); has('e1m5_room')
for k, r in by.items():
    if k.startswith('squad'):
        need(r['bbox'][0] <= 200.5 and r['bbox'][1] <= 200.5, 'squad plate larger than 200x200')
print(f'{len(man)} models checked, {len(fails)} failures')
for f in fails: print('FAIL', f)
sys.exit(1 if fails else 0)
