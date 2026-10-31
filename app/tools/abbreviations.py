"""Abbreviations, acronyms and brand names that passed the filters and are no
words to guess (bafta, nato, https), by language code. Found by listing the
words an en.wiktionary entry let in that the Hunspell dictionary does not know
and that it knows in capitals, then picking the abbreviations by hand. A word
is dropped as written.

    python abbreviations.py     remove them from the shipped lists and languages.json
"""
import json
import sys
from pathlib import Path

WORDS = Path(__file__).resolve().parent.parent / "assets" / "words"

ABBREVIATIONS = {
    "en": """bafta http lgbt nato nsfw jpeg rsvp ufos faqs awol fwiw otoh afaik covid ascii mirv norad conus
        osha wysiwyg reit conf proc prog regs devs recs defs reqs deps probs ipod wifi fedex myspace
        lmfao lmao""",
    "es": "covid",
    "fr": "ndlr",
    "sv": "nasa",
}


def is_abbreviation(code, word):
    return word in ABBREVIATIONS.get(code, "").split()


def main():
    manifest = json.loads((WORDS / "languages.json").read_text(encoding="utf-8"))
    for e in manifest:
        f = WORDS / f"{e['code']}.txt"
        lines = [l for l in f.read_text(encoding="utf-8").split("\n") if l.strip()]
        keep = [l for l in lines if not is_abbreviation(e["code"], l.split("\t")[0])]
        if len(keep) == len(lines):
            continue
        counts = {}
        for l in keep:
            n = str(len(l.split("\t")[0]))
            counts[n] = counts.get(n, 0) + 1
        f.write_text("\n".join(keep) + "\n", encoding="utf-8")
        e["counts"] = {k: counts.get(k, 0) for k in e["counts"]}
        print(f"{e['code']}: removed {len(lines) - len(keep)}", file=sys.stderr)
    (WORDS / "languages.json").write_text(
        json.dumps(manifest, indent=1, ensure_ascii=False) + "\n", encoding="utf-8"
    )


if __name__ == "__main__":
    main()
