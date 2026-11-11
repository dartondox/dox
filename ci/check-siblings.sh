#!/usr/bin/env bash
# Checks that every sibling package (from packages/) that a package needs
# is on pub.dev in a version that fits its constraint. If not, it fails
# with "release <dep> first". Without it, a package could be uploaded that
# nobody can install (pub versions cannot be removed).
# Checks dependencies and dev_dependencies.
#
# Self-test: SELF_TEST=1 ci/check-siblings.sh
# Env: PACKAGES (from ci/publish-order.sh). Needs python3 and network.
set -euo pipefail

if [ -z "${SELF_TEST:-}" ] && [ -z "${PACKAGES:-}" ]; then
  echo "::error::PACKAGES is empty, nothing to check"
  exit 1
fi

# shellcheck disable=SC2086 # one argument per package on purpose
python3 - ${SELF_TEST:+--self-test} ${PACKAGES:-} <<'PY'
import json, re, sys, urllib.request

def ver(s):
    m = re.match(r'(\d+)\.(\d+)\.(\d+)(-[0-9A-Za-z.]+)?', s)
    # a pre-release sorts before the release: (.., 0) < (.., 1)
    return (int(m[1]), int(m[2]), int(m[3]), 0 if m[4] else 1)

def fits(v, c):
    c = c.strip()
    if c.startswith('^'):  # ^3.1.3 = >=3.1.3 <4.0.0 (^0.x: <0.(x+1).0)
        lo = ver(c[1:])
        hi = (lo[0] + 1, 0, 0, 0) if lo[0] else (0, lo[1] + 1, 0, 0)
        ok = lo <= v < hi
        pre_ok = '-' in c
    else:
        ops = re.findall(r'(>=|<=|>|<|==)?\s*([0-9][^\s]*)', c)
        ok = True
        for op, x in ops:
            b = ver(x)
            ok &= {'>=': v >= b, '<=': v <= b, '>': v > b, '<': v < b, '==': v == b, '': v == b}[op]
        pre_ok = any('-' in x for _, x in ops)
    # pub does not pick a pre-release unless the constraint names one
    return ok and (v[3] == 1 or pre_ok)

if sys.argv[1:] == ['--self-test']:
    assert fits(ver('3.1.5'), '^3.1.3')
    assert not fits(ver('3.2.0-dev.1'), '^3.1.0')
    assert fits(ver('3.2.0-dev.1'), '>=3.2.0-dev.1 <4.0.0')
    assert fits(ver('3.1.3'), '3.1.3') and not fits(ver('3.1.4'), '3.1.3')
    assert not fits(ver('3.1.3'), '^3.1.5')
    assert fits(ver('3.1.3'), '>=3.1.0 <3.2.0') and not fits(ver('3.2.0'), '>=3.1.0 <3.2.0')
    print('self-test ok')
    sys.exit(0)

def fetch(dep):
    for i in range(2):  # one retry
        try:
            return json.load(urllib.request.urlopen(f'https://pub.dev/api/packages/{dep}', timeout=20))
        except Exception:
            if i == 1:
                raise

names = {}
for entry in sys.argv[1:]:
    names[entry.split(':')[1]] = entry.split(':')[0]
import glob
siblings = {re.search(r'^name:\s*(\S+)', open(p).read(), re.M)[1]
            for p in glob.glob('packages/*/pubspec.yaml')}

fail = False
for name, folder in names.items():
    text = open(f'packages/{folder}/pubspec.yaml').read()
    for dep, c in re.findall(r"^  ([a-z0-9_]+):\s*['\"]?([\^<>=0-9][^'\"#\n]*)", text, re.M):
        if dep not in siblings or dep == name:
            continue
        try:
            data = fetch(dep)
            vs = [ver(x['version']) for x in data['versions'] if not x.get('retracted')]
        except Exception as e:
            print(f'::error::{name}: cannot read {dep} on pub.dev ({e})')
            fail = True
            continue
        if any(fits(v, c) for v in vs):
            print(f'{name}: {dep} {c.strip()} is on pub.dev')
        else:
            print(f'::error::{name} needs {dep} {c.strip()}, not on pub.dev. Release {dep} first')
            fail = True
sys.exit(1 if fail else 0)
PY
