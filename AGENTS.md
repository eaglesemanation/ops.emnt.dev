# AGENTS.md

## What this repo is

Declarative infrastructure for `emnt.dev`, managed as GitOps:

- **Kubernetes** apps and platform components live under `k8s/` and are reconciled by Flux CD.
- **Nix flakes** define NixOS hosts and container images under `nix/`.
- **Talos Linux** machine configuration lives under `infra/talos/`.
- **SOPS + age** is used for every encrypted secret.
- **Renovate** updates image tags, Helm charts, and Nix flake inputs.

There is no application package manager or unit-test suite. Validation means rendering/checking Nix and Kustomize outputs, and letting Flux reconcile in-cluster.

## Repository layout

| Path | Purpose |
| --- | --- |
| `k8s/flux/` | Flux bootstrap/config, cluster settings, GitRepository source. |
| `k8s/apps/<category>/` | Application categories. Each app has a Flux `Kustomization` and a directory of manifests. |
| `k8s/bootstrap/` | One-time Flux bootstrap manifests. |
| `k8s/containers/<name>/` | Containerfiles built by the in-cluster CI. |
| `nix/flake-parts.nix` | Flake-parts configuration. |
| `nix/features/` | Reusable NixOS modules (`nixosModules.*`). |
| `nix/hosts/` | `nixosConfigurations` for hosts/VMs. |
| `nix/containers/` | Nix-built OCI images. |
| `infra/talos/` | Talos machine configs, patches, and bootstrap script. |
| `docs/` | Operational runbooks, e.g. the backup test playbook. |

## Kubernetes conventions

### File naming

- Almost every Kubernetes manifest uses the `.k8s.yaml` suffix. Keep this convention; Renovate and repository tooling rely on it.
- `kustomization.yaml` files do **not** use the suffix.
- Files ending in `.sops.yaml` are SOPS-encrypted and must never be committed decrypted.

### Adding an application

1. Create `k8s/apps/<category>/<app>/`.
2. Add the manifests and a `kustomization.yaml` that lists every file under `resources:`. Include `namespace.k8s.yaml` first when the app owns a namespace.
3. Add a Flux `Kustomization` at `k8s/apps/<category>/<app>.k8s.yaml`:
   - `namespace: flux-system`
   - `path: ./k8s/apps/<category>/<app>`
   - `sourceRef.kind: GitRepository`, `sourceRef.name: emnt-ops`
   - `interval: 1h`, `prune: true`, and `wait: true` unless there is a reason not to wait.
4. Add `<app>.k8s.yaml` to `k8s/apps/<category>/kustomization.yaml`.
5. If creating a new category, add the category directory to `k8s/apps/kustomization.yaml`.

### Manifest style

- Use explicit `namespace:` on namespaced resources, even when the app directory has a namespace manifest.
- Use 2-space indentation, consistent with `k8s/.editorconfig`.
- Use `app.kubernetes.io/name` and `app.kubernetes.io/instance` labels on workloads.
- Prefer `Deployment` with `strategy: Recreate` for single-replica apps with RWO volumes.
- Use the existing storage classes: `freenas-api-iscsi-csi` (default), `freenas-api-smb-csi`, or `freenas-api-iscsi-s3-csi`.
- Ingress classes are `ingress-external-traefik` or `ingress-internal-traefik`.
- Public hostnames should use `${CLUSTER_DOMAIN}` rather than hard-coding `emnt.dev`.
- Add the Datree CRDs Catalog schema comment at the top of CRD manifests when one exists:
  ```yaml
  # yaml-language-server: $schema=https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/...
  ```

### Flux templating

Flux performs `postBuild` variable substitution for Kustomizations applied under `k8s/apps` and `k8s/flux`. Variables come from the `cluster-settings` ConfigMap in `k8s/flux/cluster-setting.k8s.yaml`.

Common substitutions include:

- `${CLUSTER_DOMAIN}`
- `${LOCAL_CIDR}`, `${POD_CIDR}`, `${SVC_CIDR}`
- `${GATEWAY_ADDR}`, `${K8S_API_ADDR}`, `${NAS_ADDR}`, `${NAS_URL}`
- `${SVC_DNS_ADDR}`, `${SVC_UNBOUND_ADDR}`
- `${SVC_INGRESS_INTERNAL_ADDR}`, `${SVC_INGRESS_EXTERNAL_ADDR}`

Add a new variable to `cluster-setting.k8s.yaml` rather than repeating environment-specific values. The bootstrap `k8s/bootstrap/kustomization.yaml` and the root Flux config are rendered without the full app substitution chain, so avoid unnecessary variables there.

### Dependencies and operators

