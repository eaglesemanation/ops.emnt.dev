#!/bin/bash
# Called by brscan-skey when you press Scan on the printer.
#   $1 = menu choice (IMAGE | OCR | EMAIL | FILE)
#   $2 = SANE device name, e.g. brother4:net1;dev0
#   $3 = friendly device name
#
# The printer asks "scan next page?" after each sheet. Answering Yes gives us
# another page; answering No ends the batch (scanimage then stops by itself).
#
# IMAGE          -> every page saved as its own PNG
# anything else  -> all pages merged into ONE multi-page PDF
#
# Page size: every page is scanned over the full glass, then cropped or padded
# (white) to the smallest standard size that holds its content, so mixed
# documents just work. Override with SCAN_PAGE_SIZE:
#   auto (default)                 detect per page
#   A6 | A5 | Letter | A4 | Legal  force that size for every page
#   full                           keep the raw glass area, no crop or pad
set -u

# Send our output to the container log (fall back to nowhere so we never
# keep brscan-skey's pipes open).
if [ -w /proc/1/fd/1 ]; then exec >>/proc/1/fd/1 2>&1; else exec >/dev/null 2>&1; fi

MODE="$1"
DEVICE="$2"
OUT_DIR="${CONSUME_DIR:-/consume}"
RES="${SCAN_RESOLUTION:-300}"
PAGE_SIZE="${SCAN_PAGE_SIZE:-auto}"
AUTOCROP="${AUTOCROP_BIN:-/usr/local/bin/autocrop.py}"
TOJPEG="${TOJPEG_BIN:-/usr/local/bin/to_jpeg.py}"
# JPEG quality for pages inside PDFs (1-95). 90 is ~10x smaller than the raw
# PNG with no visible change; 0 keeps the lossless PNG. IMAGE scans stay PNG.
JPEG_QUALITY="${PDF_JPEG_QUALITY:-90}"
# Safety net in case the printer never ends the batch
TIMEOUT="${SCAN_TIMEOUT:-600}"
umask 022

# Copy under a "._" name (paperless ignores it by default), then rename,
# so paperless never picks up a half-written file.
publish() { # publish <source file> <final name>
	cp "$1" "$OUT_DIR/._$2" && mv "$OUT_DIR/._$2" "$OUT_DIR/$2"
	echo "[$(date)] saved $OUT_DIR/$2"
}

ts=$(date +%Y%m%d-%H%M%S)
work=$(mktemp -d /tmp/scan-XXXXXX)
trap 'rm -rf "$work"' EXIT

# brscan4 has an initialization quirk when invoked from brscan-skey:
# explicitly enumerate devices first, otherwise sane_open() can return
# EINVAL for the otherwise-valid network device.
scanimage -L >/dev/null 2>&1 || true

echo "[$(date)] scan requested via '$MODE' on $DEVICE (page size: $PAGE_SIZE)"
timeout "$TIMEOUT" scanimage -d "$DEVICE" --resolution "$RES" --format=png \
	--batch="$work/p%03d.png"

pages=("$work"/p*.png)
if [ ! -e "${pages[0]}" ]; then
	echo "[$(date)] no pages scanned" >&2
	exit 1
fi
echo "[$(date)] scanned ${#pages[@]} page(s)"

if [ "$PAGE_SIZE" != "full" ]; then
	for f in "${pages[@]}"; do
		# If this fails the page is kept as scanned, never lost
		python3 -I "$AUTOCROP" "$f" "$RES" "$PAGE_SIZE" || echo "[$(date)] autocrop failed on $(basename "$f"); kept raw page" >&2
	done
fi

if [ "$MODE" = "IMAGE" ]; then
	i=0
	for f in "${pages[@]}"; do
		i=$((i + 1))
		publish "$f" "scan-$ts-$i.png"
	done
else
	# Shrink each page to JPEG (img2pdf embeds it without recompressing).
	# A page that fails to convert stays as its PNG, never lost.
	pdf_pages=()
	for f in "${pages[@]}"; do
		if [ "$JPEG_QUALITY" != "0" ] && python3 -I "$TOJPEG" "$f" "$RES" "$JPEG_QUALITY"; then
			pdf_pages+=("${f%.png}.jpg")
		else
			pdf_pages+=("$f")
		fi
	done

	# Tell img2pdf the scan DPI so pages come out at real size; fall back to
	# its defaults if that option is rejected.
	pdf="$work/out.pdf"
	img2pdf --imgsize "${RES}dpi" -o "$pdf" "${pdf_pages[@]}" 2>/dev/null ||
		img2pdf -o "$pdf" "${pdf_pages[@]}"
	publish "$pdf" "scan-$ts.pdf"
fi
