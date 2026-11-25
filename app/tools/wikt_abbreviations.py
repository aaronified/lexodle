"""Finds the words of the shipped lists that the English Wiktionary shows as
abbreviations (an abbreviation, an initialism or an acronym), for every language.

It reads the wiktextract dump of each language (kaikki.org), streaming it, and
keeps nothing but what it finds about the words of our lists:

    python wikt_abbreviations.py [codes...]    writes <out>/abbr-<code>.json

Each flagged word has "kind": "pure" (every sense is an abbreviation), "mixed"
(it has an abbreviation sense and others) or "caps" (there is no page for the
lower-case word, only for the capitals: NATO), the counts of senses, and what
was found. The caller decides what to do with them.
"""
import json
import re
import subprocess
import sys
import urllib.parse
from pathlib import Path

WORDS = Path(__file__).resolve().parent.parent / "assets" / "words"
OUT = Path(sys.argv[0]).resolve().parent / "wikt_abbr_out"
KAIKKI = "https://kaikki.org/dictionary/{n}/kaikki.org-dictionary-{n}.jsonl"
TAGS = {"abbreviation", "initialism", "acronym"}
CAT = re.compile(r"(abbreviation|initialism|acronym)s?$", re.I)
HEAD = re.compile(r'\{"word": "((?:[^"\\]|\\.)*)"')
HEADWORD = re.compile(r"\b(abbreviation|initialism|acronym)\b", re.I)


def sense_is_abbr(s):
    if TAGS & set(s.get("tags") or []):
        return "tag"
    for c in s.get("categories") or []:
        name = c.get("name", "") if isinstance(c, dict) else str(c)
        if CAT.search(name):
            return "category"
    g = (s.get("glosses") or [""])[0]
    if re.match(r"(abbreviation|initialism|acronym) of\b", g, re.I):
        return "gloss"
    return None


def entry_abbr(d):
    """How many senses of an entry are abbreviations, out of how many, and why."""
    senses = d.get("senses") or []
    n = 0
    why = set()
    for s in senses:
        w = sense_is_abbr(s)
        if w:
            n += 1
            why.add(w)
    if n == 0 and d.get("pos") == "abbrev":
        return len(senses) or 1, len(senses) or 1, {"pos"}
    if n == 0:
        for t in d.get("head_templates") or []:
            if HEADWORD.search(t.get("expansion", "") or ""):
                # the entry says so in its heading line, for every sense
                return len(senses) or 1, len(senses) or 1, {"head"}
    return n, len(senses), why


def scan(code, name, words):
    url = KAIKKI.format(n=urllib.parse.quote(name))
    found = {}
    p = subprocess.Popen(["curl", "-sS", "-f", url], stdout=subprocess.PIPE)
    lines = 0
    for raw in p.stdout:
        lines += 1
        line = raw.decode("utf-8", "replace")
        m = HEAD.match(line)
        if not m:
            continue
        try:
            w = json.loads('"' + m.group(1) + '"')
        except ValueError:
            continue
        lw = w.lower()
        if lw not in words:
            continue
        try:
            d = json.loads(line)
        except ValueError:
            continue
        n, total, why = entry_abbr(d)
        rec = found.setdefault(lw, {"lower": 0, "caps": 0, "abbr": 0, "senses": 0, "capsabbr": 0, "why": set(), "pos": set()})
        if w == lw:
            rec["lower"] += 1
            rec["abbr"] += n
            rec["senses"] += total
            rec["pos"].add(d.get("pos", ""))
        else:
            rec["caps"] += 1
            if n:
                rec["capsabbr"] += 1
        rec["why"] |= why
    p.wait()
    out = {}
    for lw, r in found.items():
        if r["lower"]:
            if r["abbr"] == 0:
                continue
            kind = "pure" if r["abbr"] >= r["senses"] else "mixed"
        elif r["capsabbr"]:
            kind = "caps"
        else:
            continue
        out[lw] = {"kind": kind, "abbr": r["abbr"], "senses": r["senses"], "why": sorted(r["why"]), "pos": sorted(r["pos"])}
    return out, lines, p.returncode


def main():
    manifest = json.loads((WORDS / "languages.json").read_text(encoding="utf-8"))
    want = sys.argv[1:] or [e["code"] for e in manifest]
    OUT.mkdir(exist_ok=True)
    for e in manifest:
        if e["code"] not in want:
            continue
        words = {l.split("\t")[0] for l in (WORDS / f"{e['code']}.txt").read_text(encoding="utf-8").split("\n") if l.strip()}
        res, lines, rc = scan(e["code"], e["wikt"], words)
        (OUT / f"abbr-{e['code']}.json").write_text(json.dumps(res, ensure_ascii=False, indent=0), encoding="utf-8")
        kinds = {}
        for r in res.values():
            kinds[r["kind"]] = kinds.get(r["kind"], 0) + 1
        print(e["code"], "lines", lines, "rc", rc, "flagged", len(res), kinds, flush=True)


if __name__ == "__main__":
    main()
