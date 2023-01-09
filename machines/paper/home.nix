{ config, pkgs, lib, inputs, ... }:
let
  inherit (pkgs.stdenv) isLinux isDarwin;
  personalEmail = "benaduggan@gmail.com";
  workEmail = "benduggan@readlee.com";
  firstName = "Ben";
  lastName = "Duggan";
  home = builtins.getEnv "HOME";
  username = builtins.getEnv "USER";
  symbol = "ᛥ";

  # # chief keefs stuff
  # kwbauson-cfg = import <kwbauson-cfg>;
  kwbauson = import inputs.nixpkgs { inherit (inputs.kwbauson) overlays; inherit (pkgs) system; };

  # # jacobi's stuff
  jacobi = import inputs.jacobi { inherit (inputs) nixpkgs; inherit (pkgs) system; };
in
with jacobi.hax; {
  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  home = {
    stateVersion = "22.11";

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
        (if isLinux then [ ungoogled-chromium binutils ncdu ] else [ ])
        (if isDarwin then [ m-cli ] else [ ])
        (python3.withPackages (pkgs: with pkgs; [ black mypy ipdb ]))
        amazon-ecr-credential-helper
        atool
        bash-completion
        bashInteractive
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
        netcat-gnu
        nil
        nix-direnv
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
        rsync
        scc
        screen
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
        xterm
        xxd
        xz
        zip

        # # chief keef's stuff
        (with kwbauson; [
          better-comma
          nle
          fordir
          git-trim
        ])

        # jacobi's stuff
        (with jacobi; [
          devenv
          meme_sounds
          general_pog_scripts
          aws_pog_scripts
          nix_pog_scripts
          docker_pog_scripts
        ])
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
      export LC_ALL=en_US.UTF-8
      export LANG=en_US.UTF-8

      # add local scripts to path
      export PATH="$PATH:$HOME/.bin/:$HOME/.local/bin"
    '';
  };

  programs.direnv = {
    enable = true;
    # nix-direnv.enable = true;
  };

  # programs.mcfly = {
  #   enable = true;
  #   enableBashIntegration = true;
  # };

  # had to disable to build flake
  # programs.fzf = {
  #   enable = true;
  #   enableBashIntegration = false;
  #   defaultCommand = "fd -tf -c always -H --ignore-file ${./ignore} -E .git";
  #   defaultOptions = words "--ansi --reverse --multi --filepath-word";
  # };

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
      set -g default-terminal "xterm-256color"
      set-window-option -q -g utf8 on
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


  # imports = [
  #   "${fetchTarball "https://github.com/msteen/nixos-vscode-server/tarball/master"}/modules/vscode-server/home.nix"
  # ];
  # services.vscode-server.enable = builtins.pathExists "/etc/nixos";
}
