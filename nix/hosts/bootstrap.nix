{
  inputs,
  lib,
  self,
  ...
}: {
  flake.nixosConfigurations.bootstrapDigitalocean = lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      self.nixosModules.base
      self.nixosModules.digitalocean
    ];
  };
}
