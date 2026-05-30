{
  inputs,
  lib,
  self,
  ...
}: {
  flake.nixosModules.chisel = {
    pkgs,
    config,
    ...
  }: let
    cfg = config.services.chisel-server;
  in {
    sops.secrets."chisel/authfile.json" = {};
    services.chisel-server = {
      enable = true;
      reverse = true;
      port = 9090;
      host = "0.0.0.0";
    };
    networking.firewall.allowedTCPPorts = [9090];
    systemd.services.chisel-server.serviceConfig = {
      LoadCredential = "authfile:${config.sops.secrets."chisel/authfile.json".path}";
      # Overriding due to cfg.authfile being restricted to path type
      ExecStart = [
        ""
        ("${pkgs.chisel}/bin/chisel server --authfile %d/authfile "
          + lib.concatStringsSep " " (
            lib.optional (cfg.host != null) "--host ${cfg.host}"
            ++ lib.optional (cfg.port != null) "--port ${toString cfg.port}"
            ++ lib.optional (cfg.keepalive != null) "--keepalive ${cfg.keepalive}"
            ++ lib.optional (cfg.backend != null) "--backend ${cfg.backend}"
            ++ lib.optional cfg.socks5 "--socks5"
            ++ lib.optional cfg.reverse "--reverse"
          ))
      ];
    };
  };
}
