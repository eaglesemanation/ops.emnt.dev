{
  inputs,
  ...
}: {
  perSystem = {
    pkgs,
    self',
    ...
  }: let
    system = pkgs.stdenv.hostPlatform.system;
    nix2container = inputs.nix2container.packages.${system}.nix2container;
    chisel = self'.packages.chisel;
  in {
    # Chisel client/server image built from the PROXY protocol fork
    # (see ../packages/chisel.nix). Used by chisel-operator tunnel pods and by
    # the smtp-relay client in k8s/apps/network/edge-gateways.
    packages.chiselDockerImage = nix2container.buildImage {
      name = "chisel";
      tag = "latest";
      copyToRoot = [
        chisel
        pkgs.cacert
        pkgs.dockerTools.fakeNss
      ];

      config = {
        # chisel-operator only sets args, so the binary has to be the entrypoint
        Entrypoint = ["/bin/chisel"];
        Env = [
          "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
        ];
        Labels = {
          "org.opencontainers.image.source" = "https://github.com/Skaronator/chisel";
        };
      };
    };
  };
}
