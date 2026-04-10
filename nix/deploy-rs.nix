{
  inputs,
  self,
  lib,
  flake-parts-lib,
  moduleLocation,
  ...
}: {
  options.flake = flake-parts-lib.mkSubmoduleOptions {
    deploy.nodes = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.raw;
      default = {};
    };
  };

  config = let
    nodeFromNixosConfig = config: {
      # Should be overridden by a CI with a --hostname flag
      hostname = "example.com";
      profiles.system = {
        user = "root";
        path = inputs.deploy-rs.lib.${config.pkgs.stdenv.hostPlatform.system}.activate.nixos config;
      };
    };

    nixosConfigNodes = builtins.mapAttrs (_: config: nodeFromNixosConfig config) self.nixosConfigurations;
  in {
    # Autogenerate deploy-rs targets that match 1:1 to nixos configs
    flake.deploy.nodes = nixosConfigNodes;

    perSystem = {system, ...}: let
      deployLib = inputs.deploy-rs.lib.${system};
    in {
      checks = deployLib.deployChecks self.deploy;
    };
  };
}
