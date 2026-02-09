# autoload -U colors && colors	# Load colors
# PS1="%B%{$fg[red]%}[%{$fg[yellow]%}%n%{$fg[green]%} @ %{$fg[blue]%}%~%{$fg[red]%}]%{$reset_color%}$%b "

stty stop undef		# Disable ctrl-s to freeze terminal.

autoload -U compinit
zstyle ':completion:*' menu select
zmodload zsh/complist
compinit
_comp_options+=(globdots)		# Include hidden files.

# SSH & GPG
unset SSH_AGENT_PID
if [ "${gnupg_SSH_AUTH_SOCK_by:-0}" -ne $$ ]; then
  export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
fi

export GPG_TTY=$(tty)
gpg-connect-agent updatestartuptty /bye >/dev/null

HISTSIZE=10000000
SAVEHIST=10000000
HISTFILE=~/.cache/zsh/history

source "$XDG_CONFIG_HOME"/shell/aliasrc
source "$XDG_CONFIG_HOME"/shell/profile

eval "$(starship init zsh)"
