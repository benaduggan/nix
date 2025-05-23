{ pkgs, lib, common, ... }:
let
  inherit (common) isLinux isDarwin kwbauson jacobi isGraphical isMinimal;
  optList = conditional: list: if conditional then list else [ ];

  myPogScripts = import ./pog/index.nix { inherit pkgs; inherit (jacobi.pkgs) pog; };
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
        biome
        myPogScripts.spelltree
        common.agenix
        bashInteractive
        bash-completion
        pnpm-shell-completion
        coreutils-full
        curl
        jnv
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
        nixpkgs-fmt
        nil
        difftastic
        docker-client
        (optList isLinux [
          gnutar
          man-pages
        ])

        (with jacobi; [
          argus
          nixup
          httptap
        ])

        (optList (!isMinimal) [
          (optList (isLinux && isGraphical) [
            parsec-bin
            vlc
            # authy
            firefox
            discord
            spotify
            ungoogled-chromium
          ])

          (optList isLinux [
            binutils
            ncdu
            figlet
          ])

          (optList isDarwin [
            m-cli
            (writeShellScriptBin "open-docker" ''
              open --hide --background -a Docker
            '')
          ])

          esbuild
          amazon-ecr-credential-helper
          atool
          bat
          bc
          biome
          bzip2
          cachix
          codex
          diffutils
          dos2unix
          ed
          fd
          file
          gawk
          google-cloud-sdk
          gnumake
          gnugrep
          gnused
          gron
          gzip
          less
          libarchive
          libnotify
          lolcat
          netcat-gnu
          nix-direnv
          nix-info
          nix-prefetch-github
          nix-prefetch-scripts
          nix-tree
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
          (python3.withPackages (pkgs: with pkgs; [ black mypy ipdb ]))


          # common.devenv

          # # chief keef's stuff
          (with kwbauson; [
            better-comma
            # nle
            fordir
            git-trim
          ])

          # (if isDarwin then [
          #   # jacobi.llama-cpp-latest
          # ] else [ ])

          # jacobi's stuff
          (with jacobi; [
            _dex
            argus
            aws_pog_scripts
            drm
            drmi
            dshell
            ffmpeg_pog_scripts
            general_pog_scripts
            httptap
            nix_pog_scripts
            nixup

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
    nix-direnv.enable = true;
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
  programs.lsd.enable = true;
}
