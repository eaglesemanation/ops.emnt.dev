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
    nix2container = inputs.nix2container.packages.${system}.nix2container;
    attic-server = inputs.attic.packages.${system}.attic-server;
  in {
    packages.atticServerDockerImage = nix2container.buildImage {
      name = "attic-server";
      tag = "latest";
      copyToRoot = [
        attic-server
        pkgs.busybox
        pkgs.dockerTools.fakeNss
      ];

      config = {
        Entrypoint = ["/bin/atticd"];
        Env = [
          "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
        ];
        Labels = {
          "org.opencontainers.image.source" = "https://forgejo.emnt.dev/public/attic";
        };
      };
    };
  };
}
