"""Draw the Lexodle logo: three tiles climbing from grey to yellow to green.

Writes assets/logo.svg and the web icons (favicon, 192/512, maskable 192/512).
Needs Pillow:  pip install pillow
The same geometry is in lib/logo.dart; change one, change both.
"""
from pathlib import Path

from PIL import Image, ImageDraw

APP = Path(__file__).resolve().parent.parent

BG = "#16140F"
GREY, YELLOW, GREEN = "#4A453B", "#E0B83A", "#4C8C3A"

# viewBox 96 x 96: tile size, gap, corner radius, tile top-left positions
TILE, RADIUS = 22, 4
TILES = [(9, 51, GREY), (37, 37, YELLOW), (65, 23, GREEN)]
BG_RADIUS = 18
SS = 4  # supersampling for smooth edges


def svg() -> str:
    rects = "\n".join(
        f'  <rect x="{x}" y="{y}" width="{TILE}" height="{TILE}" rx="{RADIUS}" fill="{c}"/>'
        for x, y, c in TILES
    )
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96" width="96" height="96">\n'
        '  <title>lexodle</title>\n'
        f'  <rect width="96" height="96" rx="{BG_RADIUS}" fill="{BG}"/>\n{rects}\n</svg>\n'
    )


def render(size: int, *, maskable: bool = False, zoom: float = 1.0) -> Image.Image:
    """Square icon. Maskable icons are full-bleed with the mark inside the safe zone."""
    s = size * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    k = s / 96
    if maskable:
        d.rectangle([0, 0, s, s], fill=BG)
        zoom *= 0.8
    else:
        d.rounded_rectangle([0, 0, s - 1, s - 1], radius=BG_RADIUS * k, fill=BG)
    for x, y, color in TILES:
        # scale the mark about the centre of the icon
        x0 = 48 + (x - 48) * zoom
        y0 = 48 + (y - 48) * zoom
        d.rounded_rectangle(
            [x0 * k, y0 * k, (x0 + TILE * zoom) * k, (y0 + TILE * zoom) * k],
            radius=RADIUS * zoom * k,
            fill=color,
        )
    return img.resize((size, size), Image.LANCZOS)


def main() -> None:
    (APP / "assets" / "logo.svg").write_text(svg(), encoding="utf-8")
    web = APP / "web"
    render(32, zoom=1.12).save(web / "favicon.png")
    for n in (192, 512):
        render(n).save(web / "icons" / f"Icon-{n}.png")
        render(n, maskable=True).save(web / "icons" / f"Icon-maskable-{n}.png")


if __name__ == "__main__":
    main()
