{ config, common, ... }:
let
  inherit (common) jacobi;
in
{
  programs.bash = {
    enable = true;
    inherit (config.home) sessionVariables;
    historyFileSize = -1;
    historySize = -1;
    shellAliases = {
      ls = "ls --color=auto";
      l = "lsd -lA --permission octal";
      ll = "ls -ahlFG";
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
      export PATH="$PATH:$HOME/.bin/:$HOME/.local/bin"
    '';
  };
}
