#!/bin/sh
# Run all Trivy scans and write human-readable reports. POSIX sh (aquasec/trivy image).
#
# Each scan is saved once as JSON (machine-readable, complete), then rendered
# with `trivy convert` into a text table (.txt) and an HTML page (.html)
# without scanning again.
#
# Env:   REPO, OUT, SEVERITY (default MEDIUM,HIGH,CRITICAL), IGNORE_UNFIXED (false),
#        SBOM (true), TRIVY_CONFIG, TRIVY_IGNOREFILE, TRIVY_CACHE_DIR
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
SEVERITY="${SEVERITY:-MEDIUM,HIGH,CRITICAL}"
CACHE="${TRIVY_CACHE_DIR:-$HOME/.cache/trivy}"
CFG="${TRIVY_CONFIG:-$HERE/../trivy.yaml}"
IGN="${TRIVY_IGNOREFILE:-$HERE/../trivyignore.yaml}"
R="$OUT/reports"

COMMON="--quiet --cache-dir $CACHE"
[ -f "$CFG" ] && COMMON="$COMMON --config $CFG"
[ -f "$IGN" ] && COMMON="$COMMON --ignorefile $IGN"

mkdir -p "$R/images" "$R/sbom" "$CACHE"
trivy --version >"$R/trivy-version.txt"

# JSON -> table + html
render() {
  base="${1%.json}"
  trivy convert --quiet --format table --output "$base.txt" "$1"
  if [ -f /contrib/html.tpl ]; then
    trivy convert --quiet --format template --template "@/contrib/html.tpl" --output "$base.html" "$1"
  fi
}

# Trivy has no age-based cache expiry (--cache-ttl is Redis-only), so wipe the
# scan cache every CACHE_MAX_AGE_DAYS. The vulnerability DB replaces itself on
# update and needs no cleaning. Cost: the first run after a wipe re-pulls layers.
MARK="$CACHE/.last-scan-cache-clean"
[ -f "$MARK" ] || touch "$MARK"
if [ -n "$(find "$MARK" -mtime +"${CACHE_MAX_AGE_DAYS:-30}")" ]; then
  echo "==> scan cache older than ${CACHE_MAX_AGE_DAYS:-30} days, cleaning"
  trivy clean --quiet --cache-dir "$CACHE" --scan-cache
  touch "$MARK"
fi

echo "==> refreshing vulnerability DB"
# shellcheck disable=SC2086
trivy image $COMMON --download-db-only || echo "WARN: DB download failed; using cached DB if any" >&2

echo "==> misconfigurations in rendered Flux output"
# shellcheck disable=SC2086
trivy config $COMMON --severity "$SEVERITY" --format json \
  --output "$R/misconfig-rendered.json" "$OUT/rendered"
render "$R/misconfig-rendered.json"

echo "==> repo scan (secrets, raw IaC/Helm misconfig, lockfile vulns, licenses)"
# shellcheck disable=SC2086
trivy fs $COMMON --scanners vuln,misconfig,secret,license --severity "$SEVERITY" \
  --format json --output "$R/fs-repo.json" "$REPO"
render "$R/fs-repo.json"

echo "==> container images"
UNFIXED=""
[ "${IGNORE_UNFIXED:-false}" = "true" ] && UNFIXED="--ignore-unfixed"
: >"$R/image-failures.txt"
total=$(grep -c . "$OUT/images.txt" || true)
n=0
while IFS= read -r img; do
  [ -n "$img" ] || continue
  n=$((n + 1))
  f=$(printf '%s' "$img" | tr '/:@' '___')
  echo "[$n/$total] $img"
  # shellcheck disable=SC2086
  if trivy image $COMMON $UNFIXED --scanners vuln,secret --severity "$SEVERITY" \
    --format json --output "$R/images/$f.json" "$img" 2>"$R/images/$f.err"; then
    render "$R/images/$f.json"
    if [ "${SBOM:-true}" = "true" ]; then
      # shellcheck disable=SC2086
      trivy image $COMMON --format cyclonedx --output "$R/sbom/$f.cdx.json" "$img" >/dev/null 2>&1 || true
    fi
  else
    echo "$img" >>"$R/image-failures.txt"
    echo "  FAILED: $(tail -n 1 "$R/images/$f.err")" >&2
  fi
done <"$OUT/images.txt"

# One readable file with everything, also printed to the step log
{
  echo "##### Rendered Flux manifests: misconfigurations"
  cat "$R/misconfig-rendered.txt"
  echo
  echo "##### Raw repo files"
  cat "$R/fs-repo.txt"
  echo
  echo "##### Images"
  for t in "$R"/images/*.txt; do [ -f "$t" ] && cat "$t"; done
  if [ -s "$R/image-failures.txt" ]; then
    echo
    echo "##### Images that could not be scanned"
    cat "$R/image-failures.txt"
  fi
} >"$R/all.txt"
cat "$R/all.txt"

# index.html: the landing page Argo's UI shows for the reports directory.
# Only links (no scripts: the UI sandbox blocks JavaScript).
EXT=txt
[ -f /contrib/html.tpl ] && EXT=html
{
  echo '<!doctype html><meta charset="utf-8"><title>Trivy report</title>'
  echo '<style>body{font-family:sans-serif;max-width:60rem;margin:2rem auto;padding:0 1rem}li{margin:.25rem 0}</style>'
  echo "<h1>Trivy report</h1><p>$(date -u '+%Y-%m-%d %H:%M UTC') &middot; $(head -n 1 "$R/trivy-version.txt")</p>"
  echo "<h2>Manifests and repo</h2><ul>"
  echo "<li><a href=\"misconfig-rendered.$EXT\">Kubernetes misconfigurations (rendered Flux output)</a></li>"
  echo "<li><a href=\"fs-repo.$EXT\">Repo files: secrets, IaC, dependencies, licenses</a></li>"
  echo "<li><a href=\"all.txt\">Everything as one text file</a></li></ul>"
  echo "<h2>Images</h2><ul>"
  while IFS= read -r img; do
    [ -n "$img" ] || continue
    f=$(printf '%s' "$img" | tr '/:@' '___')
    if [ -f "$R/images/$f.$EXT" ]; then
      echo "<li><a href=\"images/$f.$EXT\">$img</a></li>"
    else
      echo "<li>$img (scan failed)</li>"
    fi
  done <"$OUT/images.txt"
  echo "</ul>"
} >"$R/index.html"

echo "scans done"
