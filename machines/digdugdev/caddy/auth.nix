{ lib, ... }:
let
  defaultRoles = [ "vault_users" "desktop" ];

  users = {
    "benaduggan@gmail.com" = [ "vault_users" "authp/admin" "desktop" ];
    "elliemduggan@gmail.com" = defaultRoles;
    "kwbauson@gmail.com" = defaultRoles;
    "godofjava@gmail.com" = defaultRoles;
    "bdugganrn@gmail.com" = defaultRoles;
    "cathirn@gmail.com" = defaultRoles;
    "mjandar@gmail.com" = defaultRoles;
    "ktaduggan@gmail.com" = defaultRoles;
    "kbduggan@gmail.com" = defaultRoles;
    "aduggan077@gmail.com" = defaultRoles;
    "rszemplinski22@gmail.com" = defaultRoles;
    "fisherrjd@gmail.com" = defaultRoles;
  };

  userTransforms = lib.concatStringsSep "\n" (lib.mapAttrsToList
    (email: roles: ''
      transform user {
        match realm google
        match email ${email}
        ${lib.concatMapStringsSep "\n      " (role: "action add role ${role}") roles}
      }
    '')
    users);
in
{
  services.caddy = {
    globalConfig = ''
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
          trust login redirect uri domain suffix digdug.dev path prefix /
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

          ${userTransforms}
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

    virtualHosts."auth.digdug.dev".extraConfig = ''
      authenticate with auth_portal
      encode gzip
      file_server
    '';
  };
}
