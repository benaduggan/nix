{ common, pkgs, modulesPath, lib, ... }:
{
  imports = lib.optional (builtins.pathExists ./do-userdata.nix) ./do-userdata.nix ++ [
    (modulesPath + "/virtualisation/digital-ocean-config.nix")
  ];

  nix = {
    extraOptions = ''
      max-jobs = auto
      extra-experimental-features = nix-command flakes
    '';
  };
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
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

  system.stateVersion = "23.05";
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
    kevin = buildUser "godofjava@gmail.com" [ vaultRole desktopRole ];
    ellie = buildUser "elliemduggan@gmail.com" [ vaultRole desktopRole ];
  in
    {
      enable = true;
      email = common.email;
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
        # "digdug.dev/blog" = reverse_proxy "home-server:9000";
        "ai.digdug.dev".extraConfig = ''
            authorize with google_auth

            reverse_proxy /* {
              to wsl:9090
            }
        '';

	      "vault.digdug.dev".extraConfig = ''
            reverse_proxy /* {
              to home-server:8000
            }

            reverse_proxy /notifications/hub {
              to home-server:3012
            }
        '';
	      "auth.digdug.dev".extraConfig = ''
            authenticate with auth_portal
            encode gzip
            file_server
        '';

        "digdug.dev".extraConfig = ''
          encode gzip
          file_server
          root * ${
            pkgs.runCommand "testdir" {} ''
              mkdir "$out"
              echo hello world > "$out/example.html"
            ''
          }
        '';
      };
    };
}

