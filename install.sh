#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> Installing Homebrew packages..."
brew bundle --file="${DOTFILES_DIR}/Brewfile"

echo "==> Installing fly CLI..."
echo "    Set CONCOURSE_URL env var to your Concourse server before running."
echo "    Skipping fly install if CONCOURSE_URL is not set or is the default."

if [[ "${CONCOURSE_URL:-https://ci.example.com}" != "https://ci.example.com" ]]; then
  bash "${DOTFILES_DIR}/scripts/install-fly.sh"
else
  echo "    CONCOURSE_URL not configured — skipping fly install."
  echo "    Run: CONCOURSE_URL=https://your-ci-server ${DOTFILES_DIR}/scripts/install-fly.sh"
fi

echo "==> Done!"
