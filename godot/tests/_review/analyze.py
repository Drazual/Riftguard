#!/usr/bin/env python3
"""Summarise harness output. Usage: python3 analyze.py <dir with sim_<tower>.csv files> [compare_dir]
For each path: (avg of builds WITH it) / (avg of builds WITHOUT it) per scenario, and how often it is in the top 3."""
import csv, statistics as st, sys, os
TOWERS = ['arcane','plasma','tesla','laser','mortar','disc','anvil','frost','beacon']
def load(d, t):
    p = os.path.join(d, f'sim_{t}.csv')
    if not os.path.exists(p): return None
    return {r[2]: list(map(float, r[3:])) for r in csv.reader(open(p)) if r and r[0] == 'RES'}
def table(combos):
    paths = sorted({p for k in combos for p in k.split('+')})
    n = len(next(iter(combos.values())))
    best = {i: [k for k, _ in sorted(combos.items(), key=lambda kv: -kv[1][i])[:3]] for i in range(n)}
    out = {}
    for p in paths:
        rel = []
        for i in range(n):
            w = [v[i] for k, v in combos.items() if p in k.split('+')]
            wo = [v[i] for k, v in combos.items() if p not in k.split('+')]
            rel.append(st.mean(w) / max(1.0, st.mean(wo)))
        top = sum(1 for i in best for k in best[i] if p in k.split('+'))
        out[p] = (rel, top, 3 * n)
    return out, [max(v[i] for v in combos.values()) for i in range(n)]
d = sys.argv[1]; c = sys.argv[2] if len(sys.argv) > 2 else None
for t in TOWERS:
    a = load(d, t)
    if not a: continue
    ta, ba = table(a)
    print(f'\n## {t}   best per scenario: {[round(x) for x in ba]}')
    tb = bb = None
    if c and load(c, t):
        tb, bb = table(load(c, t)); print(f'   compare best:            {[round(x) for x in bb]}')
    for p, (rel, top, of) in ta.items():
        line = f'  {p:10} ' + ' '.join(f'x{x:5.2f}' for x in rel) + f'  top {top}/{of}'
        if tb and p in tb:
            line += '   | compare ' + ' '.join(f'x{x:5.2f}' for x in tb[p][0]) + f'  top {tb[p][1]}/{tb[p][2]}'
        print(line)
