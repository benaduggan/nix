let
  authorizedKeysRec = {
    desktop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDAQ6BX5+xivdRw7p5jvXlnbgpVk4xqYazb+bN7tvPrq";
    framework = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJDt0C828UN+hwHBinQUXtOiOBB4apm5bEDK1XUVXVlU";
    lake = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMhq0qLYZCcWbgpRel02St/AxCsx7K9aufhiKXzkG3TM";
    homeServer = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPBYRwtinqAt7J+VxULNTqWewFjG5P+ah1Sc8IvRqtnw";
    paper = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINkINDS7fVFidAiIRM4AL821sbsJ7nmF9/KV+UuQ1Gtf";
    magicMbp = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIArr/sVKrsd6nlkdsbsn759Tvzwnp5cnwDo70xgNB2bY";
    digdugdev = "omit-for-security";
  };

  authorizedKeys = builtins.attrValues authorizedKeysRec;
in
{
  inherit authorizedKeys authorizedKeysRec;

  digdugdevKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMBXiUz//dlW7zcblPxQZqgcmZ5KziuhDnnIbuFmOvOw";

  cacheSubstituters = [
    "https://cache.nixos.org/"
    "https://benaduggan.cachix.org"
    "https://devenv.cachix.org"
    "https://jacobi.cachix.org"
    "https://kwbauson.cachix.org"
  ];

  trustedPublicKeys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "benaduggan.cachix.org-1:BY2tmi++VqJD6My4kB/dXGfxT7nJqrOtRVNn9UhgrHE="
    "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
    "jacobi.cachix.org-1:JJghCz+ZD2hc9BHO94myjCzf4wS3DeBLKHOz3jCukMU="
    "kwbauson.cachix.org-1:a6RuFyeJKSShV8LAUw3Jx8z48luiCU755DkweAAkwX0="
  ];
}
