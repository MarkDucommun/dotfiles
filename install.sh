#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
MISE_CONFIG_DIR="${HOME}/.config/mise"
MISE_CONFIG="${MISE_CONFIG_DIR}/config.toml"
MISE_REPO_CONFIG="${DOTFILES_DIR}/mise/config.toml"
DOCKER_CLI_PLUGINS_DIR="${HOME}/.docker/cli-plugins"

link_file() {
  local src="$1"
  local dst="$2"
  local backup

  mkdir -p "$(dirname "$dst")"

  if [[ -L "$dst" ]]; then
    if [[ "$(readlink "$dst")" == "$src" ]]; then
      echo "    ${dst} already linked"
      return
    fi

    echo "    Relinking ${dst} -> ${src}"
    ln -sfn "$src" "$dst"
    return
  fi

  if [[ -e "$dst" ]]; then
    backup="${dst}.backup.$(date +%Y%m%d%H%M%S)"
    echo "    Existing ${dst} found; moving it to ${backup}"
    mv "$dst" "$backup"
  fi

  ln -s "$src" "$dst"
  echo "    Linked ${dst} -> ${src}"
}

echo "==> Installing Homebrew packages..."
brew bundle --file="${DOTFILES_DIR}/Brewfile"

echo "==> Linking shell, prompt, terminal, and git config..."
link_file "${DOTFILES_DIR}/zshrc" "${HOME}/.zshrc"
link_file "${DOTFILES_DIR}/starship.toml" "${HOME}/.config/starship.toml"
link_file "${DOTFILES_DIR}/ghostty.conf" "${HOME}/.config/ghostty/config"
link_file "${DOTFILES_DIR}/gitconfig" "${HOME}/.gitconfig"
link_file "${DOTFILES_DIR}/gitignore_global" "${HOME}/.gitignore_global"

echo "==> Linking mise config..."
link_file "${MISE_REPO_CONFIG}" "${MISE_CONFIG}"

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
