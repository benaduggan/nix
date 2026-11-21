# Sandboxed Hermes Agent ("pooka") + Hermes WebUI on home-server.
#
# Uses jpetrucciani/nix's multi-instance rootless Podman module
# (hosts/modules/servers/hermes-agent.nix) so `pooka` runs in an isolated,
# read-only-root Podman container with its own host UID/GID, declarative Nix
# tools baked into PATH, and `enableNix = true` so it can install ad-hoc tools
# via `nix profile add`, `nix-shell -p`, `uv`, or `bun` at runtime without
# touching the host OS.
#
# Manage the running sandbox from the host with `hermes_podman`:
#   hermes_podman pooka shell
#   hermes_podman pooka logs -f hermes-agent-pooka
#   hermes_podman pooka exec -it hermes-agent-pooka hermes chat
{ common, inputs, ... }:
let
  inherit (common) tailnetIp;
  pookaUid = 32001;
in
{
  imports = [
    "${inputs.jacobi}/hosts/modules/servers/hermes-agent.nix"
    ./pooka.nix
    ./webhooks.nix
    ./webui.nix
  ];

  _module.args.hermesCfg = {
    inherit tailnetIp pookaUid;
  };

  # Expose `hermes-agent` and `pog` from inputs.jacobi for hermes-agent.nix.
  nixpkgs.overlays = [
    (_final: _prev: {
      inherit (common.jacobiLegacy.pkgs) hermes-agent pog;
    })
  ];

  # Pin the hermes-pooka group GID to match pookaUid so hermes-webui can run
  # with the exact same UID/GID and share /var/lib/hermes-agent/pooka/hermes.
  users.groups.hermes-pooka.gid = pookaUid;

  age.secrets = {
    hermesWebui = {
      file = ../../../secrets/hermes-webui.age;
      mode = "400";
      owner = "root";
      group = "root";
    };
    hermesPooka = {
      file = ../../../secrets/hermes-pooka.age;
      mode = "0400";
      owner = "hermes-pooka";
      group = "hermes-pooka";
    };
  };
}
