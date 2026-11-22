{pkgs, ...}: {
  packages = with pkgs; [
    # Core repo tooling
    git
    curl
    jq
    yq-go
    shellcheck

    # Kubernetes / Flux / Helm
    kubectl
    kustomize
    kubernetes-helm
    fluxcd

    # Secrets (SOPS + age)
    sops
    age
    age-plugin-yubikey

    # Talos
    talosctl

    # Nix / host provisioning
    nixfmt
    deploy-rs
    nixos-anywhere

    # YAML / Renovate / formatting helpers
    prettier
    yamllint
    renovate
  ];

  enterShell = ''
    echo "emnt.dev infrastructure dev shell"
  '';
}
