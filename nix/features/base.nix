{
  inputs,
  lib,
  self,
  ...
}: {
  flake.nixosModules.base = {
    modulesPath,
    pkgs,
    config,
    ...
  }: {
    imports = [
      (modulesPath + "/installer/scan/not-detected.nix")
      (modulesPath + "/profiles/qemu-guest.nix")
    ];

    networking.nftables.enable = true;

    services.openssh = {
      enable = true;
      authorizedKeysInHomedir = true;
      settings.PasswordAuthentication = false;
      settings.KbdInteractiveAuthentication = false;
    };

    nix.settings = {
      experimental-features = ["nix-command" "flakes"];
    };
    nixpkgs.config.allowUnfree = true;

    system.stateVersion = "25.11";
  };
}
