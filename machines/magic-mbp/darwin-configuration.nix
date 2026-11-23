{ common, pkgs, ... }:
{
  users.users."${common.username}" = {
    name = common.username;
    shell = pkgs.bashInteractive;
    home = "/Users/${common.username}";
    openssh.authorizedKeys.keys = common.authorizedKeys;
    packages = [
      common.jacobiLegacy.pkgs.llama-cpp-latest
    ];
  };

  ids.gids.nixbld = 350;
  system.primaryUser = common.username;

  services.llama-server =
    let
      package = common.jacobiLegacy.pkgs.llama-cpp-latest;
    in
    {
      servers = {
        qwen-38-27b = {
          inherit package;
          enable = true;
          port = 8017;
          model = "/opt/box/models/qwen3.8-27B-UD-Q4_K_XL.gguf";
          ngl = 99;
          extraFlags = "--jinja --flash-attn on --ctx-size 32768 --parallel 1 --ctx-checkpoints 32 --checkpoint-min-step 0 --cache-type-k q8_0 --cache-type-v q8_0 --spec-type draft-mtp --spec-draft-n-max 3 --reasoning-effort medium --temp 1.0 --top-p 0.95 --top-k 20 --min-p 0.0 --presence-penalty 0.0 --repeat-penalty 1.0";
        };
      };
    };
}
