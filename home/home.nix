{ config, pkgs, lib, inputs, common, ... }:
let
  inherit (common) isLinux isDarwin kwbauson jacobi isGraphical;
in
{
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
        (if isLinux && isGraphical then [ parsec-bin vlc authy firefox discord spotify ] else [ ])
        (if isLinux then [ ungoogled-chromium binutils ncdu ] else [ ])
        (if isDarwin then [
          m-cli
          (writeShellScriptBin "open-docker" ''
            open --hide --background -a Docker
          '')
        ] else [ ])
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
        inputs.devenv.packages.${system}.devenv
        diffutils
        dos2unix
        ed
        exa
        fd
        file
        figlet
        gawk
        google-cloud-sdk
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
        nodejs
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
          (if isDarwin then [
            alpaca-cpp
            llama-cpp
            whisper-cpp
          ] else [ ])

          meme_sounds
          general_pog_scripts
          aws_pog_scripts
          nix_pog_scripts
          docker_pog_scripts
          (python3.withPackages (pkgs: with pkgs; [ black mypy ipdb ]))
          # (python3.withPackages (pkgs: with pkgs; [ black mypy ipdb slack-bolt ]))
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

  programs.direnv = {
    enable = true;
    # nix-direnv.enable = true;
  };

  programs.mcfly = {
    enable = true;
    enableBashIntegration = true;
  };

  # had to disable to build flake
  programs.fzf = {
    enable = true;
    enableBashIntegration = false;
    defaultCommand = "fd -tf -c always -H --ignore-file ${./ignore} -E .git";
    defaultOptions = common.jacobi.hax.words "--ansi --reverse --multi --filepath-word";
  };
  programs.vscode.enable = isGraphical && !isDarwin;
  programs.htop.enable = true;
  programs.dircolors.enable = true;
}
