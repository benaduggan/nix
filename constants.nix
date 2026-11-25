let
  authorizedKeysRec = {
    arden = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMWjeSxvFWsw1nBAPIVY1cGMEcCpPdUIysmy0u4ZVYOK";
    desktop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDAQ6BX5+xivdRw7p5jvXlnbgpVk4xqYazb+bN7tvPrq";
    framework = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJDt0C828UN+hwHBinQUXtOiOBB4apm5bEDK1XUVXVlU";
    lake = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMhq0qLYZCcWbgpRel02St/AxCsx7K9aufhiKXzkG3TM";
    paper = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINkINDS7fVFidAiIRM4AL821sbsJ7nmF9/KV+UuQ1Gtf";
    magicMbp = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINnka7McfWZS/nPAXqvZN2mRtHab9+hVo3bWUMGsXQXe";
    homeServer = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINVM1Pr/o+daMn1ElHm/A0gCyR6t85ZuP3LRkhIJFiF1";
    beast = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOoAXeYNb3LC5nyu3yfheXHH/jvxCbKH7V7UVhdGKosk";
    # digdugdev is not added here cause it doesn't need to decrypt most of the secrets;
  };

  authorizedKeys = builtins.attrValues authorizedKeysRec;

  tailscaleIp = {
    homeServer = "100.89.0.69";
    arden = "100.105.21.57";
    desktop = "100.108.141.38";
    framework = "100.75.49.80";
    beast = "100.82.226.111";
    paper = "100.100.101.100";
    magicMbp = "100.84.51.19";
    digdugdev = "100.113.75.95";
  };

  homeServerVaultwardenArchiveDir = "/etc/vault/backups";
  desktopVaultwardenArchiveDir = "/home/bduggan/standby-vault-backups";
  ardenVaultwardenArchiveDir = "/home/bduggan/vault-backups";
  frameworkVaultwardenArchiveDir = "/home/bduggan/vault-backups";
in
{
  inherit authorizedKeys authorizedKeysRec tailscaleIp;
  inherit homeServerVaultwardenArchiveDir desktopVaultwardenArchiveDir ardenVaultwardenArchiveDir frameworkVaultwardenArchiveDir;

  digdugdevKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMBXiUz//dlW7zcblPxQZqgcmZ5KziuhDnnIbuFmOvOw";

  harmoniaUpstreams = [
    {
      url = "http://${tailscaleIp.homeServer}:5000";
      public_key = "home-server-cache-1:7YC6SEsTfQDD97tsYURuFIBDORxnfO0bcbt52V7olzE=";
      priority = 5;
    }
  ];

  cacheUpstreams = [
    {
      url = "https://cache.nixos.org";
      public_key = "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=";
      priority = 10;
    }
    {
      url = "https://benaduggan.cachix.org";
      public_key = "benaduggan.cachix.org-1:BY2tmi++VqJD6My4kB/dXGfxT7nJqrOtRVNn9UhgrHE=";
      priority = 20;
    }
    {
      url = "https://cache.g7c.us";
      public_key = "cache.g7c.us:dSWpE2B5zK/Fahd7npIQWM4izRnVL+a4LiCAnrjdoFY=";
      priority = 30;
    }
    {
      url = "https://kwbauson.cachix.org";
      public_key = "kwbauson.cachix.org-1:a6RuFyeJKSShV8LAUw3Jx8z48luiCU755DkweAAkwX0=";
      priority = 40;
    }
  ];

  communityUpstreams = [
    {
      url = "https://nix-community.cachix.org";
      public_key = "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=";
      priority = 25;
    }
  ];
}
