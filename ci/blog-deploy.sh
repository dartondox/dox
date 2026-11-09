#!/usr/bin/env bash
# Puts a built blog (the folder in $1) into blog/ on the gh-pages branch,
# then pushes it. Nothing else on gh-pages changes. See blog.yaml.
set -euo pipefail

site=$(cd "$1" && pwd)
git worktree add ../gh-pages gh-pages
cd ../gh-pages
rm -rf blog
cp -R "$site" blog
git add -A blog
git diff --cached --quiet || git commit -m "Deploy the blog"
git push origin gh-pages
