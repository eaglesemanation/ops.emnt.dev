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

    systemd.services.chisel-server = {
      after = ["nftables.service"];
      requires = ["nftables.service"];
      serviceConfig = {
        NFTSet = ["cgroup:inet:chisel_server:chisel_server"];
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

    networking.nftables = {
      preCheckRuleset = ''
        sed -i 's/socket cgroupv2 level 2 @chisel_server//g' ruleset.conf
      '';
      tables."chisel_server" = {
        family = "inet";
        content = ''
          set chisel_server {
            type cgroupsv2
          }

          chain chisel_server {
            type filter hook input priority filter - 10
            socket cgroupv2 level 2 @chisel_server meta mark set 0x1 accept
          }
        '';
      };
    };
    networking.firewall = {
      allowedTCPPorts = [9090];
      extraInputRules = ''
        meta mark 0x1 accept
      '';
    };
  };
}
