{
  inputs,
  lib,
  self,
  ...
}: {
  flake.nixosConfigurations.edgeGatewayGeneric = lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      self.nixosModules.edgeGateway
      self.nixosModules.disko
    ];
  };

  flake.nixosConfigurations.edgeGatewayQemu = lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      self.nixosModules.edgeGateway
      self.nixosModules.disko
      {disko.devices.disk.disk1.device = "/dev/vda";}
    ];
  };

  flake.nixosConfigurations.edgeGatewayDigitalocean = lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      self.nixosModules.edgeGateway
      self.nixosModules.digitalocean
    ];
  };

  flake.nixosModules.edgeGateway = {pkgs, ...}: {
    imports = with self.nixosModules; [
      base
      sops
      chisel
      crowdsecBouncer
    ];
  };
}
