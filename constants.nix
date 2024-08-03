let
  authorizedKeysRec = {
    desktop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDAQ6BX5+xivdRw7p5jvXlnbgpVk4xqYazb+bN7tvPrq";
    framework = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJDt0C828UN+hwHBinQUXtOiOBB4apm5bEDK1XUVXVlU";
    lake = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMhq0qLYZCcWbgpRel02St/AxCsx7K9aufhiKXzkG3TM";
    paper = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINkINDS7fVFidAiIRM4AL821sbsJ7nmF9/KV+UuQ1Gtf";
    magicMbp = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIArr/sVKrsd6nlkdsbsn759Tvzwnp5cnwDo70xgNB2bY";
    digdugdev = "omit-for-security";
    homeServer = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINVM1Pr/o+daMn1ElHm/A0gCyR6t85ZuP3LRkhIJFiF1";
  };

  authorizedKeys = builtins.attrValues authorizedKeysRec;
in
{
  inherit authorizedKeys authorizedKeysRec;

  digdugdevKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMBXiUz//dlW7zcblPxQZqgcmZ5KziuhDnnIbuFmOvOw";

  cacheSubstituters = [
    "https://benaduggan.cachix.org"
    "https://jacobi.cachix.org"
    "https://kwbauson.cachix.org"
  ];

  trustedPublicKeys = [
    "benaduggan.cachix.org-1:BY2tmi++VqJD6My4kB/dXGfxT7nJqrOtRVNn9UhgrHE="
    "jacobi.cachix.org-1:JJghCz+ZD2hc9BHO94myjCzf4wS3DeBLKHOz3jCukMU="
    "kwbauson.cachix.org-1:a6RuFyeJKSShV8LAUw3Jx8z48luiCU755DkweAAkwX0="
  ];
}
