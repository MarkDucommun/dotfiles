# =============================================================================
# History
# =============================================================================
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS

# =============================================================================
# Completion
# =============================================================================
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'  # case-insensitive

# =============================================================================
# Homebrew
# =============================================================================
eval "$(/opt/homebrew/bin/brew shellenv)"

# =============================================================================
# Starship prompt
# =============================================================================
eval "$(starship init zsh)"

# =============================================================================
# Aliases
# =============================================================================
alias ls='ls -GF'
alias ll='ls -lAGF'
alias la='ls -lAGF'

# Git shortcuts
alias g='git'
alias gs='git status'
alias gd='git diff'
alias gp='git push'
alias gl='git pull'
alias gc='git commit'
alias gco='git checkout'
alias gb='git branch'

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ~='cd ~'

# Misc
alias reload='source ~/.zshrc'

# =============================================================================
# Path
# =============================================================================
export PATH="$HOME/.local/bin:$PATH"

# =============================================================================
# Editor
# =============================================================================
export EDITOR='nano'
export VISUAL='nano'

if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi
