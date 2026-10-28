"""Build the per-language word lists the Flutter app ships.

Every language is built the same way:

1. candidates: the words `wordfreq` knows for the language, Latin letters only,
   4 to 8 letters long, most frequent first;
2. filter: a candidate is kept only if the language's Hunspell dictionary
   accepts it (inflected forms included), and it is not a Roman numeral. Hunspell stores proper nouns
   capitalised, and the candidates are lowercase, so names (david, texas) and
   most abbreviations drop out. German nouns are capitalised in its dictionary,
   so German also tries the capitalised form;
3. the first POOL accepted words of each length are kept, with a weight from
   their frequency.

Spelling variants (English US / UK, Portuguese Brazil / Portugal) are one
language each. wordfreq has one frequency list per language and the variants'
dictionaries filter it differently (colour is accepted by the UK dictionary
and not by the US one), so a merged language keeps a word if any of its
dictionaries accepts it, and its weight is the average of the weights the
variants give it: the full weight when every dictionary accepts the word, half
of it (two variants) when only one does, since the other variant never uses
it. The first POOL words by that averaged weight are kept.

Two things differ: Indonesian uses LibreOffice's dictionary (wooorm has none),
and the two Portuguese lists get a second filter, because the Portuguese
dictionary accepts many names in lowercase (paulo, maria, brasil). A word must
also have its lowercase page on en.wiktionary.org as a Portuguese lemma or
non-lemma form, which names do not. Finnish was dropped: no Hunspell dictionary
exists for it in either collection.

Output (assets/words/): <code>.txt, lines of `word<TAB>weight`, sorted by weight
descending within each length; languages.json (names, flags, lengths, counts,
filter); SOURCES.md (the dictionaries and the licences they state).

Usage:  python build_words.py            build every language
        python build_words.py en-GB      build just these, keep the rest

Needs:  pip install wordfreq spylls pillow
Dictionaries are downloaded to tools/dictionaries/ (not committed).
"""
import json
import re
import sys
import time
import unicodedata
import urllib.parse
import urllib.request
from pathlib import Path

from swears import is_swear  # noqa: E402

APP = Path(__file__).resolve().parent.parent
OUT = APP / "assets" / "words"
# a Roman numeral, which no word list should hold
ROMAN = re.compile(r"^m{0,4}(cm|cd|d?c{0,3})(xc|xl|l?x{0,3})(ix|iv|v?i{0,3})$")
DICTS = Path(__file__).resolve().parent / "dictionaries"
LENGTHS = range(4, 9)
POOL = 6000  # words kept per language and length
MIN_POOL = 400  # a length with fewer words than this is not offered
EXAMINE = 80_000  # most candidates tried per length
FREQUENCY_ONLY_ZIPF = 3.0

# lists that also need a Wiktionary entry (see the module docstring)
WIKTIONARY_CHECKED = {"pt"}
WIKT_API = "https://en.wiktionary.org/w/api.php"
WIKT_UA = "lexodle-build/1.0 (https://github.com/aaronified/lexodle)"

WOORM = "https://raw.githubusercontent.com/wooorm/dictionaries/main/dictionaries/{c}/{f}"
LIBRE = "https://raw.githubusercontent.com/LibreOffice/dictionaries/master/{c}/{f}"