- Flux `Kustomization` `dependsOn` is used for ordering, e.g. storage/operators before apps.
- Helm charts are deployed with `HelmRelease` plus `HelmRepository`/`OCIRepository` objects under `k8s/apps/repositories/`.
- Prefer CRDs/operators already present: CloudNativePG, Crossplane, External Secrets, cert-manager, Garage, Velero, etc.
- When adding custom update tracking, use Renovate annotations:
  ```yaml
  # renovate: datasource=github-releases depName=owner/repo
  ```
- Container image references in `k8s/containers/*/Containerfile` may also use `# renovate:` annotations.

## Secrets

- SOPS configuration is in `.sops.yaml`.
- `k8s/**/*.sops.yaml` encrypts only `data`, `stringData`, and `crowdsecLapiKey`.
- `infra/**/*.sops.(yaml|toml)` is encrypted according to the shared infra rule.
- Edit secrets with `sops <path>`; never use a plain editor on encrypted files.
- Never commit decrypted output such as `k8s/bootstrap/sops-age.yaml`, `infra/talos/secrets.yaml`, or generated Talos configs; they are gitignored.
- Do not manually edit `sops:` metadata. Let `sops` re-encrypt the file.
- External Secrets may generate secrets at runtime; prefer that over committing new static credentials where practical.

## Nix

- The flake uses `flake-parts` and `import-tree ./nix`; adding a `.nix` file under `nix/` is enough for it to be imported.
- NixOS hosts are exposed as `flake.nixosConfigurations.<name>`.
- Reusable host modules are exposed as `flake.nixosModules.<name>`.
- `nix/features/deploy-rs.nix` auto-generates a `deploy.nodes` entry for every NixOS configuration.
- Container images are exposed as `packages.<name>DockerImage` using `nix2container`.

Useful checks:

```sh
nix flake show
nix flake check
nix build .#nixosConfigurations. <name >.config.system.build.toplevel
nix build .#nixosBuildDockerImage
```

When changing a host, keep secrets out of the Nix store. Use `sops-nix` and `config.sops.secrets.<name>.path`.

## Talos

- Read `infra/talos/README.md` before changing machine configs.
- `infra/talos/gen-config.sh` generates/patches control plane and worker configs from `secrets.sops.yaml` and the patch directories.
- Talos machine configs, secrets, and `talosconfig` are generated artifacts and should not be committed when ignored or decrypted.
- Machine-specific patches belong in `infra/talos/machines/`; role-wide patches belong in `infra/talos/controlplane/` or `infra/talos/common/`.

## CI and automation

- Forgejo webhooks feed Argo Events sensors.
- Pushes touching `k8s/apps/` or `k8s/flux` trigger a Flux GitRepository reconcile.
- Pushes touching `k8s/containers/` trigger Kaniko builds for changed containers. The image is pushed to `forgejo.${CLUSTER_DOMAIN}/public/<container>:<revision>` and `:latest`.
- Nix container images are built/pushed through the `nix-containers` Argo WorkflowTemplate, using Attic for caching. It discovers every `packages.<name>DockerImage` in the flake and pushes it to `forgejo.${CLUSTER_DOMAIN}/public/<kebab-case name>:latest`, so a new image only needs a package under `nix/containers/`.
- Renovate runs from an in-cluster CronWorkflow. Its config is `.renovaterc.json5`; the runtime `config.json` lives under `k8s/apps/development/argo-workflows/renovate/`.
- Renovate schedules updates after 19:00 on Fridays in `America/Toronto`.

## Validation before finishing

Use the checks appropriate to what changed:

```sh
# Render a Kustomize app locally
kubectl kustomize k8s/apps/<category>/<app>

# Check the whole Flux/app tree (after bootstrap prerequisites exist)
kubectl kustomize k8s/apps

# Validate all Nix outputs (can be slow)
nix flake check

# Validate a specific host
nix build .#nixosConfigurations.<name>.config.system.build.toplevel
```

Also:

- Run `git diff --check` to catch trailing whitespace.
- Inspect `git status` to ensure no decrypted secrets or generated files are staged.
- Do not commit unrelated local changes.

## Commit style

Commits follow Conventional Commits, usually with a scope matching the app/component:

```text
feat(edge-gateway): Add smtp relay
fix(garage): Default to a single-node layout
chore(deps): update docker.io/actualbudget/actual-server docker tag to v26.11.0
chore(immich): Upgrade postgresql to v18
```

Use `feat`, `fix`, `chore`, `docs`, `refactor`, or `revert` and keep the subject imperative and scoped.

## Documentation

- Operational procedures belong in `docs/` (for example, `docs/backup-test-playbook.md`).
- Bootstrap instructions live in `k8s/README.md` and `infra/talos/README.md`; keep them updated when commands or prerequisites change.
