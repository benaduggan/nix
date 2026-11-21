{ lib, ... }:
{
  # Shared OpenSSH hardening applied across all NixOS hosts.
  # Restricts SSH to tailscale0 whenever the firewall is enabled; individual
  # hosts can override specific settings (e.g. openFirewall = true).
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 22 ];

  services.openssh = {
    openFirewall = lib.mkDefault false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitEmptyPasswords = false;
      PermitRootLogin = lib.mkDefault "no";
      X11Forwarding = lib.mkDefault false;
      MaxAuthTries = lib.mkDefault 8;

      # Modern post-quantum hybrid + Curve25519 crypto
      KexAlgorithms = [
        "mlkem768x25519-sha256"
        "sntrup761x25519-sha512"
        "sntrup761x25519-sha512@openssh.com"
        "curve25519-sha256"
        "curve25519-sha256@libssh.org"
      ];
      Ciphers = [
        "chacha20-poly1305@openssh.com"
        "aes256-gcm@openssh.com"
        "aes256-ctr"
      ];
      Macs = [
        "hmac-sha2-512-etm@openssh.com"
        "hmac-sha2-256-etm@openssh.com"
        "umac-128-etm@openssh.com"
      ];
    };
  };
}
