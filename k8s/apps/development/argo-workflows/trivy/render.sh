#!/bin/sh
# Render the whole Flux repo (Kustomizations + HelmReleases) with flate and
# collect every container image it references.
#
# Needs: flate on PATH.
# Env:   REPO   repo checkout   (default: .)
#        OUT    output dir      (default: ./work/out)
set -eu

REPO="${REPO:-.}"
OUT="${OUT:-./work/out}"

mkdir -p "$OUT/rendered"

echo "==> flate build all"
flate build all --path "$REPO" >"$OUT/rendered/all.yaml"

echo "==> flate get images"
flate get images --path "$REPO" -o name | sort -u >"$OUT/images.txt"

n=$(grep -c . "$OUT/images.txt" || true)
echo "found $n unique images:"
cat "$OUT/images.txt"
[ "$n" -gt 0 ] || {
  echo "no images found, check 'flate get images --help' output format" >&2
  exit 1
}
