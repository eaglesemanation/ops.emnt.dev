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
    nix2containerPkgs = inputs.nix2container.packages.${system};
    attic-client = inputs.attic.packages.${system}.attic-client;
  in {
    packages.nix2containerDockerImage = nix2containerPkgs.nix2container.buildImage {
      name = "nix2container";
      tag = "latest";
      maxLayers = 64;
      initializeNixDatabase = true;
      copyToRoot = [
        (pkgs.runCommand "dirs" {} ''
          mkdir -p $out/tmp
        '')
        (pkgs.buildEnv {
          name = "image-root";
          paths =
            [
              ./nix-root
              attic-client
            ]
            ++ (with nix2containerPkgs; [
              nix2container-bin
              skopeo-nix2container
            ])
            ++ (with pkgs; [
              nix
              bashInteractive
              gitMinimal
              coreutils
              gnutar
              gzip
              openssh
              xz
            ]);
          pathsToLink = ["/bin" "/etc" "/lib" "/share/nix"];
          extraOutputsToInstall = [];
        })
      ];
      config = {
        WorkingDir = "/app";
        Cmd = ["/bin/bash"];
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
