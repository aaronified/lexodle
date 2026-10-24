"""Checks that the app's own font draws every character the app can show.

A character the font lacks is drawn from a fallback font, which a web page has to
fetch from a font server (and which a test draws as a box). So every letter of
every word list, every language name and every character in the interface text
must be in the bundled JetBrains Mono, regular and bold. Run from the app folder:

    pip install fonttools
    python tools/check_glyphs.py

It exits 1 and lists what is missing, by where it was found, if anything is.
"""
import glob
import io
import json
import re
import sys

from fontTools.ttLib import TTFont

FONTS = [
    "assets/fonts/JetBrainsMono-Regular.ttf",
    "assets/fonts/JetBrainsMono-Bold.ttf",
]


def cmap(path):
    return set(TTFont(path).getBestCmap().keys())


def words():
    """Every character of every word in every word list, by language."""
    for path in sorted(glob.glob("assets/words/*.txt")):
        code = path.replace("\\", "/").split("/")[-1][:-4]
        seen = set()
        with io.open(path, encoding="utf-8") as f:
            for line in f:
                seen.update(line.split("\t")[0])
        yield f"words/{code}", seen


def names():
    with io.open("assets/words/languages.json", encoding="utf-8") as f:
        langs = json.load(f)
    seen = set()
    for m in langs:
        seen.update(m["name"])
    yield "language names", seen


STRING = re.compile(r"""'((?:[^'\\\n]|\\.)*)'|"((?:[^"\\\n]|\\.)*)\"""")


def interface():
    """Every character in a string literal of the Dart sources. Escapes such as
    \\u2212 are read as the character they name."""
    for path in sorted(glob.glob("lib/**/*.dart", recursive=True)):
        seen = set()
        with io.open(path, encoding="utf-8") as f:
            text = f.read()
        for m in STRING.finditer(text):
            s = m.group(1) if m.group(1) is not None else m.group(2)
            s = re.sub(r"\\u([0-9a-fA-F]{4})", lambda u: chr(int(u.group(1), 16)), s)
            s = re.sub(r"\\u\{([0-9a-fA-F]+)\}", lambda u: chr(int(u.group(1), 16)), s)
            seen.update(c for c in s if c.isprintable() and not c.isspace())
        yield path.replace("\\", "/"), seen


def main():
    fonts = {p: cmap(p) for p in FONTS}
    bad = {}
    for source in (words(), names(), interface()):
        for where, chars in source:
            for c in chars:
                for p, have in fonts.items():
                    if ord(c) not in have:
                        bad.setdefault((c, p), set()).add(where)
    if not bad:
        print("every character is in the font (regular and bold)")
        return 0
    for (c, p), where in sorted(bad.items()):
        print(f"U+{ord(c):04X} {c!r} is not in {p}: {', '.join(sorted(where))}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
