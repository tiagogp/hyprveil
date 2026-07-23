# hyprveil zsh — installed to ~/.zshrc by scripts/04-install-fedora-theming.sh
# (zsh reads config from $HOME, not ~/.config, so the cp -r line doesn't cover it).
# Prompt styling lives in ~/.config/starship.toml.

# history: shared across terminals, no dupes, `<space>cmd` stays out of history
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt inc_append_history share_history hist_ignore_all_dups hist_ignore_space

# completion: menu selection, case-insensitive matching
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# keys: emacs-style line editing; Up/Down search history by what you've typed
bindkey -e
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[3~' delete-char

alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias grep='grep --color=auto'
alias ip='ip -color=auto'

# Fedora plugin paths (dnf: zsh-autosuggestions zsh-syntax-highlighting)
if [ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#6B6E78'   # dimmed ghost text, palette gray
fi
# syntax highlighting must be sourced after every other plugin
[ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && \
    source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

command -v starship >/dev/null && eval "$(starship init zsh)"
command -v fzf >/dev/null && eval "$(fzf --zsh)"
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"

# Pokémon splash on new shells — opt-in, off by default. Flip to true to enable
# (needs pokemon-colorscripts installed; scripts/04-install-fedora-theming.sh offers it).
HYPRVEIL_POKEMON_SHELL=false
if [ "$HYPRVEIL_POKEMON_SHELL" = true ] && command -v pokemon-colorscripts >/dev/null; then
    pokemon-colorscripts --no-title -r
fi
