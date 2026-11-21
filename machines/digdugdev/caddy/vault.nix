let
  failoverProxy = ''
    reverse_proxy home-server-1:8000 bduggan-desktop:8222 arden:8222 {
      lb_policy first
      fail_duration 30s
      max_fails 1
      lb_try_duration 5s
      lb_try_interval 250ms
      health_uri /alive
      health_interval 10s
      health_timeout 3s
    }
  '';
in
{
  services.caddy.virtualHosts."vault.digdug.dev".extraConfig = ''
    # Standbys serve reads and the minimum POST endpoints required to
    # authenticate. All other non-read requests stay pinned to the
    # primary so a standby can never acknowledge a vault mutation that
    # would be lost during restore or failback.
    @vaultFailoverRead {
      method GET HEAD OPTIONS
    }

    @vaultFailoverLogin {
      method POST
      path /identity/connect/token /identity/accounts/prelogin /identity/accounts/prelogin/password /api/accounts/prelogin /api/two-factor/send-email-login
    }

    handle @vaultFailoverRead {
      ${failoverProxy}
    }

    handle @vaultFailoverLogin {
      ${failoverProxy}
    }

    handle {
      reverse_proxy home-server-1:8000 {
        fail_duration 30s
        max_fails 1
        health_uri /alive
        health_interval 10s
        health_timeout 3s
        transport http {
          dial_timeout 3s
        }
      }
    }

    handle_errors {
      header Content-Type application/json
      respond `{ "message": "Vaultwarden is currently read-only because the primary server is unavailable. Your changes were not saved.", "error": "vaultwarden_read_only_failover", "error_description": "Vaultwarden is currently read-only because the primary server is unavailable. Your changes were not saved.", "object": "error" }` 503
    }
  '';
}
