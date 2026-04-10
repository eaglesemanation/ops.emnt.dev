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
  }: {
    sops.secrets."chisel/authfile.json" = {};
    services.chisel-server = {
      enable = true;
      reverse = true;
      port = 9090;
      authfile = config.sops.secrets."chisel/authfile.json".path;
    };
  };
}
