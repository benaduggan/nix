{ config, common, lib, ... }:
let
  inherit (common) jacobi;
  inherit (common) machineName;
  perUser = if machineName == "paper" then "benduggan" else "bduggan";
in
{
  programs. bash = {
    enable = true;
    inherit (config.home) sessionVariables;
    historyFileSize = -1;
    historySize = -1;
    shellAliases = {
      cc = "security unlock-keychain ~/Library/Keychains/login.keychain-db && claude";
      ls = lib.mkForce "ls --color=auto";
      l = lib.mkForce "lsd -lA --permission octal";
      ll = lib.mkForce "ls -ahlFG";
      mkdir = "mkdir -pv";
      hm = "home-manager";
      wrun =
        "watchexec --debounce 50 --no-shell --clear --restart --signal SIGTERM -- ";

      # git
      g = "git";
      ga = "g add -A .";
      cm = "g commit -m ";

      hidden = "g ls-files -v | grep '^S' | cut -c3-";
      hide = ''g update-index --skip-worktree "$@"'';
      unhide = "g update-index --no-skip-worktree";

      # misc
      rot13 = "tr 'A-Za-z' 'N-ZA-Mn-za-m'";
      space = "du -Sh | sort -rh | head -10";
      now = "date +%s";
      fzfp = "fzf --preview 'bat --style=numbers --color=always {}'";
    } // jacobi.hax.docker_aliases // jacobi.hax.kubernetes_aliases;

    initExtra = ''
      shopt -s histappend
      set +h

      export DO_NOT_TRACK=1
      export LC_ALL=en_US.UTF-8
      export LANG=en_US.UTF-8

      # add local scripts to path
      export PATH="$PATH:$HOME/.bin/:$HOME/.local/bin:$HOME/.rd/bin"
      # mkdir -p $HOME/.completions
      # source $HOME/.completions/*

      # source ~/.nix-profile/etc/profile.d/bash_completion.sh
      source /etc/profiles/per-user/${perUser}/share/bash-completion/completions/git
      source /etc/profiles/per-user/${perUser}/share/bash-completion/completions/ssh
      complete -o bashdefault -o default -o nospace -F __git_wrap__git_main g
      complete -F __start_kubectl k
      source /etc/profiles/per-user/${perUser}/share/bash-completion/completions/docker
      complete -F _docker d

      gu() {
        MSG="guh"
        if [ $# -gt 0 ] ; then
          MSG="$@"
        fi
        git add -A
        git commit -nm "$MSG"
      }

      guh() {
        MSG="guh"
        if [ $# -gt 0 ] ; then
          MSG="$@"
        fi
        git add -A
        git commit -nm "$MSG"
        git put --no-verify
      }
    '';
  };
}
