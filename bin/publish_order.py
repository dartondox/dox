#!/usr/bin/env python3
"""Print `folder:package` for every published package, in publish order.

A package comes after every sibling it depends on (dependencies and
dev_dependencies: pub checks both on publish). Packages with
`publish_to: none` are left out. Run from the repo root.
"""
import glob
import os
import re
import sys

pkgs = {}  # name -> (folder, text)
for path in sorted(glob.glob('packages/*/pubspec.yaml')):
    text = open(path).read()
    if re.search(r"^publish_to:\s*['\"]?none", text, re.M):
        continue
    name = re.search(r'^name:\s*(\S+)', text, re.M).group(1)
    pkgs[name] = (os.path.basename(os.path.dirname(path)), text)

deps = {
    name: {d for d in re.findall(r'^\s+([a-z0-9_]+):', text, re.M)
           if d in pkgs and d != name}
    for name, (_, text) in pkgs.items()
}

order, done = [], set()
while len(order) < len(pkgs):
    ready = sorted(n for n in pkgs if n not in done and deps[n] <= done)
    if not ready:
        sys.exit('dependency cycle: ' + ', '.join(sorted(set(pkgs) - done)))
    for n in ready:
        order.append(n)
        done.add(n)

for n in order:
    print(f'{pkgs[n][0]}:{n}')
