#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Find the latest stable channel
LATEST_CHANNEL=$(curl -s https://raw.githubusercontent.com/openshift/cincinnati-graph-data/master/channels/ | \
  grep -oP 'stable-4\.\d+' | sort -t. -k2 -n | tail -1)

echo "Latest stable channel: ${LATEST_CHANNEL}"

# Get latest version from Cincinnati API
LATEST_VERSION=$(curl -s -H "Accept: application/json" \
  "https://api.openshift.com/api/upgrades_info/v1/graph?channel=${LATEST_CHANNEL}" | \
  python3 -c "
import sys, json
data = json.load(sys.stdin)
nodes = data.get('nodes', [])
if nodes:
    best = max(nodes, key=lambda n: [int(x) for x in n['version'].split('.')])
    print(best['version'])
")

echo "Latest OCP version: ${LATEST_VERSION}"

CURRENT_VERSION=$(yq '.packages.oc.version' "${ROOT_DIR}/versions.yaml")

if [[ "${CURRENT_VERSION}" == "${LATEST_VERSION}" ]]; then
  echo "Already up to date"
  exit 0
fi

echo "Updating oc: ${CURRENT_VERSION} -> ${LATEST_VERSION}"
yq -i ".packages.oc.version = \"${LATEST_VERSION}\"" "${ROOT_DIR}/versions.yaml"
