#!/bin/sh
# Render the whole Flux repo (Kustomizations + HelmReleases) with flate and
# collect every container image it references.
#
# Every Kustomization and HelmRelease is rendered into its own file
# (rendered/ks/<name>.yaml, rendered/hr/<name>.yaml), so the Trivy report can
# say which Flux object a finding belongs to.
#
# Needs: flate on PATH.
# Env:   REPO             repo checkout   (default: .)
#        OUT              output dir      (default: ./work/out)
#        FLATE_CACHE_DIR  flate cache     (recommended: every object is a
#                         separate flate run, without a persistent cache they
#                         all refetch their sources)
set -eu

names="$OUT/names.txt"

for kind in ks hr; do
  mkdir -p "$OUT/rendered/$kind"

  echo "==> flate get $kind"
  # Into a file, not a pipe: a failing flate must stop the script.
  flate get "$kind" --path "$REPO" -o name >"$names"
  sort -u -o "$names" "$names"

  echo "==> flate build $kind ($(grep -c . "$names" || true) objects)"
  while IFS= read -r name || [ -n "$name" ]; do
    [ -n "$name" ] || continue
    echo "====> flate build $kind $name"
    flate build "$kind" "$name" --path "$REPO" >"$OUT/rendered/$kind/$name.yaml"
  done <"$names"
done

rm -f "$names"

echo "==> flate get images"
flate get images --path "$REPO" -o name | sort -u >"$OUT/images.txt"

n=$(grep -c . "$OUT/images.txt" || true)
echo "found $n unique images:"
cat "$OUT/images.txt"
[ "$n" -gt 0 ] || {
  echo "no images found, check 'flate get images --help' output format" >&2
  exit 1
}
