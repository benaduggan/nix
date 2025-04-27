{ common, config, pkgs, modulesPath, lib, ... }:
{
  imports = lib.optional (builtins.pathExists ./do-userdata.nix) ./do-userdata.nix ++ [
    (modulesPath + "/virtualisation/digital-ocean-config.nix")
  ];

  nix = {
    extraOptions = ''
      max-jobs = auto
      extra-experimental-features = nix-command flakes
    '';

    settings.substituters = common.cacheSubstituters;
    settings.trusted-public-keys = common.trustedPublicKeys;
    settings.experimental-features = [ "nix-command" "flakes" ];
  };
  programs.nix-ld.enable = true;

  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  age = {
    identityPaths = [ "/home/bduggan/.ssh/id_ed25519" ];
    secrets = {
      board.file = ../../secrets/board.age;
      caddy = {
        file = ../../secrets/caddy.age;
        path = "/etc/default/caddy";
        owner = "root";
        group = "root";
        mode = "644";
      };
    };
  };

  environment.systemPackages = with pkgs; [
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
    wget
    yq-go
  ];

  users.extraUsers.bduggan = {
    createHome = true;
    isNormalUser = true;
    home = "/home/bduggan";
    description = "bduggan";
    group = "users";
    extraGroups = [ "wheel" ];
    useDefaultShell = true;
    openssh.authorizedKeys.keys = common.authorizedKeys;
  };

  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  security.sudo.wheelNeedsPassword = false;
  zramSwap = {
    enable = true;
    memoryPercent = 100;
  };
  services = {
    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "prohibit-password";
        PasswordAuthentication = false;
        KexAlgorithms = [
          "curve25519-sha256"
          "curve25519-sha256@libssh.org"
        ];
        Ciphers = [
          "chacha20-poly1305@openssh.com"
          "aes256-gcm@openssh.com"
          "aes256-ctr"
        ];
        Macs = [
          "hmac-sha2-512-etm@openssh.com"
          "hmac-sha2-256-etm@openssh.com"
          "umac-128-etm@openssh.com"
        ];
        X11Forwarding = true;
      };
    };
    tailscale.enable = true;
  };

  system.stateVersion = common.stateVersion;
  programs.command-not-found.enable = false;

  services.caddy =
    let
      transformUser = email: extraConfig: ''
        transform user {
          match realm google
          match email ${email}
          ${extraConfig}
        }
      '';

      vaultRole = "action add role vault_users\n";
      adminRole = "action add role authp/admin\n";
      desktopRole = "action add role desktop\n";
      buildUser = email: roles: transformUser email (lib.concatStrings roles);

      ben = buildUser "benaduggan@gmail.com" [ vaultRole adminRole desktopRole ];
      brian = buildUser "bdugganrn@gmail.com" [ vaultRole desktopRole ];
      cathi = buildUser "cathirn@gmail.com" [ vaultRole desktopRole ];
      keri = buildUser "kbduggan@gmail.com" [ vaultRole desktopRole ];
      matt = buildUser "mjandar@gmail.com" [ vaultRole desktopRole ];
      kristy = buildUser "ktaduggan@gmail.com" [ vaultRole desktopRole ];
      anna = buildUser "aduggan077@gmail.com" [ vaultRole desktopRole ];
      cobi = buildUser "godofjava@gmail.com" [ vaultRole desktopRole ];
      kevin = buildUser "kwbauson@gmail.com" [ vaultRole desktopRole ];
      ellie = buildUser "elliemduggan@gmail.com" [ vaultRole desktopRole ];
      aly = buildUser "spiffai@gmail.com" [ vaultRole desktopRole ];
      # jade = buildUser "fisherrjd@gmail.com" [ vaultRole desktopRole ];
      ryguy = buildUser "rszemplinski22@gmail.com" [ vaultRole desktopRole ];
    in
    {
      enable = true;
      inherit (common) email;
      package = common.jacobi.zaddy;
      globalConfig = ''
        order authenticate before respond
        order authorize before basicauth

        security {
          oauth identity provider google {
            realm google
            driver google
            client_id {env.GOOGLE_CLIENT_ID}.apps.googleusercontent.com
            client_secret {env.GOOGLE_CLIENT_SECRET}
            scopes openid email profile
          }

          authentication portal auth_portal {
            crypto default token lifetime 3600
            crypto key sign-verify {env.JWT_SHARED_KEY}
            enable identity provider google
            cookie domain digdug.dev
            ui {
              links {
                "My Identity" "/whoami" icon "las la-user"
                "Vault" "https://vault.digdug.dev" icon "las la-shield-alt"
              }
            }

            transform user {
              match realm google
              action add role authp/user
            }

            ${ben}
            ${ellie}
            ${kevin}
            ${cobi}
            ${brian}
            ${cathi}
            ${matt}
            ${kristy}
            ${keri}
            ${anna}
            ${ryguy}
            ${aly}

          }

          authorization policy google_auth {
            set auth url https://auth.digdug.dev/oauth2/google
            crypto key verify {env.JWT_SHARED_KEY}
            allow roles vault_users
            validate bearer header
            inject headers with claims
          }
        }
      '';
      virtualHosts = {
        # Push Notifications
        "ntfy.digdug.dev".extraConfig = ''
          reverse_proxy * {
            to home-server-1:9090
          }
        '';

        # LLM stuff
        "n8n.digdug.dev".extraConfig = ''
          reverse_proxy * {
            to home-server-1:5678
          }
        '';
        "litellm.digdug.dev".extraConfig = ''
          reverse_proxy /* {
            to home-server-1:4000
          }
        '';
        "chat.digdug.dev".extraConfig = ''
          reverse_proxy /* {
            to home-server-1:8080
          }
        '';
        "ai.digdug.dev".extraConfig = ''
          authorize with google_auth

          reverse_proxy /* {
            to desktop-5su64sl:9090
          }
        '';

        # Content Hosting
        "audio.digdug.dev".extraConfig = ''
          reverse_proxy /* {
            to bduggan-desktop:8000
          }
        '';

        "sink.digdug.dev".extraConfig = ''
          reverse_proxy /* {
            to localhost:8080
          }
        '';
        "books.digdug.dev".extraConfig = ''
          reverse_proxy /* {
            to bduggan-desktop:8083
          }
        '';
        "assets.digdug.dev".extraConfig = ''
          root * /var/www/tldr
          file_server
        '';

        # Home Assistants
        "arden.ha.digdug.dev".extraConfig = ''
          reverse_proxy /* {
            to arden:8123
          }
        '';
        "springfield.ha.digdug.dev".extraConfig = ''
          reverse_proxy /* {
            to springfield:8123
          }
        '';
        "lake.ha.digdug.dev".extraConfig = ''
          reverse_proxy /* {
            to bduggan-desktop:8123
          }
        '';
        "fishers.ha.digdug.dev".extraConfig = ''
          reverse_proxy /* {
            to home-server-1:8123
          }
        '';


        # Misc
        "vault.digdug.dev".extraConfig = ''
          reverse_proxy /* {
            to home-server-1:8000
          }

          reverse_proxy /notifications/hub {
            to home-server-1:3012
          }
        '';
        "grafana.digdug.dev".extraConfig = ''
          authorize with google_auth

          reverse_proxy /* {
            to home-server-1:2342
          }
        '';
        "greenhouse.digdug.dev".extraConfig = ''
          authorize with google_auth

          reverse_proxy /* {
            to home-server-1:7000
          }
        '';
        "auth.digdug.dev".extraConfig = ''
          authenticate with auth_portal
          encode gzip
          file_server
        '';
        # "garden.digdug.dev".extraConfig = ''
        #   authorize with google_auth

        #   reverse_proxy /* {
        #     to nexus-6:8080
        #   }
        # '';

        "http://board.digdug.dev".extraConfig = ''
          header {
            Cache-Control "no-cache, no-store, must-revalidate"
          }
          root * /var/www
          file_server
        '';
        "sec-board.digdug.dev".extraConfig = ''
          authorize with google_auth

          header {
            Cache-Control "no-cache, no-store, must-revalidate"
          }
          root * /var/www
          file_server
        '';
      };
    };

  systemd.timers.update-quotes = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "4m";
      OnUnitActiveSec = "4m";
      Unit = "update-quotes.service";
    };
  };

  systemd.services = {
    update-quotes = {
      path = [ pkgs.jq pkgs.gawk pkgs.gnused pkgs.curlMinimal ];
      script = ''
        HTML_OUTPUT_PATH=/var/www/index.html
        QOUTES_PATH=/var/www/quotes.txt

        # get the google sheet url from agenix secret
        export $(${pkgs.gnugrep}/bin/grep -v '^#' ${config.age.secrets.board.path} | xargs)


        # Fetch the latest quotes from google drive
        curl -L $GOOGLE_PUBLIC_URL -o $QOUTES_PATH

        RANDOM_LINE=$(shuf -n 1 "$QOUTES_PATH")
        NAME=$(echo $RANDOM_LINE | awk '{print $1}')
        QUOTE=$(echo $RANDOM_LINE | awk '{$1=""; print $0}' | sed 's/^[ \t]*//')
        RANDOM_PHOTO_INDEX=$(( RANDOM % 11 + 1 ))
        IMG_PATH="imgs/$NAME/$NAME$RANDOM_PHOTO_INDEX.png"

        cat > $HTML_OUTPUT_PATH << EOF
        <!DOCTYPE html>
        <html lang="en">
          <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <meta http-equiv="X-UA-Compatible" content="ie=edge">
            <title>Quote Board</title>
            <style>
            * {
              margin: 0;
            }

            body {
              margin: 0;
              max-width: 600px;
              max-height: 800px;
              width: 600px;
              height: 800px;
            }

            .quote-text {
              margin: 0 auto;
              display: block;
              font-size: 24px;
              font-weight: bold;
              max-width: 80%;
              padding: 20px;
              text-align: center;
            }

            .profile {
              width: 100%;
              max-width: 600px;
              height: auto;
            }
            </style>
          </head>
          <body>
            <img class="profile" src="$IMG_PATH" />
            <p class="quote-text">$QUOTE</p>
          </body>
        </html>
        EOF
      '';
      serviceConfig = {
        User = "root";
        Type = "oneshot";
      };
    };
  };

}

