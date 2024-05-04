let
  constants = import ../constants.nix;
in
{
  # home server
  "grafana.age".publicKeys = constants.authorizedKeys;
  "vaultwarden.age".publicKeys = constants.authorizedKeys;
  "ondeck-vars.age".publicKeys = constants.authorizedKeys;
  "home-magic-runner.age".publicKeys = constants.authorizedKeys;
  "home-self-runner.age".publicKeys = constants.authorizedKeys;

  # digdugdev
  "board.age".publicKeys = constants.authorizedKeys ++ [ constants.digdugdevKey ];
  "caddy.age".publicKeys = constants.authorizedKeys ++ [ constants.digdugdevKey ];
}
