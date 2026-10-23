#!/usr/bin/env python3
"""Picks the CI jobs that a change can break. Run from the repo root.

Reads the changed files from stdin, one per line. With ALL=1 in the env,
everything runs. Prints `key=value` lines for $GITHUB_OUTPUT:

  code      true when any file other than docs changed
  changed   JSON list of package folders to treat as changed. Native
            tests use it.
  tests     JSON matrix of the ci/test-matrix.json entries to run
  examples  JSON matrix of the examples/ apps to run

Rules:
- Docs files (*.md, docs/, mkdocs.yml, overrides/) are ignored.
- A file under packages/<folder>/ changes that package. A file under
  examples/<folder>/ changes that example.
- Any other file (root pubspec, ci/, .github/, bin/, ...) runs everything.
- A package is affected when it changed, or when it depends on an
  affected package (dependencies and dev_dependencies, transitively).
- A test entry runs when one of its packages is affected. An example runs
  when it changed, or when it uses an affected package.
"""
import glob
import json
import os
import re
import sys

DOCS = re.compile(r'(\.md$|^docs/|^mkdocs\.yml$|^overrides/)')


def read_pubspecs(pattern):
    """folder -> text of its pubspec.yaml."""
    out = {}
    for path in sorted(glob.glob(pattern)):
        text = open(path).read()
        out[os.path.basename(os.path.dirname(path))] = text
    return out


# ponytail: same pubspec scan as bin/publish_order.py. Any indented key
# that names a sibling package counts as a dependency.
pkg_text = read_pubspecs('packages/*/pubspec.yaml')
name_to_folder = {
    re.search(r'^name:\s*(\S+)', t, re.M).group(1): f for f, t in pkg_text.items()
}


def deps_of(text, self_folder=None):
    return {
        name_to_folder[d]
        for d in re.findall(r'^\s+([a-z0-9_]+):', text, re.M)
        if d in name_to_folder and name_to_folder[d] != self_folder
    }


pkg_deps = {f: deps_of(t, f) for f, t in pkg_text.items()}
# The examples use only the packages in pubspec.yaml. pubspec_overrides.yaml
# points every dox package to this repo, so it is not read here.
example_deps = {f: deps_of(t) for f, t in read_pubspecs('examples/*/pubspec.yaml').items()}

files = [line.strip() for line in sys.stdin if line.strip()]
code_files = [f for f in files if not DOCS.search(f)]
run_all = os.environ.get('ALL') == '1'

changed_pkgs, changed_examples = set(), set()
for f in code_files:
    parts = f.split('/')
    if len(parts) > 2 and parts[0] == 'packages' and parts[1] in pkg_deps:
        changed_pkgs.add(parts[1])
    elif len(parts) > 2 and parts[0] == 'examples' and parts[1] in example_deps:
        changed_examples.add(parts[1])
    else:
        run_all = True

if run_all:
    changed_pkgs, changed_examples = set(pkg_deps), set(example_deps)

# Grow the set until no package depends on one outside it.
affected = set(changed_pkgs)
grew = True
while grew:
    grew = False
    for folder, deps in pkg_deps.items():
        if folder not in affected and deps & affected:
            affected.add(folder)
            grew = True

with open('ci/test-matrix.json') as fh:
    entries = json.load(fh)
tests = [e for e in entries if set(e['packages'].split()) & affected]
examples = [
    {'example': f}
    for f, deps in example_deps.items()
    if f in changed_examples or deps & affected
]

print(f'code={"true" if run_all or code_files else "false"}')
# Compact JSON: the workflow skips a job when its matrix is {"include":[]}.
print('changed=' + json.dumps(sorted(changed_pkgs), separators=(',', ':')))
print('tests=' + json.dumps({'include': tests}, separators=(',', ':')))
print('examples=' + json.dumps({'include': examples}, separators=(',', ':')))
