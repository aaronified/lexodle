"""Build the per-language word lists the Flutter app ships.

English reuses the original game's lexodle_list.csv (tools/data) (word + Google Ngrams count).
Every other language comes from `wordfreq` (pip install wordfreq).

Output: assets/words/<code>.txt, lines of `word<TAB>weight`, sorted by weight
descending within each length. The app treats the first ANSWERS words of each
length as possible answers and every word as a valid guess.
"""
import csv
import json
import math
import sys
import unicodedata
from pathlib import Path

csv.field_size_limit(10**9)

APP = Path(__file__).resolve().parent.parent
DATA = Path(__file__).resolve().parent / "data"
OUT = APP / "assets" / "words"
LENGTHS = range(4, 9)
POOL = 6000  # words kept per language and length
MIN_POOL = 400  # a length with fewer words than this is not offered

# code -> (name shown in the app, language heading used on en.wiktionary.org)
LANGS = {
    "en": ("English", "English"), "es": ("Español", "Spanish"),
    "fr": ("Français", "French"), "de": ("Deutsch", "German"),
    "it": ("Italiano", "Italian"), "pt": ("Português", "Portuguese"),
    "nl": ("Nederlands", "Dutch"), "pl": ("Polski", "Polish"),
    "sv": ("Svenska", "Swedish"), "da": ("Dansk", "Danish"),
    "nb": ("Norsk", "Norwegian Bokmål"), "fi": ("Suomi", "Finnish"),
    "tr": ("Türkçe", "Turkish"), "ro": ("Română", "Romanian"),
    "cs": ("Čeština", "Czech"), "id": ("Indonesia", "Indonesian"),
    "hu": ("Magyar", "Hungarian"), "ca": ("Català", "Catalan"),
}


def is_latin_word(w: str) -> bool:
    return w.isalpha() and all(
        unicodedata.name(c, "").startswith("LATIN") for c in w
    )


def english() -> dict[str, int]:
    out = {}
    with open(DATA / "lexodle_list.csv", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            w = row["word"].lower()
            if w.isascii() and w.isalpha():
                out[w] = max(1, int(row["wordcount"]))
    return out


def other(code: str) -> dict[str, int]:
    from wordfreq import top_n_list, zipf_frequency

    out = {}
    for w in top_n_list(code, 250_000):
        w = w.lower()
        if is_latin_word(w) and len(w) in LENGTHS:
            out[w] = max(1, int(10 ** zipf_frequency(w, code)))
    return out


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = []
    for code, (name, wikt) in LANGS.items():
        words = other(code)
        if code == "en":  # the repo's list is authoritative where it has data
            repo = english()
            # wordfreq includes names and fragments; the repo's dictionary
            # (dwyl/english-words) keeps only real words.
            with open(DATA / "words_dictionary.json", encoding="utf-8") as f:
                dictionary = set(json.load(f))
            words = {w: c for w, c in words.items() if w in dictionary}
            words ={w: c for w, c in words.items() if len(w) not in {len(r) for r in repo}}
            words.update(repo)
        lines, lengths = [], []
        for n in LENGTHS:
            pool = sorted(
                ((w, c) for w, c in words.items() if len(w) == n),
                key=lambda x: -x[1],
            )[:POOL]
            if len(pool) >= MIN_POOL:
                lengths.append(n)
                lines += [f"{w}\t{c}" for w, c in pool]
        (OUT / f"{code}.txt").write_text("\n".join(lines), encoding="utf-8")
        manifest.append({"code": code, "name": name, "wikt": wikt, "lengths": lengths})
        print(code, name, lengths, len(lines), file=sys.stderr)
    (OUT / "languages.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=1), encoding="utf-8"
    )


if __name__ == "__main__":
    main()
