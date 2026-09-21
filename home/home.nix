{ pkgs, lib, common, ... }:
let
  inherit (common) isLinux isDarwin kwbauson jacobiPackages jacobiLegacy isGraphical isMinimal;
  optList = conditional: list: if conditional then list else [ ];

  # myPogScripts = import ./pog/index.nix { inherit pkgs; inherit (jacobiLegacy.pkgs) pog; };
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
        # myPogScripts.spelltree
        common.agenix
        bashInteractive
        bash-completion
        coreutils-full
        curl
        jnv
        jq
        lsof
        moreutils
        nano
        nix
        tealdeer
        wget
        rrsync
        yq-go
        vim
        delta
        nixpkgs-fmt
        nil
        difftastic
        docker-client
        httptap
        (writeShellApplication {
          name = "git-clean-merged";
          runtimeInputs = [ git ];
          text = builtins.readFile ./scripts/git-clean-merged.sh;
        })
        (optList isLinux [
          gnutar
          man-pages
        ])

        (with jacobiLegacy; [
          jacobiPackages.argus-rs
          nixup
        ])

        (optList (!isMinimal) [
          (optList (isLinux && isGraphical) [
            vlc
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
          claude-code
          codex
          amazon-ecr-credential-helper
          atool
          bat
          bun
          bzip2
          cachix
          diffutils
          dos2unix
          file
          gawk
          gnumake
          gnugrep
          gnused
          gron
          gzip
          less
          libnotify
          lolcat
          netcat-gnu
          nix-direnv
          nix-info
          nix-prefetch-github
          nix-prefetch-scripts
          nix-tree
          nmap
          openssh
          p7zip
          patch
          procps
          pv
          ranger
          re2c
          ripgrep
          rlwrap
          rsync
          scc
          sd
          shellcheck
          shfmt
          socat
          sox
          spacer
          time
          unzip
          watch
          watchexec
          which
          xterm
          xz
          zip
          python3

          # # chief keef's stuff
          (with kwbauson; [
            better-comma
            fordir
            git-trim
          ])

          # (if isDarwin then [
          #   # jacobiLegacy.llama-cpp-latest
          # ] else [ ])

          # jacobi's stuff
          (with jacobiLegacy; [
            _dex
            drm
            drmi
            dshell

            crop_video
            cut_video
            faxify
            flip
            scale
            to_mp3

            batwhich
            get_cert
            jql
            jqf
            json_envvars
            jwtdecode
            slack_meme
            fif
            rot13
            sin
            srv
            sqlfmt
            whatip
            whereami
            portwatch
            pdfcat

            hex
            hexcast
            nixrender
            ndiff
            overlay-check
            overlay-diff
            nixsum
            nixcache
            nupdate
            nupdate_latest_github
            generate_sglang_omni_lock
            generate_uv_lock
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
    defaultOptions = common.jacobiLegacy.hax.words "--ansi --reverse --multi --filepath-word";
  };
  programs.vscode.enable = isGraphical && !isDarwin;
  programs.htop.enable = true;
  programs.dircolors.enable = true;
  programs.lsd.enable = true;
}
