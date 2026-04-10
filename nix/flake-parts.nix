{
  self,
  inputs,
  ...
}: {
  imports = [inputs.disko.flakeModule];
  systems = ["x86_64-linux" "aarch64-linux"];

  perSystem = {
    config,
    system,
    ...
  }: {
    _module.args.pkgs = import self.inputs.nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
  };
}
