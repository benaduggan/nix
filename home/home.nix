{ pkgs, lib, common, ... }:
let
  inherit (common) isLinux isDarwin kwbauson jacobi isGraphical isMinimal;
  optList = conditional: list: if conditional then list else [ ];
in
{
  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  home = {
    inherit (common) stateVersion;
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
        bashInteractive
        bash-completion
        coreutils-full
        curl
        jq
        lsof
        moreutils
        nano
        nix
        q
        tealdeer
        wget
        yq-go
        vim
        gitAndTools.delta

        (optList (!isMinimal) [
          (optList (isLinux && isGraphical) [
            parsec-bin
            vlc
            authy
            firefox
            discord
            spotify
            ungoogled-chromium
          ])

          (optList isLinux [
            binutils
            ncdu
          ])

          (optList isDarwin [
            m-cli
            (writeShellScriptBin "open-docker" ''
              open --hide --background -a Docker
            '')
          ])

          amazon-ecr-credential-helper
          atool
          bat
          bc
          bzip2
          cachix
          cowsay
          deno
          diffutils
          dos2unix
          ed
          exa
          fd
          file
          figlet
          gawk
          google-cloud-sdk
          gnumake
          gnugrep
          gnused
          gnutar
          gron
          gzip
          less
          libarchive
          libnotify
          lolcat
          loop
          man-pages
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
          spacer
          swaks
          time
          unzip
          watch
          watchexec
          which
          xterm
          xxd
          xz
          zip

          common.devenv

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
            ffmpeg_pog_scripts
            drm
            drmi
            dshell
            _dex
            (python3.withPackages (pkgs: with pkgs; [ black mypy ipdb ]))
          ])
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
    enable = !isMinimal;
    # nix-direnv.enable = true;
  };

  programs.mcfly = {
    enable = !isMinimal;
    enableBashIntegration = !isMinimal;
  };

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
