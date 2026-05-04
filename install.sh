#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
MISE_CONFIG_DIR="${HOME}/.config/mise"
MISE_CONFIG="${MISE_CONFIG_DIR}/config.toml"
MISE_REPO_CONFIG="${DOTFILES_DIR}/mise/config.toml"
DOCKER_CLI_PLUGINS_DIR="${HOME}/.docker/cli-plugins"

echo "==> Installing Homebrew packages..."
brew bundle --file="${DOTFILES_DIR}/Brewfile"

echo "==> Linking mise config..."
mkdir -p "${MISE_CONFIG_DIR}"
if [[ -e "${MISE_CONFIG}" && ! -L "${MISE_CONFIG}" ]]; then
  BACKUP="${MISE_CONFIG}.backup.$(date +%Y%m%d%H%M%S)"
  echo "    Existing mise config found; moving it to ${BACKUP}"
  mv "${MISE_CONFIG}" "${BACKUP}"
fi
ln -sfn "${MISE_REPO_CONFIG}" "${MISE_CONFIG}"

echo "==> Installing mise tools..."
mise install

echo "==> Linking Docker CLI plugins..."
mkdir -p "${DOCKER_CLI_PLUGINS_DIR}"
ln -sfn "$(brew --prefix)/opt/docker-compose/bin/docker-compose" "${DOCKER_CLI_PLUGINS_DIR}/docker-compose"
ln -sfn "$(brew --prefix)/opt/docker-buildx/bin/docker-buildx" "${DOCKER_CLI_PLUGINS_DIR}/docker-buildx"
echo "    Start Colima when you need containers: colima start"

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
