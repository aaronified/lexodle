"""The topic categories of the English Wiktionary, from its dumps, for build_themes.py.

Wiktionary files its English entries under topic categories ("Category:en:Birds",
"Category:en:Geometry"), each with its entries and its sub-categories. This reads
the category tables of the database dumps (the same three files as
wiktionary_members.py: one download, about 1.7 GB, streamed, nothing kept) and
writes tools/dictionaries/wiktionary-topics.json:

    {"pages": {"en:Birds": ["albatross", ...]}, "subs": {"en:Birds": ["en:Parrots", ...]}}

Usage:  python wiktionary_topics.py
"""
import collections
import gzip
import json
import re
import sys
import urllib.request
from pathlib import Path

BASE = "https://dumps.wikimedia.org/enwiktionary/latest/enwiktionary-latest-{}.sql.gz"
UA = "lexodle-build/1.0 (https://github.com/aaronified/lexodle)"
OUT = Path(__file__).resolve().parent / "dictionaries" / "wiktionary-topics.json"

# a quoted SQL string: no quote or backslash, or a backslash and one character
Q = r"'((?:[^'\\]|\\.)*)'"
LINKTARGET = re.compile(r"\((\d+),(\d+)," + Q + r"\)")
CATLINK = re.compile(r"\((\d+)," + Q + r",'[^']*'," + Q + r",'(page|subcat|file)',\d+,(\d+)\)")
PAGE = re.compile(r"\((\d+),(\d+)," + Q + r",")


def stream(name):
    """The lines of one dump, decompressed as they arrive."""
    req = urllib.request.Request(BASE.format(name), headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=180) as r, gzip.GzipFile(fileobj=r) as f:
        for line in f:
            if line.startswith((b"INSERT INTO", b"(")):
                yield line.decode("utf-8", errors="replace")


def main():
    print("linktarget…", file=sys.stderr)
    target = {}  # id -> "en:Birds"
    for line in stream("linktarget"):
        for m in LINKTARGET.finditer(line):
            if m[2] == "14" and m[3].startswith("en:"):
                target[int(m[1])] = m[3]
    print(f"  {len(target)} topic categories", file=sys.stderr)
    print("categorylinks…", file=sys.stderr)
    rows = []  # (page id, category id, page or subcat)
    for line in stream("categorylinks"):
        for m in CATLINK.finditer(line):
            if int(m[5]) in target and m[4] in ("page", "subcat"):
                rows.append((int(m[1]), int(m[5]), m[4]))
    print(f"  {len(rows)} links", file=sys.stderr)
    want = {r[0] for r in rows}
    print("page…", file=sys.stderr)
    title, ns = {}, {}
    for line in stream("page"):
        for m in PAGE.finditer(line):
            if int(m[1]) in want:
                title[int(m[1])] = m[3].replace("_", " ")
                ns[int(m[1])] = m[2]
    pages, subs = collections.defaultdict(set), collections.defaultdict(set)
    for f, t, kind in rows:
        if f not in title:
            continue
        if kind == "page" and ns[f] == "0":
            pages[target[t]].add(title[f])
        elif kind == "subcat" and ns[f] == "14":
            subs[target[t]].add(title[f].replace("Category:", "").replace(" ", "_"))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(
        json.dumps({"pages": {k: sorted(v) for k, v in pages.items()}, "subs": {k: sorted(v) for k, v in subs.items()}}),
        encoding="utf-8",
    )
    print(f"wrote {OUT} ({len(pages)} categories with entries)", file=sys.stderr)


if __name__ == "__main__":
    main()
