#!/usr/bin/env bash
# Fails when the docs or the blog use content tabs (=== "Tab"). They do
# not use them. Use one code block or sub-headings.
set -euo pipefail

if rg -n '^=== "' docs blog/docs; then
  echo "::error::Content tabs are not used in these docs. Use one code block or sub-headings."
  exit 1
fi