# code, name shown in the app, language heading on en.wiktionary.org,
# wordfreq code, dictionary directory (None: no dictionary; a list: the
# variants of one language, merged), flag.
# A flag is "svg:<name>" (or "svg:<a>+<b>", two flags side by side, for a
# language that merges two variants), a file in assets/flags/ (Twemoji graphics, CC BY 4.0,
# and the Catalan flag drawn for the project). They are not emoji: an emoji
# needs a font the device may not have, and a web page fetches one.
LANGS = [
    ("en", "English", "English", "en", ["en", "en-GB"], "svg:gb+us"),
    ("es", "Español", "Spanish", "es", "es", "svg:es"),
    ("fr", "Français", "French", "fr", "fr", "svg:fr"),
    ("de", "Deutsch", "German", "de", "de", "svg:de"),
    ("it", "Italiano", "Italian", "it", "it", "svg:it"),
    ("pt", "Português", "Portuguese", "pt", ["pt", "pt-PT"], "svg:br+pt"),
    ("nl", "Nederlands", "Dutch", "nl", "nl", "svg:nl"),
    ("pl", "Polski", "Polish", "pl", "pl", "svg:pl"),
    ("sv", "Svenska", "Swedish", "sv", "sv", "svg:se"),
    ("da", "Dansk", "Danish", "da", "da", "svg:dk"),
    ("nb", "Norsk", "Norwegian Bokmål", "nb", "nb", "svg:no"),
    ("tr", "Türkçe", "Turkish", "tr", "tr", "svg:tr"),
    ("ro", "Română", "Romanian", "ro", "ro", "svg:ro"),
    ("cs", "Čeština", "Czech", "cs", "cs", "svg:cz"),
    ("id", "Indonesia", "Indonesian", "id", "id", "svg:id"),
    ("hu", "Magyar", "Hungarian", "hu", "hu", "svg:hu"),
    ("ca", "Català", "Catalan", "ca", "ca", "svg:ca"),
]


def source(dictdir):
    """(url template, {local: remote}, origin) for a dictionary, or None."""
    if dictdir is None:
        return None
    if dictdir == "id":
        return LIBRE, {"index.aff": "id_ID.aff", "index.dic": "id_ID.dic"}, "LibreOffice/dictionaries"
    return WOORM, {"index.aff": "index.aff", "index.dic": "index.dic"}, "wooorm/dictionaries"


def get(url, dest):
    req = urllib.request.Request(url, headers={"User-Agent": "lexodle-build/1.0"})
    dest.write_bytes(urllib.request.urlopen(req, timeout=120).read())


def fetch(dictdir):
    """Download a dictionary once; return (path, licence text)."""
    tpl, files, _ = source(dictdir)
    d = DICTS / dictdir
    d.mkdir(parents=True, exist_ok=True)
    for local, remote in files.items():
        if not (d / local).exists():
            print(f"  downloading {dictdir}/{local}", file=sys.stderr)
            get(tpl.format(c=dictdir, f=remote), d / local)
    lic = d / "licence.txt"
    if not lic.exists():
        text = ""
        try:
            if tpl is WOORM:
                get(WOORM.format(c=dictdir, f="readme.md"), d / "readme.md")
                m = re.search(r"## License\s+(.+?)(\n\n|\Z)", (d / "readme.md").read_text(encoding="utf-8"), re.S)
                text = " ".join(m.group(1).split()) if m else ""
                # "Dictionary and affix file: [(GPL-3.0 OR MPL-2.0)](url). Rest: ..."
                link = re.search(r"\[([^\]]+)\]\(http", text)
                text = link.group(1) if link else text
            else:
                # LibreOffice's Indonesian dictionary ships LICENSE-dict: LGPL-3.0
                get(LIBRE.format(c=dictdir, f="LICENSE-dict"), d / "LICENSE-dict")
                head = (d / "LICENSE-dict").read_text(encoding="utf-8", errors="replace")[:200]
                text = "LGPL-3.0" if "LESSER GENERAL PUBLIC LICENSE" in head and "Version 3" in head else "see LICENSE-dict"
        except Exception as e:  # a missing licence line must not stop the build
            print(f"  could not read the licence of {dictdir}: {e}", file=sys.stderr)
        lic.write_text(text, encoding="utf-8")
    return d / "index", lic.read_text(encoding="utf-8")


def wiktionary_get(params):
    q = urllib.parse.urlencode({"format": "json", "formatversion": "2", **params})
    for attempt in range(6):
        try:
            req = urllib.request.Request(WIKT_API + "?" + q, headers={"User-Agent": WIKT_UA})
            return json.load(urllib.request.urlopen(req, timeout=60))
        except Exception as e:  # rate limited or a hiccup: back off and retry
            print(f"  wiktionary retry {attempt + 1}: {e}", file=sys.stderr)
            time.sleep(2 ** attempt)
    raise RuntimeError("Wiktionary did not answer")


