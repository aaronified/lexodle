"""Which words have an entry on en.wiktionary.org, for each language, from its dumps.

A word counts when the English Wiktionary files it as a lemma or a non-lemma form
of the language ("Category:English lemmas", "Category:English non-lemma forms").
That is the check build_words.py makes through the API for Portuguese; this reads
the database dumps instead, which is one download of about 1.5 GB rather than tens
of thousands of API requests. It writes tools/dictionaries/wiktionary-<heading>-
members.txt for every language in assets/words/languages.json, the files
build_words.py reads, and can then drop the words with no entry from the shipped
lists.

Usage:  python wiktionary_members.py            write the member files
        python wiktionary_members.py --filter   also remove the words without an
                                                entry from assets/words/*.txt and
                                                update languages.json
"""
import gzip
import json
import re
import sys
import unicodedata
import urllib.request
from pathlib import Path

APP = Path(__file__).resolve().parent.parent
WORDS = APP / "assets" / "words"
OUT = Path(__file__).resolve().parent / "dictionaries"
BASE = "https://dumps.wikimedia.org/enwiktionary/latest/enwiktionary-latest-{}.sql.gz"
UA = "lexodle-build/1.0 (https://github.com/aaronified/lexodle)"

# a quoted SQL string: no quote or backslash, or a backslash and one character
Q = r"'((?:[^'\\]|\\.)*)'"
LINKTARGET = re.compile(r"\((\d+),(\d+)," + Q + r"\)")
CATLINK = re.compile(r"\((\d+)," + Q + r",'[^']*'," + Q + r",'(page|subcat|file)',\d+,(\d+)\)")
PAGE = re.compile(r"\((\d+),(\d+)," + Q + r",")


def stream(name):
    """The lines of one dump, decompressed as they arrive."""
    req = urllib.request.Request(BASE.format(name), headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=120) as r, gzip.GzipFile(fileobj=r) as f:
        for line in f:
            # the rows are on the lines after INSERT INTO, or on the same line
            if line.startswith((b"INSERT INTO", b"(")):
                yield line.decode("utf-8", errors="replace")


def is_latin_word(w):
    return w.isalpha() and all(unicodedata.name(c, "").startswith("LATIN") for c in w)


def main():
    manifest = json.loads((WORDS / "languages.json").read_text(encoding="utf-8"))
    headings = {e["code"]: e["wikt"] for e in manifest}
    names = {}  # category title in the dump -> (heading)
    for h in set(headings.values()):
        for kind in ("lemmas", "non-lemma_forms"):
            names[f"{h.replace(' ', '_')}_{kind}"] = h
    print("linktarget…", file=sys.stderr)
    target = {}  # lt_id -> heading
    for line in stream("linktarget"):
        for m in LINKTARGET.finditer(line):
            if m[2] == "14" and m[3] in names:
                target[int(m[1])] = names[m[3]]
    print(f"  {len(target)} categories", file=sys.stderr)
    print("categorylinks…", file=sys.stderr)
    pages = {}  # page id -> the headings it is a lemma or a form of
    for line in stream("categorylinks"):
        for m in CATLINK.finditer(line):
            if m[4] == "page" and int(m[5]) in target:
                pages.setdefault(int(m[1]), set()).add(target[int(m[5])])
    print(f"  {len(pages)} pages", file=sys.stderr)
    print("page…", file=sys.stderr)
    members = {h: set() for h in headings.values()}
    for line in stream("page"):
        for m in PAGE.finditer(line):
            if m[2] == "0" and int(m[1]) in pages:
                t = m[3].replace("_", " ")
                if not (4 <= len(t) <= 8 and is_latin_word(t)):
                    continue
                # a word two languages share (from: English, Welsh) counts for
                # each of them. German nouns are capitalised on Wiktionary, so
                # German keeps a title that is not lowercase, as its lowercase.
                for h in pages[int(m[1])]:
                    if t == t.lower():
                        members[h].add(t)
                    elif h == "German":
                        members[h].add(t.lower())
    OUT.mkdir(parents=True, exist_ok=True)
    for h, ws in members.items():
        (OUT / f"wiktionary-{h}-members.txt").write_text("\n".join(sorted(ws)), encoding="utf-8")
        print(f"{h}: {len(ws)} words", file=sys.stderr)
    if "--filter" in sys.argv:
        filter_lists(manifest, headings, members)


def filter_lists(manifest, headings, members):
    """Remove the words with no entry from the shipped lists."""
    for e in manifest:
        f = WORDS / f"{e['code']}.txt"
        have = members[headings[e["code"]]]
        lines = [l for l in f.read_text(encoding="utf-8").split("\n") if l.strip()]
        keep = [l for l in lines if l.split("\t")[0] in have]
        counts = {}
        for l in keep:
            n = str(len(l.split("\t")[0]))
            counts[n] = counts.get(n, 0) + 1
        f.write_text("\n".join(keep) + "\n", encoding="utf-8")
        e["counts"] = {k: counts.get(k, 0) for k in e["counts"]}
        e["lengths"] = [n for n in e["lengths"] if counts.get(str(n), 0) >= 400]
        e["filter"] = e["filter"] if "wiktionary" in e["filter"] else e["filter"] + "+wiktionary"
        print(f"{e['code']}: kept {len(keep)} of {len(lines)}", file=sys.stderr)
    (WORDS / "languages.json").write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
