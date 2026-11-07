#!/bin/sh
# Run Trivy scans and produce HTML reports.
# POSIX sh (aquasec/trivy image).
# Escaped for FluxCD envsubst

set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

SEVERITY="$${SEVERITY:-MEDIUM,HIGH,CRITICAL}"
CACHE="$${TRIVY_CACHE_DIR:-$HOME/.cache/trivy}"
CFG="$${TRIVY_CONFIG:-$HERE/trivy.yaml}"
IGN="$${TRIVY_IGNOREFILE:-$HERE/trivyignore.yaml}"

R="$OUT/reports"

HTML_TEMPLATE="$${TRIVY_HTML_TEMPLATE:-$HERE/trivy-report.tpl}"
IMAGE_HTML_TEMPLATE="$${TRIVY_IMAGE_HTML_TEMPLATE:-$HERE/trivy-image-compact.tpl}"
IMAGE_SUMMARY_TEMPLATE="$${TRIVY_IMAGE_SUMMARY_TEMPLATE:-$HERE/trivy-image-summary.tpl}"

FAILURES="$TMPDIR/trivy-image-failures"
SUMMARIES="$TMPDIR/trivy-image-summaries.tsv"
IMAGE_JSON="$TMPDIR/trivy-image.json"
IMAGE_SUMMARY="$TMPDIR/trivy-image-summary"
IMAGE_ERR="$TMPDIR/trivy-image.err"

mkdir -p "$R/images" "$CACHE" "$TMPDIR"

# Validate templates.
for template in "$HTML_TEMPLATE" "$IMAGE_HTML_TEMPLATE" "$IMAGE_SUMMARY_TEMPLATE"; do
  if [ ! -f "$template" ]; then
    echo "ERROR: Template not found: $template" >&2
    exit 1
  fi
done

# Run Trivy with subcommand-specific configuration flags.
# --config and --ignorefile must follow the subcommand.
trivy_cmd() {
  subcommand=$1
  shift

  set -- "$subcommand" "$@"

  if [ -f "$CFG" ]; then
    set -- "$@" --config "$CFG"
  fi

  if [ -f "$IGN" ]; then
    set -- "$@" --ignorefile "$IGN"
  fi

  trivy --quiet --cache-dir "$CACHE" "$@"
}

# Instantiate the shared report template with a report title.
# usage: make_template <title> <output file>
make_template() {
  # HTML-escape, then escape what is special in a sed replacement (& | \).
  safe_title=$(printf '%s' "$1" |
    sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' |
    sed -e 's/[&|\\]/\\&/g')
  sed "s|@@TITLE@@|$safe_title|g" "$HTML_TEMPLATE" >"$2"
}

version=$(trivy --version | head -n 1)

# Cache cleanup marker lives outside the scan cache.
MARK="$HOME/.cache/trivy-last-scan-cache-clean"

mkdir -p "$(dirname "$MARK")"
touch "$MARK" 2>/dev/null || :

if find "$MARK" -mtime "+$${CACHE_MAX_AGE_DAYS:-30}" -print | grep -q .; then
  echo "==> Cleaning old scan cache"
  trivy_cmd clean --scan-cache
  touch "$MARK"
fi

echo "==> Refreshing vulnerability DB"

trivy_cmd image --download-db-only ||
  echo "WARN: DB download failed; using cached DB if available" >&2

echo "==> Scanning rendered Flux output"

make_template "Kubernetes misconfigurations (rendered Flux output)" "$TMPDIR/report-rendered.tpl"
trivy_cmd config \
  --severity "$SEVERITY" \
  --format template \
  --template "@$TMPDIR/report-rendered.tpl" \
  --output "$R/misconfig-rendered.html" \
  "$OUT/rendered"

echo "==> Scanning repository"

make_template "Repository vulnerabilities and misconfigurations" "$TMPDIR/report-repo.tpl"
trivy_cmd fs \
  --scanners vuln,misconfig \
  --severity "$SEVERITY" \
  --format template \
  --template "@$TMPDIR/report-repo.tpl" \
  --output "$R/fs-repo.html" \
  "$REPO"

