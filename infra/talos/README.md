# Bootstraping talos cluster

## Prerequisites

- sops
- talosctl
- kubectl
- Nodes with Talos ISO booted

## Steps

1. Generate default machine configs with `./gen-config.sh -c talos-cluster-1 -e https://192.168.25.100:6443 -v <Talos version, e.g. v1.7.4>`
2. Apply config to controlplane machines with `talosctl -n <Node IP> apply-config --insecure --file controlplane.yaml --config-patch @machines/talos-controlplane-<NODE NUM>.patch.yaml`
3. Apply config to worker machines with `talosctl -n <Node IP> apply-config --insecure --file worker.yaml --config-patch @machines/talos-worker-<NODE NUM>.patch.yaml`
4. Update talosconfig endpoint with virtual IP `talosctl --talosconfig ./talosconfig config endpoints 192.168.25.100`
5. Update talosconfig nodes with static IPs `talosctl --talosconfig ./talosconfig config nodes <Node IPs, separated with space>`
6. Merge talosconfig with user global config `talosctl config merge ./talosconfig`
7. Bootstrap a single control plane node with `talosctl -n <Node IP> bootstrap`
8. Verify that all nodes are connected with `talosctl -n 192.168.25.100 get members`
9. Check health status of talos cluster with `talosctl -n 192.168.25.100 health`
10. Generate and merge kubectl config with `talosctl -n 192.168.25.100 kubeconfig`
11. Verify that all nodes are a part of k8s cluster `kubectl get nodes`
12. Clean up with `rm controlplane.yaml worker.yaml talosconfig`
