{ config, pkgs, lib, ... }:
let
  inherit (pkgs.hax) fetchFromGitHub;

  personalEmail = "benaduggan@gmail.com";
  workEmail = "benduggan@readlee.com";
  firstName = "Ben";
  lastName = "Duggan";
  home = (builtins.getEnv "HOME");
  username = (builtins.getEnv "USER");
  symbol = "ᛥ";

  # chief keefs stuff
  kwbauson-cfg = import <kwbauson-cfg>;

  # cobi's stuff
  jacobi = import (
    pkgs.fetchFromGitHub {
      owner = "jpetrucciani";
      repo = "nix";
      rev = "9f4c761a6fb58f513a82455a0a39e5b6fbfb463f";
      sha256 = "13zzkq8zmdd07v014z5v0ik5smvqn89vxr5h61qnpnm625gn0kiw";
    }
  );
in
with pkgs.hax; {
  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  home = {
    username = username;
    homeDirectory = home;

    stateVersion = "21.05";

    sessionVariables = {
      EDITOR = "nano";
      HISTCONTROL = "ignoreboth";
      PAGER = "less";
      LESS = "-iR";
      BASH_SILENCE_DEPRECATION_WARNING = "1";
    };

    packages = with lib;
      with pkgs;
      lib.flatten [
        ungoogled-chromium
        (python3.withPackages (pkgs: with pkgs; [ black mypy bpython ipdb ]))
        amazon-ecr-credential-helper
        atool
        bash-completion
        bashInteractive_5
        bat
        bc
        bzip2
        cachix
        coreutils-full
        cowsay
        curl
        deno
        diffutils
        dos2unix
        ed
        exa
        fd
        file
        figlet
        gawk
        gcc
        gitAndTools.delta
        gnumake
        gnugrep
        gnused
        gnutar
        gron
        gzip
        jq
        less
        libarchive
        libnotify
        lolcat
        loop
        lsof
        man-pages
        moreutils
        nano
        ncdu
        netcat-gnu
        nix-direnv
        nix-bash-completions
        nix-index
        nix-info
        nix-prefetch-github
        nix-prefetch-scripts
        nix-tree
        nixpkgs-fmt
        nmap
        openssh
        p7zip
        patch
        perl
        php
        pigz
        pssh
        procps
        pv
        ranger
        re2c
        ripgrep
        ripgrep-all
        rlwrap
        rnix-lsp
        rsync
        scc
        sd
        shellcheck
        shfmt
        socat
        sox
        swaks
        tealdeer
        time
        unzip
        vim
        watch
        watchexec
        wget
        which
        xxd
        xz
        zip
        binutils

        # chief keef's stuff
        kwbauson-cfg.better-comma
        kwbauson-cfg.nle
        kwbauson-cfg.fordir
        kwbauson-cfg.git-trim

        # jacobi's stuff
        jacobi.hax.meme_sounds
        jacobi.hax.general_bash_scripts
        jacobi.hax.aws_bash_scripts
      ];

    file.sqliterc = {
      target = ".sqliterc";
      text = ''
        .output /dev/null
        .headers on
        .mode column
        .prompt "> " ". "
        .separator ROW "\n"
        .nullvalue NULL
        .output stdout
      '';
    };
  };

  programs.bash = {
    enable = true;
    inherit (config.home) sessionVariables;
    historyFileSize = -1;
    historySize = -1;
    shellAliases = {
      ls = "ls --color=auto";
      l = "exa -alFT -L 1";
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

      # add local scripts to path
      export PATH="$PATH:$HOME/.bin/:$HOME/.local/bin:$HOME/.local/bin/flutter/bin"

      source ~/.nix-profile/etc/profile.d/nix.sh

      # bash completions
      source ~/.nix-profile/etc/profile.d/bash_completion.sh
      source ~/.nix-profile/share/bash-completion/completions/git
      source ~/.nix-profile/share/bash-completion/completions/ssh
    '';
  };

  programs.direnv = {
    enable = true;
  };

  programs.mcfly = {
    enable = true;
    enableBashIntegration = true;
  };

  programs.fzf = {
    enable = true;
    enableBashIntegration = false;
    defaultCommand = "fd -tf -c always -H --ignore-file ${./ignore} -E .git";
    defaultOptions = words "--ansi --reverse --multi --filepath-word";
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      character = rec {
        success_symbol = "[${symbol}](bright-green)";
        error_symbol = "[${symbol}](bright-red)";
      };
      golang = {
        style = "fg:#00ADD8";
        symbol = "go ";
      };
      directory.style = "fg:#d442f5";
      nix_shell = {
        pure_msg = "";
        impure_msg = "";
        format = "via [$symbol$state]($style) ";
      };
      kubernetes = {
        disabled = false;
        style = "fg:#326ce5";
      };

      # disabled plugins
      aws.disabled = true;
      cmd_duration.disabled = true;
      gcloud.disabled = true;
      package.disabled = true;
    };
  };

  programs.tmux = {
    enable = true;
    tmuxp.enable = true;
    historyLimit = 500000;
    shortcut = "j";
    extraConfig = ''
      # ijkl arrow key style pane selection
      bind -n M-j select-pane -L
      bind -n M-i select-pane -U
      bind -n M-k select-pane -D
      bind -n M-l select-pane -R

      # split panes using | and -
      bind | split-window -h
      bind - split-window -v
      unbind '"'
      unbind %

      set-option -g mouse on
    '';
  };

  programs.htop.enable = true;
  programs.dircolors.enable = true;

  programs.git = {
    enable = true;
    package = pkgs.gitAndTools.gitFull;
    userName = "${firstName} ${lastName}";
    userEmail = personalEmail;
    aliases = {
      co = "checkout";
      cam = "commit -am";
      ca = "commit -a";
      cm = "commit -m";
      st = "status";
      br = "branch -v";
      branch-name = "!git rev-parse --abbrev-ref HEAD";
      # Push current branch
      put = "!git push origin $(git branch-name)";
      # Pull without merging
      get = "!git pull origin $(git branch-name) --ff-only";
      # Pull Master without switching branches
      got =
        "!f() { CURRENT_BRANCH=$(git branch-name) && git checkout $1 && git pull origin $1 --ff-only && git checkout $CURRENT_BRANCH;  }; f";
      lol = "log --graph --decorate --pretty=oneline --abbrev-commit";
      lola = "log --graph --decorate --pretty=oneline --abbrev-commit --all";

      # delete local branch and pull from remote
      fetchout =
        "!f() { git co main; git branch -D $@; git fetch && git co $@; }; f";
      pufl = "!git push origin $(git branch-name) --force-with-lease";
      putf = "put --force-with-lease";
      shake = "remote prune origin";
    };
    extraConfig = {
      color.ui = true;
      push.default = "simple";
      pull.ff = "only";
      core = {
        editor = "nano";
        pager = "delta --dark";
      };
    };
  };


  imports = [
    "${fetchTarball "https://github.com/msteen/nixos-vscode-server/tarball/master"}/modules/vscode-server/home.nix"
  ];
  services.vscode-server.enable = builtins.pathExists "/etc/nixos";
}
