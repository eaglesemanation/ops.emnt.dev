# Bootstraping talos cluster
## Prerequisites
- sops
- talosctl
- kubectl
- preconfigured VMs with Talos ISO

## Steps
1. Decrypt secrets with `sops -d secrets.sops.yaml > secrets.yaml`
2. Generate default machine configs with `talosctl gen config --with-secrets secrets.yaml talos-cluster-1 https://192.168.25.100:6443 --config-patch @common/disable-flannel.patch.yaml --config-patch @common/cert-rotation.patch.yaml --config-patch @common/metrics-bind-address.patch.yaml --config-patch @common/sysctl.patch.yaml`
3. Apply config to controlplane machines with `talosctl -n <VM IP> apply-config --insecure --file controlplane.yaml --config-patch @controlplane/virtual-ip.patch.yaml --config-patch @controlplane/oidc.patch.yaml --config-patch @machines/talos-controlplane-<NODE NUM>.patch.yaml`
4. Apply config to worker machines with `talosctl -n <VM IP> apply-config --insecure --file worker.yaml --config-patch @worker/iscsi.patch.yaml --config-patch @machines/talos-worker-<NODE NUM>.patch.yaml`
5. Update talosconfig endpoint with virtual IP `talosctl --talosconfig ./talosconfig config endpoints 192.168.25.100`
6. Update talosconfig nodes with static IPs `talosctl --talosconfig ./talosconfig config nodes 192.168.25.101 192.168.25.111`
7. Merge talosconfig with user global config `talosctl config merge ./talosconfig`
8. Bootstrap a single control plane node with `talosctl -n <VM IP> bootstrap`
9. Verify that all nodes are connected with `talosctl -n 192.168.25.100 get members`
10. Check health status of talos cluster with `talosctl -n 192.168.25.100 health`
11. Generate and merge kubectl config with `talosctl -n 192.168.25.100 kubeconfig`
12. Verify that all nodes are a part of k8s cluster `kubectl get nodes`
13. Clean up secrets with `rm controlplane.yaml worker.yaml secrets.yaml talosconfig`
