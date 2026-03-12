set fish_greeting

starship init fish | source
zoxide init fish | source

fish_add_path ~/.local/bin
fish_add_path /opt/nvim-linux-x86_64/bin

alias n='nvim'
alias gg='lazygit'

set -x SSH_AUTH_SOCK "~/.1password/agent.sock"
