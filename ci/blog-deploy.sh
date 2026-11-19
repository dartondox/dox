#!/usr/bin/env bash
# Puts a built blog (the folder in $1) into blog/ on the gh-pages branch,
# updates the root sitemap.xml (it lists the blog posts too), then pushes
# it. Nothing else on gh-pages changes. See blog.yaml.
set -euo pipefail

site=$(cd "$1" && pwd)
ci=$(cd "$(dirname "$0")" && pwd)
git worktree add ../gh-pages gh-pages
cd ../gh-pages
rm -rf blog
cp -R "$site" blog
python3 "$ci/root_sitemap.py"
git add -A blog sitemap.xml
git diff --cached --quiet || git commit -m "Deploy the blog"
git push origin gh-pages
