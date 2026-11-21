{
  # Shared OpenSSH hardening for nix-darwin hosts.
  # macOS's /etc/ssh/sshd_config includes /etc/ssh/sshd_config.d/* by default;
  # 050-hardening.conf sorts before Apple's 100-macos.conf (first-match-wins).
  environment.etc."ssh/sshd_config.d/050-hardening.conf".text = ''
    PasswordAuthentication no
    KbdInteractiveAuthentication no
    PermitEmptyPasswords no
    PermitRootLogin no
    MaxAuthTries 8
  '';
}
