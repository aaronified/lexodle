"""Writes assets/donate/upi-qr.svg: the QR code of the project's UPI payment link.

    pip install segno
    python tools/make_donate_qr.py

The code is drawn here, once, and bundled, so the app asks no service to make it. The payee
and the UPI ID are the ones in lib/donate.dart; change both together.

Each dark run is a filled rectangle. segno's own SVG draws rows as stroked lines, and the
renderer in the app shows hairline gaps between those strokes, so the code looked like lines.
"""
import segno

UPI_ID = "das.arani@pingpay"
NAME = "Arani Das"
SCALE = 8
BORDER = 2

link = f"upi://pay?pa={UPI_ID}&pn={NAME.replace(' ', '%20')}&cu=INR"
qr = segno.make(link, error="m")
rows = [list(r) for r in qr.matrix]
size = len(rows) + 2 * BORDER

parts = []
for y, row in enumerate(rows):
    x = 0
    while x < len(row):
        if not row[x]:
            x += 1
            continue
        start = x
        while x < len(row) and row[x]:
            x += 1
        parts.append(f"M{start + BORDER} {y + BORDER}h{x - start}v1h-{x - start}z")

px = size * SCALE
svg = (
    f'<svg xmlns="http://www.w3.org/2000/svg" width="{px}" height="{px}" viewBox="0 0 {size} {size}" '
    f'shape-rendering="crispEdges">'
    f'<rect width="{size}" height="{size}" fill="#ffffff"/>'
    f'<path fill="#000000" d="{"".join(parts)}"/></svg>'
)
with open("assets/donate/upi-qr.svg", "w", encoding="utf-8") as f:
    f.write(svg)
print(link)
