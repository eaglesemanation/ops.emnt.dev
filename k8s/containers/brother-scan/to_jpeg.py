#!/usr/bin/env python3
"""Re-encode a scanned PNG page as a JPEG next to it (the PNG is left alone).

Usage: to_jpeg.py <png file> <dpi> <quality 1-95>

Raw scans are mostly sensor noise, which makes lossless PNGs huge (~10 MB per
page at 300 dpi). JPEG at quality ~90 drops that noise and keeps text edges
about as clean as the scan itself, at roughly a tenth of the size. img2pdf
embeds the JPEG as-is, so the PDF is not recompressed a second time.
"""

import sys
from pathlib import Path

from PIL import Image

src = Path(sys.argv[1])
dpi = int(sys.argv[2])
quality = int(sys.argv[3])
dst = src.with_suffix(".jpg")

with Image.open(src) as im:
    mode = "L" if im.mode == "L" else "RGB"
    im.convert(mode).save(dst, "JPEG", quality=quality, optimize=True, dpi=(dpi, dpi))

print(
    f"to_jpeg: {src.stat().st_size / 1e6:.1f} MB -> {dst.stat().st_size / 1e6:.1f} MB (q{quality})"
)
