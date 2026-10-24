"""Draw the Lexodle logo: three tiles climbing from grey to yellow to green.

Writes assets/logo.svg, the web icons (favicon, 192/512, maskable 192/512) and the
Android launcher icons: the rounded tile for phones before Android 8, and an adaptive
icon (the ground colour and the three tiles inside the safe zone) for the rest.
Needs Pillow:  pip install pillow
The same geometry is in lib/logo.dart; change one, change both.
"""
from pathlib import Path

from PIL import Image, ImageDraw

APP = Path(__file__).resolve().parent.parent

# The dark Material You scheme from lib/main.dart (surface, onSurface at 30%
# over it, tertiary, secondary). Icons cannot read the theme, so these are
# copied from it; if the seed in main.dart changes, update them.
BG = "#141409"
GREY, YELLOW, GREEN = "#535245", "#C7CB82", "#B4CEA5"

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


def render(
    size: int, *, maskable: bool = False, zoom: float = 1.0, ground: bool = True
) -> Image.Image:
    """Square icon. Maskable icons are full-bleed with the mark inside the safe zone.
    With no [ground] only the three tiles are drawn, on transparent."""
    s = size * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    k = s / 96
    if not ground:
        pass
    elif maskable:
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


RES = APP / "android" / "app" / "src" / "main" / "res"


def android() -> None:
    # legacy launcher icons, by density
    for name, px in [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)]:
        render(px).save(RES / f"mipmap-{name}" / "ic_launcher.png", optimize=True)
    # the adaptive icon: a 108 dp canvas of which the middle 66 dp is always seen. The
    # tiles are 54 dp wide, so their corners stay inside the circle every mask has.
    for name, px in [("mdpi", 108), ("hdpi", 162), ("xhdpi", 216), ("xxhdpi", 324), ("xxxhdpi", 432)]:
        render(px, ground=False, zoom=54 / 78).save(
            RES / f"mipmap-{name}" / "ic_launcher_foreground.png", optimize=True
        )
    (RES / "values").mkdir(parents=True, exist_ok=True)
    (RES / "values" / "ic_launcher_background.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        f'    <color name="ic_launcher_background">{BG}</color>\n</resources>\n',
        encoding="utf-8",
    )
    (RES / "mipmap-anydpi-v26").mkdir(parents=True, exist_ok=True)
    (RES / "mipmap-anydpi-v26" / "ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        "</adaptive-icon>\n",
        encoding="utf-8",
    )


def main() -> None:
    (APP / "assets" / "logo.svg").write_text(svg(), encoding="utf-8")
    android()
    web = APP / "web"
    render(32, zoom=1.12).save(web / "favicon.png")
    for n in (192, 512):
        render(n).save(web / "icons" / f"Icon-{n}.png")
        render(n, maskable=True).save(web / "icons" / f"Icon-maskable-{n}.png")


if __name__ == "__main__":
    main()
