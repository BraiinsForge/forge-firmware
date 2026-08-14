#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
workflow=$repo_root/.github/workflows/build-forge-axe.yml

require() {
    local description=$1
    local pattern=$2
    if ! grep -Fq -- "$pattern" "$workflow"; then
        echo "workflow does not $description: $pattern" >&2
        exit 1
    fi
}

# Releases need write access, while the token should remain scoped to publishing steps.
require "grant release write access" "contents: write"
require "discard checkout credentials before building" "persist-credentials: false"
require "pass the built-in token to release commands" 'GH_TOKEN: ${{ github.token }}'

# Master builds are intentionally replaceable; version-tag releases are permanent.
require "use a stable rolling tag for master" "tag=master-latest"
require "move the rolling tag through GitHub" '--method PATCH'
require "force the rolling tag update" '-F force=true'
require "mark the rolling release as a prerelease" "--prerelease"
require "publish the pushed version tag" 'tag=$GITHUB_REF_NAME'
require "generate notes for version releases" "--generate-notes"
require "make rerun uploads idempotent" 'gh release upload "$tag" forge-axe/build/* --clobber'

# Releases supplement rather than replace the short-lived workflow artifact.
require "retain the workflow artifact" "uses: actions/upload-artifact@v7"
