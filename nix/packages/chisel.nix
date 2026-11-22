{
  lib,
  ...
}: {
  perSystem = {
    pkgs,
    ...
  }: let
    version = "1.13.0-unstable-2026-10-31";
  in {
    # Upstream v1.13.0 plus PROXY protocol v2 support for reverse remotes
    # ("RP:" prefix, https://github.com/Skaronator/chisel/tree/proxy-protocol-rebased).
    # Both peers must run it: the server writes the PROXY v2 header, the client
    # advertises the flag for the remote over the SSH handshake.
    packages.chisel = pkgs.buildGoModule {
      pname = "chisel";
      inherit version;

      src = pkgs.fetchFromGitHub {
        owner = "Skaronator";
        repo = "chisel";
        rev = "ff55e3c558780c12dfe528404aacdcbb06f3a34a";
        hash = "sha256-FvJR597cHRucmLZH+1Jk4jaT06vphsjAxYFN07oM8ZI=";
      };

      vendorHash = "sha256-Lv3XOIDWKzzmqBedKY8K3i7DdwDYTJvUwbz30Xfx5Kw=";

      ldflags = [
        "-s"
        "-w"
        "-X=github.com/jpillora/chisel/share.BuildVersion=${version}"
      ];

      # Tests bind sockets and talk to each other over the network.
      doCheck = false;

      meta = {
        description = "Fast TCP/UDP tunnel over HTTP, with PROXY protocol support";
        homepage = "https://github.com/Skaronator/chisel";
        changelog = "https://github.com/Skaronator/chisel/commits/proxy-protocol-rebased";
        license = lib.licenses.mit;
        mainProgram = "chisel";
      };
    };
  };
}
