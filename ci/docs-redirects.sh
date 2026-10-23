#!/usr/bin/env bash
# Writes the redirect pages for old docs links, the root index.html,
# 404.html, CNAME and robots.txt on the gh-pages branch, then pushes it.
# See ci/docs_redirects.py. Run it after mike deploy.
set -euo pipefail

ci=$(cd "$(dirname "$0")" && pwd)
git worktree add ../gh-pages gh-pages
cd ../gh-pages
python3 "$ci/docs_redirects.py"
git add -A
git diff --cached --quiet || git commit -m "Redirect old docs links"
git push origin gh-pages