rm -f "$TMPDIR/report-rendered.tpl" "$TMPDIR/report-repo.tpl"

echo "==> Scanning container images"

: >"$FAILURES"
: >"$SUMMARIES"

total=$(grep -c . "$OUT/images.txt" || true)
n=0

while IFS= read -r img || [ -n "$img" ]; do
  [ -n "$img" ] || continue

  n=$((n + 1))
  f=$(printf '%s' "$img" | sed 's/[^A-Za-z0-9_.-]/_/g')

  echo "[$n/$total] $img"

  rm -f "$IMAGE_JSON" "$IMAGE_SUMMARY" "$IMAGE_ERR"

  # Build image scan arguments.
  if [ "$${IGNORE_UNFIXED:-false}" = "true" ]; then
    if trivy_cmd image \
      --parallel 1 \
      --ignore-unfixed \
      --scanners vuln \
      --severity "$SEVERITY" \
      --format json \
      --output "$IMAGE_JSON" \
      "$img" 2>"$IMAGE_ERR"; then
      :
    else
      echo "$img" >>"$FAILURES"
      echo "  FAILED: $(tail -n 1 "$IMAGE_ERR")" >&2
      continue
    fi
  else
    if trivy_cmd image \
      --parallel 1 \
      --scanners vuln \
      --severity "$SEVERITY" \
      --format json \
      --output "$IMAGE_JSON" \
      "$img" 2>"$IMAGE_ERR"; then
      :
    else
      echo "$img" >>"$FAILURES"
      echo "  FAILED: $(tail -n 1 "$IMAGE_ERR")" >&2
      continue
    fi
  fi

  # Generate compact HTML from the same scan results.
  if ! trivy_cmd convert \
    --format template \
    --template "@$IMAGE_HTML_TEMPLATE" \
    --output "$R/images/$f.html" \
    "$IMAGE_JSON" 2>"$IMAGE_ERR"; then
    echo "$img" >>"$FAILURES"
    echo "  FAILED generating HTML: $(tail -n 1 "$IMAGE_ERR")" >&2
    rm -f "$R/images/$f.html"
    continue
  fi

  # Generate severity counts from the same JSON results.
  if ! trivy_cmd convert \
    --format template \
    --template "@$IMAGE_SUMMARY_TEMPLATE" \
    --output "$IMAGE_SUMMARY" \
    "$IMAGE_JSON" 2>"$IMAGE_ERR"; then
    echo "$img" >>"$FAILURES"
    echo "  FAILED generating summary: $(tail -n 1 "$IMAGE_ERR")" >&2
    rm -f "$R/images/$f.html"
    continue
  fi

  # Summary template outputs five whitespace-separated counts:
  # critical high medium low unknown
  if ! read critical high medium low unknown <"$IMAGE_SUMMARY"; then
    echo "$img" >>"$FAILURES"
    echo "  FAILED reading vulnerability summary" >&2
    rm -f "$R/images/$f.html"
    continue
  fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$critical" "$high" "$medium" "$low" "$unknown" \
    "$img" "$f.html" >>"$SUMMARIES"

done <"$OUT/images.txt"

echo "==> Generating report index"

# Table cell for a severity count: coloured when non-zero, muted when zero.
# usage: sev_cell <SEVERITY> <count>
sev_cell() {
  if [ "$2" -gt 0 ]; then
    printf '<td class="sev-%s">%s</td>' "$1" "$2"
  else
    printf '<td class="zero">0</td>'
  fi
}

