{ config, pkgs, lib, ... }:
let
  inherit (pkgs.hax) isDarwin isLinux fetchFromGitHub;

  personalEmail = "benaduggan@gmail.com";
  workEmail = "benduggan@readlee.com";
  firstName = "Ben";
  lastName = "Duggan";
  home = (builtins.getEnv "HOME");
  username = (builtins.getEnv "USER");
  symbol = if isDarwin then "ᛗ" else "ᛥ";

  # chief keefs stuff
  kwbauson-cfg = import <kwbauson-cfg>;

  coinSound = pkgs.fetchurl {
    url = "https://hexa.dev/static/sounds/coin.wav";
    sha256 = "18c7dfhkaz9ybp3m52n1is9nmmkq18b1i82g6vgzy7cbr2y07h93";
  };
  guhSound = pkgs.fetchurl {
    url = "https://hexa.dev/static/sounds/guh.wav";
    sha256 = "1chr6fagj6sgwqphrgbg1bpmyfmcd94p39d34imq5n9ik674z9sa";
  };
  bruhSound = pkgs.fetchurl {
    url = "https://hexa.dev/static/sounds/bruh.mp3";
    sha256 = "11n1a20a7fj80xgynfwiq3jaq1bhmpsdxyzbnmnvlsqfnsa30vy3";
  };

in
with pkgs.hax; {
  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  home = {
    username = username;
    homeDirectory = home;

    stateVersion = "21.11";

    sessionVariables = {
      EDITOR = "vim";
      HISTCONTROL = "ignoreboth";
      PAGER = "less";
      LESS = "-iR";
      BASH_SILENCE_DEPRECATION_WARNING = "1";
    };

    packages = with lib;
      with pkgs;
      lib.flatten [
        (lib.optional stdenv.isLinux ungoogled-chromium)
        (python3.withPackages (pkgs: with pkgs; [ black mypy bpython ipdb ]))
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
        kwbauson-cfg.better-comma
        kwbauson-cfg.nle
        kwbauson-cfg.fordir
        kwbauson-cfg.git-trim
        (lib.optional isLinux [ binutils ])
        (writeShellScriptBin "hms" ''
          git -C ~/.config/nixpkgs/ pull origin main
          home-manager switch
        '')
        (soundScript "coin" coinSound)
        (soundScript "guh" guhSound)
        (soundScript "bruh" bruhSound)
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

      # docker
      d = "docker";
      da = "docker ps -a";
      di = "docker images";
      de = "docker exec -it";
      dr = "docker run --rm -it";
      daq = "docker ps -aq";
      drma = "docker stop $(docker ps -aq) && docker rm -f $(docker ps -aq)";
      drmi = "di | grep none | awk '{print $3}' | sponge | xargs docker rmi";
      dc = "docker-compose";

      # k8s
      k = "kubectl";
      kx = "kubectx";
      ka = "k get pods";
      kaw = "k get pods -o wide";
      knuke = "k delete pods --grace-period=0 --force";
      klist =
        "k get pods --all-namespaces -o jsonpath='{..image}' | tr -s '[[:space:]]' '\\n' | sort | uniq -c";

      # aws stuff
      aws_id = "aws sts get-caller-identity --query Account --output text";

      # misc
      rot13 = "tr 'A-Za-z' 'N-ZA-Mn-za-m'";
      space = "du -Sh | sort -rh | head -10";
      now = "date +%s";

      #nix
      nixc = "cd ~/.config/nixpkgs";

      fzfp = "fzf --preview 'bat --style=numbers --color=always {}'";
    };

    initExtra = ''
      shopt -s histappend
      set +h

      export DO_NOT_TRACK=1

      export MONOREPO_DIR="$HOME/mimir"

      # add local scripts to path
      export PATH="$PATH:$HOME/.bin/:$HOME/.local/bin:$HOME/.local/bin/flutter/bin"

      # asdf and base nix
    '' + (if isDarwin then ''
      # source /usr/local/opt/asdf/asdf.sh
      # source /usr/local/opt/asdf/etc/bash_completion.d/asdf.bash
    '' else ''
      # source $HOME/.asdf/asdf.sh
      # source $HOME/.asdf/completions/asdf.bash
    '') + ''
      source ~/.nix-profile/etc/profile.d/nix.sh

      # bash completions
      source ~/.nix-profile/etc/profile.d/bash_completion.sh
      source ~/.nix-profile/share/bash-completion/completions/git
      source ~/.nix-profile/share/bash-completion/completions/ssh
    '';
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
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

  programs.starship.enable = true;
  programs.starship.settings = {
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
        editor = if isDarwin then "code --wait" else "vim";
        pager = "delta --dark";
      };
    };
  };
}