def wiktionary_members(heading):
    """The lowercase single-word titles, 4 to 8 letters, that en.wiktionary.org
    files as a lemma or a non-lemma form of [heading] (for example Portuguese).
    Names are not among them: their lowercase titles are other languages' words
    or do not exist. The category listings are fetched once, 500 titles a
    request, and cached in a text file; the check is then a set lookup."""
    path = DICTS / f"wiktionary-{heading}-members.txt"
    if path.exists():
        return set(path.read_text(encoding="utf-8").split())
    members, requests = set(), 0
    for kind in ("lemmas", "non-lemma forms"):
        cont = None
        while True:
            params = {"action": "query", "list": "categorymembers",
                      "cmtitle": f"Category:{heading} {kind}", "cmlimit": "500", "cmtype": "page"}
            if cont:
                params["cmcontinue"] = cont
            data = wiktionary_get(params)
            for m in data["query"]["categorymembers"]:
                t = m["title"]
                if t == t.lower() and 4 <= len(t) <= 8 and is_latin_word(t):
                    members.add(t)
            requests += 1
            if requests % 100 == 0:
                print(f"  {heading} {kind}: {requests} requests, {len(members)} words", file=sys.stderr)
            cont = data.get("continue", {}).get("cmcontinue")
            if not cont:
                break
            time.sleep(0.2)
    DICTS.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(sorted(members)), encoding="utf-8")
    return members


def is_latin_word(w):
    return w.isalpha() and all(unicodedata.name(c, "").startswith("LATIN") for c in w)


_candidates = {}


def candidates(wf):
    """{length: [(word, zipf)]} for a wordfreq language, most frequent first."""
    if wf in _candidates:
        return _candidates[wf]
    from wordfreq import get_frequency_dict, zipf_frequency

    by_len = {n: [] for n in LENGTHS}
    for w, _ in sorted(get_frequency_dict(wf).items(), key=lambda x: -x[1]):
        w = w.lower()
        if len(w) in by_len and is_latin_word(w):
            by_len[len(w)].append(w)
    out = {}
    for n, ws in by_len.items():
        seen, uniq = set(), []
        for w in ws:  # the same word can appear twice after lowercasing
            if w not in seen:
                seen.add(w)
                uniq.append((w, zipf_frequency(w, wf)))
        out[n] = uniq
    _candidates[wf] = out
    return out


def acceptor(code, wf, dictdir):
    """accept(word, zipf) for one dictionary directory (None: frequency only)
    and the kind of filter it is."""
    from spylls.hunspell import Dictionary

    if dictdir is None:
        return (lambda w, z: z >= FREQUENCY_ONLY_ZIPF), "frequency"
    d = Dictionary.from_files(str(fetch(dictdir)[0]))
    if wf == "de":
        accept = lambda w, z: d.lookup(w) or d.lookup(w.capitalize())  # noqa: E731
    else:
        accept = lambda w, z: d.lookup(w)  # noqa: E731
    kind = "hunspell"
    if code in WIKTIONARY_CHECKED:
        members = wiktionary_members(HEADINGS[code])
        hunspell_ok = accept
        accept = lambda w, z: w in members and hunspell_ok(w, z)  # noqa: E731
        kind = "hunspell+wiktionary"
    return accept, kind


HEADINGS = {}


