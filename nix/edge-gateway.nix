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
    ];
  };

  flake.nixosConfigurations.edgeGatewayQemu = lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      self.nixosModules.edgeGateway
      {disko.devices.disk.disk1.device = "/dev/vda";}
    ];
  };

  flake.nixosConfigurations.edgeGatewayDigitalocean = lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      self.nixosModules.edgeGateway
      self.nixosModules.digitalocean
      {disko.devices.disk.disk1.device = "/dev/vda";}
    ];
  };

  flake.nixosModules.edgeGateway = {pkgs, ...}: {
    imports = [
      self.nixosModules.base
      self.nixosModules.chisel
      self.nixosModules.crowdsecBouncer
    ];
  };
}
