#!/bin/bash

set -e

# Reset in case getopts has been used previously in the shell.
OPTIND=1

usage() { echo "Usage: $0 -c clusterName -e endpoint"; exit 1; }

cluster_name=""
endpoint=""

while getopts "c:e:" opt; do
  case "$opt" in
    c)
        cluster_name=$OPTARG
        ;;
    e)
        endpoint=$OPTARG
        ;;
    *)
        usage
        ;;
  esac
done

shift $((OPTIND-1))

[ "${1:-}" = "--" ] && shift

if [ -z "$cluster_name" ] || [ -z "$endpoint" ]; then
    usage
fi

echo "Decrypting secrets.yaml"
sops -d secrets.sops.yaml > secrets.yaml
for encrypted_patch in */*.sops.yaml; do
    echo "Decrypting $encrypted_patch"
    sops -d "$encrypted_patch" > "$encrypted_patch.patch.yaml"
done

COMMON_PATCHES=""
for patch in common/*.patch.yaml; do
    COMMON_PATCHES+="--config-patch @$patch "
done

CONTROL_PLANE_PATCHES=""
for patch in controlplane/*.patch.yaml; do
    CONTROL_PLANE_PATCHES+="--config-patch-control-plane @$patch "
done

WORKER_PATCHES=""
for patch in worker/*.patch.yaml; do
    WORKER_PATCHES+="--config-patch-worker @$patch "
done

echo "Generating config"
# shellcheck disable=2086
talosctl gen config --force --with-secrets secrets.yaml $cluster_name $endpoint $COMMON_PATCHES $CONTROL_PLANE_PATCHES $WORKER_PATCHES

echo "Deleting decrypted secrets"
rm secrets.yaml
# shellcheck disable=2035
rm */*.sops.yaml.patch.yaml

echo "Done"
