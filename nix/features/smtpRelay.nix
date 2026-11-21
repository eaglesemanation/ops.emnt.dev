{
  inputs,
  lib,
  self,
  ...
}: {
  flake.nixosModules.smtpRelay = {
    pkgs,
    config,
    ...
  }: {
    services.postfix = {
      enable = true;
      settings.main = {
        # Only reachable from this machine; there is no firewall rule for port 25 on purpose.
        inet_interfaces = "loopback-only";
        inet_protocols = "ipv4";
        mynetworks = ["127.0.0.0/8"];
        
        # Relay only, never deliver locally.
        mydestination = [];
        smtpd_relay_restrictions = ["permit_mynetworks" "reject"];
        
        smtp_tls_security_level = "may";
      };
    };
  };
}
