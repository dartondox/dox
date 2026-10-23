#!/usr/bin/env bash
# Fails when the docs use content tabs (=== "Tab"). These docs do not use
# them. Use one code block or sub-headings.
set -euo pipefail

if rg -n '^=== "' docs; then
  echo "::error::Content tabs are not used in these docs. Use one code block or sub-headings."
  exit 1
fi