{
  echo '<!doctype html>'
  echo '<html><head><meta charset="utf-8">'
  echo '<meta name="viewport" content="width=device-width, initial-scale=1">'
  echo '<title>Trivy report</title>'
  echo '<style>'
  echo 'body{font-family:sans-serif;max-width:90rem;margin:2rem auto;padding:0 1rem}'
  echo 'li{margin:.5rem 0}'
  echo 'table{border-collapse:collapse;width:100%;font-size:.9rem}'
  echo 'th,td{border:1px solid #ccc;padding:.5rem;text-align:left}'
  echo 'th{background:#eee}'
  echo 'td:nth-child(n+2){text-align:center;font-variant-numeric:tabular-nums}'
  echo 'td:first-child{overflow-wrap:anywhere}'
  # Same severity colours as the per-image reports; zero counts are muted.
  echo 'th.sev-CRITICAL,td.sev-CRITICAL{color:#c00}'
  echo 'th.sev-HIGH,td.sev-HIGH{color:#d66b00}'
  echo 'th.sev-MEDIUM,td.sev-MEDIUM{color:#a58b00}'
  echo 'th.sev-LOW,td.sev-LOW{color:#398a20}'
  echo 'th.sev-UNKNOWN,td.sev-UNKNOWN{color:#777}'
  echo 'td[class^=sev-]{font-weight:bold}'
  echo 'td.zero{color:#aaa}'
  echo '</style></head><body>'

  echo '<h1>Trivy report</h1>'
  echo "<p>$(date -u '+%Y-%m-%d %H:%M UTC') &middot; $version</p>"

  echo '<h2>Manifests and repository</h2><ul>'
  echo '<li><a href="misconfig-rendered.html">Kubernetes misconfigurations (rendered Flux output)</a></li>'
  echo '<li><a href="fs-repo.html">Repository vulnerabilities and misconfigurations</a></li>'
  echo '</ul>'

  echo '<h2>Container images</h2>'

  echo '<table>'
  echo '<thead><tr>'
  echo '<th>Image</th>'
  echo '<th class="sev-CRITICAL">Critical</th>'
  echo '<th class="sev-HIGH">High</th>'
  echo '<th class="sev-MEDIUM">Medium</th>'
  echo '<th class="sev-LOW">Low</th>'
  echo '<th class="sev-UNKNOWN">Unknown</th>'
  echo '<th>Total</th>'
  echo '</tr></thead><tbody>'

  TAB=$(printf '\t')

  sort -t "$TAB" \
    -k1,1nr -k2,2nr -k3,3nr \
    "$SUMMARIES" |
    while IFS="$TAB" read -r critical high medium low unknown img report; do
      [ -n "$img" ] || continue

      total=$((critical + high + medium + low + unknown))

      # Escape image name for HTML.
      safe_img=$(printf '%s' "$img" | sed \
        -e 's/&/\&amp;/g' \
        -e 's/</\&lt;/g' \
        -e 's/>/\&gt;/g' \
        -e 's/"/\&quot;/g')

      printf '<tr>'
      printf '<td><a href="images/%s">%s</a></td>' "$report" "$safe_img"
      sev_cell CRITICAL "$critical"
      sev_cell HIGH "$high"
      sev_cell MEDIUM "$medium"
      sev_cell LOW "$low"
      sev_cell UNKNOWN "$unknown"
      printf '<td><strong>%s</strong></td>' "$total"
      printf '</tr>\n'
    done

  echo '</tbody></table>'

  if [ -s "$FAILURES" ]; then
    echo '<h2>Failed scans</h2><ul>'

    while IFS= read -r img; do
      safe_img=$(printf '%s' "$img" | sed \
        -e 's/&/\&amp;/g' \
        -e 's/</\&lt;/g' \
        -e 's/>/\&gt;/g' \
        -e 's/"/\&quot;/g')

      printf '<li>%s</li>\n' "$safe_img"
    done <"$FAILURES"

    echo '</ul>'
  fi

  echo '</body></html>'
} >"$R/index.html"

rm -f \
  "$FAILURES" \
  "$SUMMARIES" \
  "$IMAGE_JSON" \
  "$IMAGE_SUMMARY" \
  "$IMAGE_ERR"

echo "Scans done: $R/index.html"
