#!/usr/bin/env python3
"""Runs a group of test entries from ci/test-matrix.json in parallel, in one
CI job. Run from the repo root.

Env: ENTRIES: JSON list of entries (the `unit` or `databases` output of
     ci/affected.py). Each entry runs ci/run-tests.sh with its `packages`
     and `vars`.
     MAX_PARALLEL: how many entries run at the same time. Default: the
     number of CPUs.

Entries run at the same time, except when they share a lock. `locks` of
an entry names what it can not share, like one database
("postgres mariadb"). An entry starts only when no running entry holds
one of its locks. So the tests that use the same database run one after
the other, and the tests on other databases run next to them.

Each entry writes to its own log. When all are done, every log is printed
in its own `::group::`, then a summary. Exit code 1 when any entry failed.
"""
import json
import os
import subprocess
import sys
import tempfile
import time

entries = json.loads(os.environ['ENTRIES'])
max_parallel = int(os.environ.get('MAX_PARALLEL') or os.cpu_count() or 2)
log_dir = tempfile.mkdtemp(prefix='dox-tests-')

pending = list(entries)
running = {}  # Popen -> (entry, log file, start time)
results = []  # (entry, exit code, seconds, log path)


def locks(entry):
    return set(entry.get('locks', '').split())


def start(entry, index):
    path = os.path.join(log_dir, f'{index:02d}.log')
    log = open(path, 'w')
    env = dict(
        os.environ,
        TEST_PACKAGES=entry['packages'],
        TEST_VARS=entry.get('vars', ''),
        # run-tests.sh prints ::group:: lines. Groups can not be nested,
        # so this file prints the whole log in one group.
        NO_LOG_GROUPS='1',
    )
    proc = subprocess.Popen(
        ['ci/run-tests.sh'], env=env, stdout=log, stderr=subprocess.STDOUT
    )
    running[proc] = (entry, log, time.monotonic(), path)
    print(f'started: {entry["name"]}', flush=True)


index = 0
while pending or running:
    busy = set().union(*(locks(e) for e, *_ in running.values()))
    for entry in list(pending):
        if len(running) >= max_parallel:
            break
        if locks(entry) & busy:
            continue
        pending.remove(entry)
        busy |= locks(entry)
        index += 1
        start(entry, index)
    # ponytail: poll every second. Fine for a few long test runs.
    time.sleep(1)
    for proc in [p for p in running if p.poll() is not None]:
        entry, log, began, path = running.pop(proc)
        log.close()
        seconds = time.monotonic() - began
        results.append((entry, proc.returncode, seconds, path))
        state = 'passed' if proc.returncode == 0 else 'FAILED'
        print(f'{state}: {entry["name"]} ({seconds:.0f}s)', flush=True)

for entry, code, seconds, path in results:
    state = 'passed' if code == 0 else 'FAILED'
    print(f'::group::{entry["name"]}: {state} ({seconds:.0f}s)')
    with open(path) as fh:
        sys.stdout.write(fh.read())
    print('::endgroup::', flush=True)

failed = [e['name'] for e, code, *_ in results if code != 0]
print(f'{len(results) - len(failed)} passed, {len(failed)} failed')
for name in failed:
    print(f'::error::{name} failed. Open its log group above.')
sys.exit(1 if failed else 0)
