#!/usr/bin/env bash
set -euo pipefail

# download_pyodide.sh <version>
# version: a release tag (e.g. "0.23.4") or "latest"
# expects GITHUB_TOKEN in env to avoid rate limits when contacting the GitHub API

VERSION="${1:-latest}"
API_BASE="https://api.github.com/repos/pyodide/pyodide"
WORKDIR="$(pwd)/.github/tmp-pyodide-work"
DISTDIR="$(pwd)/pyodide-dist"

mkdir -p "${WORKDIR}"
rm -rf "${DISTDIR}"
mkdir -p "${DISTDIR}"

# fetch release JSON
if [ "${VERSION}" = "latest" ]; then
  RELEASE_JSON=$(curl -sSL -H "Accept: application/vnd.github+json" -H "Authorization: token ${GITHUB_TOKEN}" "${API_BASE}/releases/latest")
else
  RELEASE_JSON=$(curl -sSL -H "Accept: application/vnd.github+json" -H "Authorization: token ${GITHUB_TOKEN}" "${API_BASE}/releases/tags/${VERSION}")
fi

# ensure assets exist
ASSETS_COUNT=$(echo "${RELEASE_JSON}" | jq '.assets | length')
if [ "${ASSETS_COUNT}" -eq 0 ]; then
  echo "No assets found for release ${VERSION}"
  echo "Release JSON:"
  echo "${RELEASE_JSON}"
  exit 1
fi

# Download each asset
echo "Found ${ASSETS_COUNT} assets. Downloading..."
echo "${RELEASE_JSON}" | jq -r '.assets[] | [.name, .browser_download_url] | @tsv' | while IFS=$'\t' read -r NAME URL; do
  echo "  - ${NAME}"
  OUT="${WORKDIR}/${NAME}"
  curl -L -H "Authorization: token ${GITHUB_TOKEN}" -o "${OUT}" "${URL}"

  case "${NAME}" in
    *.tar.bz2|*.tar.gz|*.tgz)
      TMP="${WORKDIR}/extract_tmp"
      mkdir -p "${TMP}"
      tar -xf "${OUT}" -C "${TMP}"
      # copy contents (works whether tar has top-level dir or not)
      cp -r "${TMP}/." "${DISTDIR}/"
      rm -rf "${TMP}"
      ;;
    *.zip)
      TMP="${WORKDIR}/extract_tmp"
      mkdir -p "${TMP}"
      unzip -q "${OUT}" -d "${TMP}"
      cp -r "${TMP}/." "${DISTDIR}/"
      rm -rf "${TMP}"
      ;;
    *)
      # single file (e.g. pyodide.js) -> copy into dist
      cp "${OUT}" "${DISTDIR}/"
      ;;
  esac
done

# cleanup
rm -rf "${WORKDIR}"

echo "Pyodide release ${VERSION} downloaded and extracted to ${DISTDIR}"
