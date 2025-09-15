#!/usr/bin/env bash

set -ex

GH_ARCH="amd64"

TAG=$( curl --retry 12 --retry-delay 30 "https://api.github.com/repos/cli/cli/releases/latest" | jq --raw-output '.tag_name' )
VERSION=${TAG#v}

# Fallback to a known working version if API returns null
if [[ "${TAG}" == "null" || -z "${TAG}" ]]; then
  echo "Warning: GitHub API returned null, using fallback version"
  TAG="v2.62.0"
  VERSION="2.62.0"
fi

curl --retry 12 --retry-delay 120 -sSL "https://github.com/cli/cli/releases/download/${TAG}/gh_${VERSION}_linux_${GH_ARCH}.tar.gz" -o "gh_${VERSION}_linux_${GH_ARCH}.tar.gz"

tar xf "gh_${VERSION}_linux_${GH_ARCH}.tar.gz"

cp "gh_${VERSION}_linux_${GH_ARCH}/bin/gh" /usr/local/bin/

gh --version
