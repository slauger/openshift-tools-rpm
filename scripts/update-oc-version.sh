#!/usr/bin/env bash
#
# Bump packages.oc.version in versions.yaml to the newest release of the
# latest OpenShift stable channel (Cincinnati graph).
#
# Optional: GH_TOKEN / GITHUB_TOKEN to avoid GitHub API rate limits.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
VERSIONS_FILE="${ROOT_DIR}/versions.yaml"

CHANNELS_API="https://api.github.com/repos/openshift/cincinnati-graph-data/contents/channels?ref=master"
GRAPH_API="https://api.openshift.com/api/upgrades_info/v1/graph"
MIRROR_URL="https://mirror.openshift.com/pub/openshift-v4/clients/ocp"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
AUTH_HEADER=()
if [[ -n "${TOKEN}" ]]; then
  AUTH_HEADER=(-H "Authorization: Bearer ${TOKEN}")
fi

# Find the latest stable channel (e.g. stable-4.22) from cincinnati-graph-data
CHANNELS_JSON=$(curl -sSfL ${AUTH_HEADER[@]+"${AUTH_HEADER[@]}"} \
  -H "Accept: application/vnd.github+json" "${CHANNELS_API}") \
  || die "failed to list channels from ${CHANNELS_API}"

LATEST_CHANNEL=$(python3 -c '
import json, re, sys
names = [e["name"] for e in json.load(sys.stdin)]
minors = [int(m.group(1)) for n in names if (m := re.fullmatch(r"stable-4\.(\d+)\.yaml", n))]
if minors:
    print(f"stable-4.{max(minors)}")
' <<<"${CHANNELS_JSON}")

[[ -n "${LATEST_CHANNEL}" ]] || die "no stable-4.x channel found"
echo "Latest stable channel: ${LATEST_CHANNEL}"

# Get the newest version in that channel from the Cincinnati API
GRAPH_JSON=$(curl -sSfL -H "Accept: application/json" \
  "${GRAPH_API}?channel=${LATEST_CHANNEL}") \
  || die "failed to query Cincinnati graph for ${LATEST_CHANNEL}"

LATEST_VERSION=$(python3 -c '
import json, re, sys
versions = [n["version"] for n in json.load(sys.stdin).get("nodes", [])]
versions = [v for v in versions if re.fullmatch(r"\d+\.\d+\.\d+", v)]
if versions:
    print(max(versions, key=lambda v: [int(x) for x in v.split(".")]))
' <<<"${GRAPH_JSON}")

[[ -n "${LATEST_VERSION}" ]] || die "no release found in channel ${LATEST_CHANNEL}"
echo "Latest OCP version: ${LATEST_VERSION}"

CURRENT_VERSION=$(yq '.packages.oc.version' "${VERSIONS_FILE}")
echo "Current oc version: ${CURRENT_VERSION}"

if [[ "${CURRENT_VERSION}" == "${LATEST_VERSION}" ]]; then
  echo "Already up to date"
  exit 0
fi

# Never downgrade
NEWEST=$(printf '%s\n%s\n' "${CURRENT_VERSION}" "${LATEST_VERSION}" | sort -V | tail -1)
if [[ "${NEWEST}" != "${LATEST_VERSION}" ]]; then
  echo "Current version ${CURRENT_VERSION} is newer than ${LATEST_VERSION}, skipping"
  exit 0
fi

# Make sure the client tarball is actually published before bumping
ASSET_URL="${MIRROR_URL}/${LATEST_VERSION}/openshift-client-linux.tar.gz"
curl -sSfIL -o /dev/null "${ASSET_URL}" || die "client tarball not available: ${ASSET_URL}"

echo "Updating oc: ${CURRENT_VERSION} -> ${LATEST_VERSION}"
# Edit in place with sed (yq -i would drop the blank lines between packages)
TMP_FILE=$(mktemp)
sed "/^  oc:\$/,/^    version:/ s/^    version: \".*\"\$/    version: \"${LATEST_VERSION}\"/" \
  "${VERSIONS_FILE}" >"${TMP_FILE}"
cat "${TMP_FILE}" >"${VERSIONS_FILE}"
rm -f "${TMP_FILE}"

[[ "$(yq '.packages.oc.version' "${VERSIONS_FILE}")" == "${LATEST_VERSION}" ]] \
  || die "failed to update packages.oc.version in ${VERSIONS_FILE}"
