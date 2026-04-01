#!/usr/bin/env bash
set -euo pipefail

# Update this to your Concourse server URL
CONCOURSE_URL="${CONCOURSE_URL:-https://ci.example.com}"

INSTALL_DIR="/usr/local/bin"
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  arm64)  ARCH="arm64" ;;
  *)      echo "Unsupported architecture: $ARCH" && exit 1 ;;
esac

echo "Downloading fly from ${CONCOURSE_URL}..."
curl -sL "${CONCOURSE_URL}/api/v1/cli?arch=${ARCH}&platform=${OS}" -o /tmp/fly
chmod +x /tmp/fly
sudo mv /tmp/fly "${INSTALL_DIR}/fly"

echo "fly installed to ${INSTALL_DIR}/fly"
fly --version
