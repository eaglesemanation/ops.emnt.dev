{
  inputs,
  lib,
  self,
  ...
}: {
  perSystem = {
    config,
    pkgs,
    ...
  }: let
    system = pkgs.stdenv.hostPlatform.system;
    nixos-anywhere = inputs.nixos-anywhere.packages.${system}.nixos-anywhere;
    deploy-rs = inputs.deploy-rs.packages.${system}.deploy-rs;
    attic-client = inputs.attic.packages.${system}.attic-client;
    nix2container = inputs.nix2container.packages.${system}.nix2container;
  in {
    packages.nixosBuildDockerImage = nix2container.buildImage {
      name = "nixos-build";
      tag = "latest";
      initializeNixDatabase = true;
      copyToRoot = [
        (pkgs.runCommand "dirs" {} ''
          mkdir -p $out/tmp
        '')
        (pkgs.buildEnv {
          name = "image-root";
          paths =
            (with pkgs; [
              nix
              bashInteractive
              coreutils
              gitMinimal
              sops
              openssh
            ])
            ++ [
              ./nix-root
              attic-client
              nixos-anywhere
              deploy-rs
            ];
          pathsToLink = ["/bin" "/etc" "/lib" "/share/nix"];
          extraOutputsToInstall = [];
        })
      ];
      config = {
        Env = [
          "ENV=/etc/profile.d/nix.sh"
          "BASH_ENV=/etc/profile.d/nix.sh"
          "NIX_BUILD_SHELL=/bin/bash"
          "NIX_PAGER=cat"
          "USER=root"
          "HOME=/root"
          "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
        ];
        Labels = {
          "org.opencontainers.image.source" = "https://forgejo.emnt.dev/public/ops.emnt.dev";
        };
      };
    };
  };
}
