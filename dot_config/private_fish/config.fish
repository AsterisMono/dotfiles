set fish_greeting

starship init fish | source
zoxide init fish | source
atuin init fish --disable-up-arrow | source
devenv hook fish | source

fish_add_path ~/.local/bin

alias n='nvim'
alias gg='lazygit'
alias cl='claude --dangerously-skip-permissions'

if test -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish
    source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish
end

fish_add_path ~/.nix-profile/bin

set -x SSH_AUTH_SOCK "~/.1password/agent.sock"
