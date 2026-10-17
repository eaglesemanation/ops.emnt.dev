#!/usr/bin/env python3
"""
Normalise a flatbed scan to a standard portrait page size, in place.

Usage: autocrop.py <png file> <dpi> [size]

  size = auto (default) | A6 | A5 | Letter | A4 | Legal

With "auto" the smallest standard size that holds the page's content is
chosen, and the scan is cropped or padded with white to exactly that size:
cropped where the scan is bigger (the extra glass below a Letter page),
padded where it is smaller (this scanner only captures about 209 mm of
width, so a 215.9 mm Letter page gets roughly 7 mm of white on the right).

The sheet is assumed to sit against the top-left of the glass, so only the
right and bottom edges are ever trimmed or padded. The lid is white, so paper
edges are invisible; the size is judged from where the content (text, images,
anything darker than the paper) ends.
"""

import sys

from PIL import Image

# Standard portrait sizes (name, width mm, height mm), smallest area first
SIZES: list[tuple[str, float, float]] = [
    ("A6", 105.0, 148.0),
    ("A5", 148.0, 210.0),
    ("Letter", 215.9, 279.4),
    ("A4", 210.0, 297.0),
    ("Legal", 215.9, 355.6),
]
DEFAULT_NAME = "Letter"  # used when the page looks blank

MARGIN_MM = 8.0  # keep at least this much space beyond the content
WHITE_BELOW = 225  # pixels darker than this (0-255) count as content
EDGE_IGNORE_MM = 6.0  # ignore this border on the left, right and bottom: the scanner's own edge shadows must not count as content

# Threshold lookup table: one entry per grey level
THRESHOLD = [255 if level < WHITE_BELOW else 0 for level in range(256)]


def find_size(name: str) -> tuple[str, float, float] | None:
    for size in SIZES:
        if size[0].lower() == name.lower():
            return size
    return None


def detect_size(im: Image.Image, dpi: int) -> tuple[str, float, float]:
    """Smallest standard size whose width and height both hold the content."""
    gray = im.convert("L")
    # Shrink to ~75 dpi: faster, and averaging suppresses dust and speckle
    factor = max(1, round(dpi / 75))
    small = gray.reduce(factor)
    edge = round(EDGE_IGNORE_MM / 25.4 * dpi / factor)
    # Trimming only left/right/bottom keeps y unchanged; x is shifted by `edge`
    small = small.crop((edge, 0, small.width - edge, small.height - edge))
    box = small.point(THRESHOLD).getbbox()  # (left, top, right, bottom) or None

    if box is None:
        default = find_size(DEFAULT_NAME)
        assert default is not None
        return default

    right_mm = (box[2] + edge) * factor / dpi * 25.4
    bottom_mm = box[3] * factor / dpi * 25.4
    need_w = right_mm + MARGIN_MM
    need_h = bottom_mm + MARGIN_MM
    return next((s for s in SIZES if s[1] >= need_w and s[2] >= need_h), SIZES[-1])


def main() -> None:
    path = sys.argv[1]
    dpi = int(sys.argv[2])
    wanted = sys.argv[3] if len(sys.argv) > 3 else "auto"

    im = Image.open(path)
    im.load()
    if im.mode not in ("RGB", "L"):
        im = im.convert("RGB")

    if wanted.lower() == "auto":
        name, w_mm, h_mm = detect_size(im, dpi)
    else:
        size = find_size(wanted)
        if size is None:
            names = ", ".join(s[0] for s in SIZES)
            sys.exit(f"autocrop: unknown size {wanted} (use auto or one of: {names})")
        name, w_mm, h_mm = size

    target_w = round(w_mm / 25.4 * dpi)
    target_h = round(h_mm / 25.4 * dpi)

    # White canvas of the exact target size, scan pasted at the top-left:
    # anything beyond the canvas is cropped, anything short is left white.
    white = 255 if im.mode == "L" else (255, 255, 255)
    canvas = Image.new(im.mode, (target_w, target_h), white)
    canvas.paste(
        im.crop((0, 0, min(im.width, target_w), min(im.height, target_h))), (0, 0)
    )
    canvas.save(path, dpi=(dpi, dpi))

    print(f"autocrop: {im.width}x{im.height} -> {target_w}x{target_h} px ({name})")


if __name__ == "__main__":
    main()
