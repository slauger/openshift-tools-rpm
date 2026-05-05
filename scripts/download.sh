#!/bin/bash
set -euo pipefail

PACKAGE="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
PKG_DIR="${ROOT_DIR}/packages/${PACKAGE}"
BIN_DIR="${PKG_DIR}/bin"

# Read version and URL from versions.yaml
VERSION=$(yq ".packages.${PACKAGE}.version" "${ROOT_DIR}/versions.yaml")
URL_TEMPLATE=$(yq ".packages.${PACKAGE}.url" "${ROOT_DIR}/versions.yaml")
URL="${URL_TEMPLATE//\$\{VERSION\}/$VERSION}"
EXTRACT=$(yq ".packages.${PACKAGE}.extract // \"\"" "${ROOT_DIR}/versions.yaml")
BINARY=$(yq ".packages.${PACKAGE}.binary // \"\"" "${ROOT_DIR}/versions.yaml")

# Skip if already downloaded
if [[ -f "${BIN_DIR}/done" ]]; then
    echo "==> Skipping ${PACKAGE} v${VERSION} (already downloaded)"
    exit 0
fi

echo "==> Downloading ${PACKAGE} v${VERSION}"
echo "    URL: ${URL}"

rm -rf "${BIN_DIR}"
mkdir -p "${BIN_DIR}"
TMPDIR=$(mktemp -d)
trap "rm -rf ${TMPDIR}" EXIT

if [[ "${URL}" == *.tar.gz ]] || [[ "${URL}" == *.tgz ]]; then
    curl -sSfL "${URL}" | tar xz -C "${TMPDIR}"
    if [[ -n "${EXTRACT}" ]]; then
        EXTRACT_PATH="${EXTRACT//\$\{VERSION\}/$VERSION}"
        cp "${TMPDIR}/${EXTRACT_PATH}" "${BIN_DIR}/${BINARY}"
    fi
elif [[ "${URL}" == *.zip ]]; then
    curl -sSfL "${URL}" -o "${TMPDIR}/archive.zip"
    unzip -q "${TMPDIR}/archive.zip" -d "${TMPDIR}"
    cp "${TMPDIR}/${EXTRACT}" "${BIN_DIR}/${BINARY}"
else
    # Direct binary download
    curl -sSfL "${URL}" -o "${BIN_DIR}/${BINARY}"
fi

chmod +x "${BIN_DIR}"/*

# Handle extra downloads (e.g., kubens for kubectx package)
EXTRA_URL_TEMPLATE=$(yq ".packages.${PACKAGE}.extra_url // \"\"" "${ROOT_DIR}/versions.yaml")
if [[ -n "${EXTRA_URL_TEMPLATE}" ]]; then
    EXTRA_URL="${EXTRA_URL_TEMPLATE//\$\{VERSION\}/$VERSION}"
    EXTRA_EXTRACT=$(yq ".packages.${PACKAGE}.extra_extract // \"\"" "${ROOT_DIR}/versions.yaml")
    EXTRA_BINARY=$(yq ".packages.${PACKAGE}.extra_binary // \"\"" "${ROOT_DIR}/versions.yaml")

    echo "    Extra: ${EXTRA_URL}"
    TMPDIR2=$(mktemp -d)

    if [[ "${EXTRA_URL}" == *.tar.gz ]]; then
        curl -sSfL "${EXTRA_URL}" | tar xz -C "${TMPDIR2}"
        cp "${TMPDIR2}/${EXTRA_EXTRACT}" "${BIN_DIR}/${EXTRA_BINARY}"
    else
        curl -sSfL "${EXTRA_URL}" -o "${BIN_DIR}/${EXTRA_BINARY}"
    fi

    chmod +x "${BIN_DIR}/${EXTRA_BINARY}"
    rm -rf "${TMPDIR2}"
fi

touch "${BIN_DIR}/done"
echo "==> Done: ${PACKAGE} v${VERSION}"
