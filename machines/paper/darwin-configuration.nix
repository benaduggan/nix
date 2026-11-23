{ common, ... }:
{
  users.users.benduggan = {
    name = "benduggan";
    home = "/Users/benduggan";
    openssh.authorizedKeys.keys = common.authorizedKeys;
  };

  ids.gids.nixbld = 30000;
  system.primaryUser = "benduggan";

}

