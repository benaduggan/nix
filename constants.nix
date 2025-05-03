let
  authorizedKeysRec = {
    arden = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMWjeSxvFWsw1nBAPIVY1cGMEcCpPdUIysmy0u4ZVYOK";
    desktop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDAQ6BX5+xivdRw7p5jvXlnbgpVk4xqYazb+bN7tvPrq";
    framework = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJDt0C828UN+hwHBinQUXtOiOBB4apm5bEDK1XUVXVlU";
    lake = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMhq0qLYZCcWbgpRel02St/AxCsx7K9aufhiKXzkG3TM";
    paper = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINkINDS7fVFidAiIRM4AL821sbsJ7nmF9/KV+UuQ1Gtf";
    magicMbp = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIArr/sVKrsd6nlkdsbsn759Tvzwnp5cnwDo70xgNB2bY";
    homeServer = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINVM1Pr/o+daMn1ElHm/A0gCyR6t85ZuP3LRkhIJFiF1";
    springfield = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFulKxPMuKmSevjxb6rhhcxKP1tmbqD6tlS0eXE99JwU";
    wsl = "test";
    # digdugdev is not added here cause it doesn't need to decrypt most of the secrets;
  };

  authorizedKeys = builtins.attrValues authorizedKeysRec;
in
{
  inherit authorizedKeys authorizedKeysRec;

  digdugdevKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMBXiUz//dlW7zcblPxQZqgcmZ5KziuhDnnIbuFmOvOw";

  cacheSubstituters = [
    "https://benaduggan.cachix.org"
    "https://cache.g7c.us"
    "https://kwbauson.cachix.org"
  ];

  trustedPublicKeys = [
    "benaduggan.cachix.org-1:BY2tmi++VqJD6My4kB/dXGfxT7nJqrOtRVNn9UhgrHE="
    "kwbauson.cachix.org-1:a6RuFyeJKSShV8LAUw3Jx8z48luiCU755DkweAAkwX0="
    "cache.g7c.us:dSWpE2B5zK/Fahd7npIQWM4izRnVL+a4LiCAnrjdoFY="
  ];

  magicSubstituters = [
    "https://magic-school-ai.cachix.org"
  ];

  magicTrustedPublicKeys = [
    "magic-school-ai.cachix.org-1:EcAHj+Bu7cr7tnrIXr4W2hiSQMOvswmV/o8Qi9shmFQ="
  ];

}