def build(code, wf, dictdir, heading):
    import heapq

    HEADINGS[code] = heading
    cands = candidates(wf)
    # Roman numerals (xviii) pass a dictionary but are no words to guess
    cands = {
        n: [(w, z) for w, z in c if not ROMAN.match(w) and not is_swear(code, w)]
        for n, c in cands.items()
    }
    dirs = dictdir if isinstance(dictdir, list) else [dictdir]
    accepts, kind = [], None
    for dd in dirs:
        acc, kind = acceptor(code, wf, dd)
        accepts.append(acc)
    lines, lengths, counts = [], [], {}
    for n in LENGTHS:
        kept = []
        if len(accepts) == 1:
            for w, z in cands[n][:EXAMINE]:
                if accepts[0](w, z):
                    kept.append((w, max(1, int(10 ** z))))
                    if len(kept) >= POOL:
                        break
        else:
            # merged variants: the weight is the average over the variants,
            # a variant that does not accept the word counting as 0. A later
            # candidate can weigh no more than its own raw weight, so the scan
            # stops once the POOL-th best averaged weight is above it.
            top = []  # min-heap of the POOL best averaged weights
            for w, z in cands[n][:EXAMINE]:
                raw = max(1, int(10 ** z))
                if len(top) >= POOL and raw <= top[0]:
                    break
                votes = sum(1 for acc in accepts if acc(w, z))
                if votes:
                    avg = max(1, round(raw * votes / len(accepts)))
                    kept.append((w, avg))
                    if len(top) < POOL:
                        heapq.heappush(top, avg)
                    elif avg > top[0]:
                        heapq.heapreplace(top, avg)
            kept.sort(key=lambda x: -x[1])  # stable: ties keep the raw order
            kept = kept[:POOL]
        counts[str(n)] = len(kept)
        if len(kept) >= MIN_POOL:
            lengths.append(n)
            lines += [f"{w}\t{c}" for w, c in kept]
    return lines, lengths, counts, kind


def write_sources(manifest):
    built = {m["code"]: m.get("filter") for m in manifest}
    rows = []
    for code, name, _, _, dictdir, _ in LANGS:
        dirs = dictdir if isinstance(dictdir, list) else [dictdir]
        src = source(dirs[0])
        if src is None:
            rows.append(f"| {name} (`{code}`) | frequency only (zipf >= 3) | none (no dictionary) |")
        else:
            extra = " + en.wiktionary.org lemma check" if built.get(code) == "hunspell+wiktionary" else ""
            ds = " and ".join(f"`{d}`" for d in dirs)
            merged = ", variants merged (weights averaged)" if len(dirs) > 1 else ""
            lic = "; ".join(f"`{d}`: {fetch(d)[1]}" if len(dirs) > 1 else fetch(d)[1] for d in dirs)
            rows.append(f"| {name} (`{code}`) | Hunspell, {src[2]} {ds}{extra}{merged} | {lic} |")
    (OUT / "SOURCES.md").write_text(
        "# Word list sources\n\n"
        "Candidates come from [wordfreq](https://github.com/rspeer/wordfreq) (CC BY-SA 4.0). "
        "Each is kept only if the language's Hunspell dictionary accepts it; only the filtered "
        "word lists are shipped, not the dictionaries. The licence is the one each dictionary "
        "package states for its dictionary and affix files.\n\n"
        "| Language | Filter | Dictionary licence |\n| --- | --- | --- |\n" + "\n".join(rows) + "\n",
        encoding="utf-8")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    only = set(sys.argv[1:])
    manifest_path = OUT / "languages.json"
    old = {m["code"]: m for m in json.loads(manifest_path.read_text(encoding="utf-8"))} if manifest_path.exists() else {}
    manifest = []
    for code, name, wikt, wf, dictdir, flag in LANGS:
        if only and code not in only and code in old:
            # not rebuilt: keep its word list and counts, refresh the rest
            manifest.append({**old[code], "name": name, "wikt": wikt, "flag": flag})
            continue
        lines, lengths, counts, kind = build(code, wf, dictdir, wikt)
        (OUT / f"{code}.txt").write_text("\n".join(lines), encoding="utf-8")
        manifest.append({"code": code, "name": name, "wikt": wikt, "flag": flag,
                         "lengths": lengths, "counts": counts, "filter": kind})
        print(code, name, kind, counts, file=sys.stderr)
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=1), encoding="utf-8")
    write_sources(manifest)


if __name__ == "__main__":
    main()
