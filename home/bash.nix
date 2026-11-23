{ config, common, lib, pkgs, ... }:
let
  inherit (common) jacobiLegacy;
in
{
  programs.bash = {
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
    } // jacobiLegacy.hax.docker_aliases // jacobiLegacy.hax.kubernetes_aliases;

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

      if (( BASH_VERSINFO[0] >= 4 )) && [ -n "''${BASH_COMPLETION_VERSINFO:-}" ]; then
        source ${pkgs.complete-alias}/bin/complete_alias
        if (( ''${#BASH_ALIASES[@]} > 0 )); then
          complete -F _complete_alias "''${!BASH_ALIASES[@]}"
        fi
      fi

      # jet terminal OSC 7 (cwd) & OSC 1337 status bar variables
      source ${./scripts/jet-status.bash}
      if [ -n "''${STARSHIP_SHELL:-}" ] || command -v starship >/dev/null 2>&1; then
        starship_precmd_user_func="__jet_status"
      else
        case "''${PROMPT_COMMAND:-}" in
          *__jet_status*) ;;
          *) PROMPT_COMMAND="__jet_status''${PROMPT_COMMAND:+;$PROMPT_COMMAND}" ;;
        esac
      fi

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
