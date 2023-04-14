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
      ts_reverse_proxy = location: {
        extraConfig = ''
          import TAILSCALE
          reverse_proxy /* {
            to ${location}
          }
        '';
      };
      reverse_proxy = location: {
        extraConfig = ''
          import GEOBLOCK
          import SECURITY
          reverse_proxy /* {
            to ${location}
          }
        '';
      };
    in
    {
      enable = true;
      email = "benaduggan@gmail.com";
      package = common.jacobi.zaddy;
      virtualHosts = {
        "blog.digdug.dev" =
          common.jacobi.zaddy.ts_reverse_proxy "home-server:1313/ben";

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
