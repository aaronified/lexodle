"""Builds the word lists of the themed wordle (assets/themes/*.tsv and themes.json).

A theme is a list of words with the subthemes each belongs to. The game draws the
answer from one subtheme and accepts a guess from the whole theme; the subtheme
"all" is every word. Common words only (a proper noun has no frequency in the
English list: mythology and names have their own builds).

Sources, English only:
  - WordNet 3.0 (Princeton, its own licence: see assets/themes/NOTICE.md): the
    words under a few chosen senses (animal, bird, bone, ...). A word counts only
    when that sense is one of its two commonest, so "ball" is not a body part and
    "pencil" is not mathematics.
  - the English Wiktionary's topic categories (CC BY-SA 4.0), read from its dumps
    by wiktionary_topics.py: the entries of a few specific categories, a level or
    two down.
  - assets/words/en.txt, for what a word is worth: a word must be in it, and its
    count is the word's weight. That list holds only words people use, which is
    what keeps an obscure entry out of an answer.

A word is kept when it is a lowercase single word of 4 to 8 letters a to z, is not
a swear word or an abbreviation (swears.py, abbreviations.py) and is not on
themes/deny.txt. themes/allow.txt adds a word to a subtheme by hand.

Run:  python3 tools/build_themes.py          (reads tools/dictionaries/…, writes assets/themes)
      python3 tools/build_themes.py --check  (the roots, with what they mean)
"""
import collections
import json
import re
import sys
import urllib.request
import zipfile
from pathlib import Path

import abbreviations
import swears

APP = Path(__file__).resolve().parent.parent
DICT = Path(__file__).resolve().parent / "dictionaries"
OUT = APP / "assets" / "themes"
HAND = Path(__file__).resolve().parent / "themes"
LENGTHS = range(4, 9)
WORDNET_URL = "https://raw.githubusercontent.com/nltk/nltk_data/gh-pages/packages/corpora/wordnet.zip"

# Wiktionary sub-categories that bring in words that are not of the topic
WK_SKIP = ("thesaurus", "by_language", "terms_by", "translingual", "entries", "lemmas", "forms",
           "etymology", "rhymes", "pronunciation", "veterinary", "bestiality", "animal_body_parts",
           "baby_animals", "male_animals", "female_animals", "biomolecules", "genitalia", "eggs",
           "feathers", "mathematicians", "cryptography", "cellular_automata", "appendices")


def slug(name):
    """A subtheme's id in the files: letters and digits, joined by underscores."""
    return re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")


def S(label, wn=(), wk=(), domain=(), hidden=False):
    """A subtheme: WordNet roots (lemma, sense), Wiktionary roots (category, depth) and
    WordNet domain roots (words whose topic is that sense). A hidden one is not offered:
    its words are in the theme (so a guess may be one of them), in no subtheme."""
    return dict(label=label, wn=list(wn), wk=[(c, d) for c, d in wk], domain=list(domain), hidden=hidden)


THEMES = {
    "living": dict(title="living world", subs={
        "animals": S("all animals", wn=[("animal", 1)], wk=[("en:Animals", 1)]),
        "mammals": S("mammals", wn=[("mammal", 1)], wk=[("en:Mammals", 2)]),
        "birds": S("birds", wn=[("bird", 1)], wk=[("en:Birds", 2)]),
        "fish": S("fish", wn=[("fish", 1)], wk=[("en:Fish", 2)]),
        "reptiles and amphibians": S("reptiles & amphibians", wn=[("reptile", 1), ("amphibian", 3)],
                                     wk=[("en:Reptiles", 2), ("en:Amphibians", 2)]),
        "insects and spiders": S("insects & spiders", wn=[("insect", 1), ("arachnid", 1)],
                                 wk=[("en:Insects", 2), ("en:Arachnids", 2)]),
        "other animals": S("shellfish, worms & more", wn=[("mollusk", 1), ("crustacean", 1), ("worm", 1)],
                           wk=[("en:Mollusks", 2), ("en:Worms", 2), ("en:Arthropods", 1)]),
        "dogs and cats": S("dogs & cats", wn=[("dog", 1), ("domestic_cat", 1), ("big_cat", 1)],
                           wk=[("en:Dogs", 2), ("en:Cats", 2)]),
        "microbes and fungi": S("microbes & fungi", wn=[("bacterium", 1), ("virus", 1), ("microorganism", 1),
                                                        ("protozoan", 1), ("fungus", 1), ("alga", 1)],
                                wk=[("en:Bacteria", 1), ("en:Viruses", 1), ("en:Fungi", 2)]),
        "plants": S("all plants", wn=[("plant", 2)], wk=[("en:Plants", 1), ("en:Herbs", 1)]),
        "trees": S("trees", wn=[("tree", 1), ("shrub", 1)], wk=[("en:Trees", 2)]),
        "flowers": S("flowers", wn=[("flower", 2)], wk=[("en:Flowers", 2)]),
        "fruits": S("fruits", wn=[("edible_fruit", 1), ("berry", 1), ("citrus", 1), ("melon", 1)],
                    wk=[("en:Fruits", 2)]),
        "vegetables": S("vegetables", wn=[("vegetable", 1)], wk=[("en:Vegetables", 2)]),
    }),
    "food": dict(title="food", subs={
        "fruits": S("fruits", wn=[("edible_fruit", 1), ("berry", 1), ("citrus", 1), ("melon", 1)],
                    wk=[("en:Fruits", 2)]),
        "vegetables": S("vegetables", wn=[("vegetable", 1)], wk=[("en:Vegetables", 2)]),
        "meat, seafood and dairy": S("meat, seafood & dairy", wn=[("meat", 1), ("seafood", 1), ("fish", 2), ("bird", 2),
                                                              ("dairy_product", 1), ("cheese", 1)],
                                     wk=[("en:Meats", 2), ("en:Seafood", 2), ("en:Cheeses", 1), ("en:Milk", 1)]),
        "grains and bread": S("grains & bread", wn=[("cereal", 2), ("bread", 1), ("pastry", 2), ("pasta", 2)],
                              wk=[("en:Breads", 1), ("en:Grains", 1), ("en:Pasta", 1), ("en:Cakes_and_pastries", 1)]),
        "sweets and desserts": S("sweets & desserts", wn=[("dessert", 1), ("candy", 1), ("sweet", 3), ("cake", 3), ("cookie", 1)],
                                 wk=[("en:Desserts", 1), ("en:Ice_cream", 1)]),
        "drinks": S("drinks", wn=[("beverage", 1)], wk=[("en:Beverages", 2)]),
        "spices and herbs": S("spices & herbs", wn=[("spice", 2), ("herb", 2), ("condiment", 1)],
                              wk=[("en:Seasonings", 1), ("en:Condiments", 1), ("en:Sauces", 1)]),
        "dishes": S("dishes", wn=[("dish", 2), ("soup", 1), ("salad", 1), ("sandwich", 1), ("pasta", 1), ("sauce", 1)],
                    wk=[("en:Soups", 1), ("en:Salads", 1), ("en:Sandwiches", 1), ("en:Meals", 1)]),
        "other foods": S("other foods", wn=[("food", 2), ("food", 1)], wk=[("en:Foods", 1)], hidden=True),
    }),
    "minerals": dict(title="minerals & elements", subs={
        "elements and metals": S("elements & metals", wn=[("chemical_element", 1), ("metal", 1), ("alloy", 1)],
                                 wk=[("en:Chemical_elements", 0), ("en:Metals", 1)]),
        "minerals, rocks and gems": S("minerals, rocks & gems", wn=[("mineral", 1), ("ore", 1), ("gem", 2), ("precious_stone", 1), ("rock", 1)],
                                      wk=[("en:Minerals", 0), ("en:Birthstones", 1), ("en:Rocks", 1)]),
    }),
    "anatomy": dict(title="anatomy", subs={
        "bones, joints and muscles": S("bones, joints & muscles", wn=[("bone", 1), ("joint", 1), ("skeleton", 3), ("muscle", 1)],
                                       wk=[("en:Skeleton", 1), ("en:Muscles", 1)]),
        "organs, nerves and blood": S("organs, nerves & blood", wn=[("organ", 1), ("gland", 1), ("nerve", 1), ("brain", 1), ("blood_vessel", 1)],
                                      wk=[("en:Organs", 1), ("en:Brain", 1), ("en:Nerves", 1), ("en:Blood", 1)]),
        "teeth, skin and hair": S("teeth, skin & hair", wn=[("tooth", 1), ("skin", 1)],
                                  wk=[("en:Teeth", 1), ("en:Skin", 1), ("en:Hair", 1)]),
        "the rest of the body": S("head, limbs & trunk", wn=[("body_part", 1)], wk=[("en:Body_parts", 1), ("en:Head_and_neck", 1), ("en:Arms", 1), ("en:Legs", 1), ("en:Chest", 1)]),
    }),
    "math": dict(title="math", subs={
        "geometry": S("geometry", wn=[("plane_figure", 1), ("polygon", 1), ("solid", 3), ("curve", 1)],
                      domain=[("geometry", 1)], wk=[("en:Geometry", 1)]),
        "algebra, calculus and statistics": S("algebra, calculus & statistics",
                                              domain=[("algebra", 1), ("calculus", 3), ("trigonometry", 1), ("statistics", 1)],
                                              wk=[("en:Algebra", 1), ("en:Mathematical_analysis", 1), ("en:Complex_analysis", 1),
                                                  ("en:Measure_theory", 1), ("en:Trigonometry", 1), ("en:Statistics", 1)]),
        "numbers": S("numbers", wn=[("number", 2)], domain=[("arithmetic", 1)], wk=[("en:Arithmetic", 1), ("en:Number_theory", 1), ("en:Quantity", 1)]),
        "logic and sets": S("logic & sets", domain=[("logic", 1), ("set", 2)],
                            wk=[("en:Set_theory", 1), ("en:Combinatorics", 1), ("en:Graph_theory", 1), ("en:Topology", 1), ("en:Paradoxes", 1)]),
    }),
}
THEMES["math"]["subs"]["other math"] = S("other math", domain=[("mathematics", 1)], wk=[("en:Mathematics", 0)], hidden=True)


# ---------------------------------------------------------------- WordNet
def load_wordnet():
    d = DICT / "wordnet"
    if not (d / "data.noun").exists():
        DICT.mkdir(parents=True, exist_ok=True)
        z = DICT / "wordnet.zip"
        print("downloading WordNet…", file=sys.stderr)
        req = urllib.request.Request(WORDNET_URL, headers={"User-Agent": "lexodle-build/1.0"})
        z.write_bytes(urllib.request.urlopen(req, timeout=120).read())
        zipfile.ZipFile(z).extractall(DICT)
    syn = {}  # offset -> (words, gloss, [(symbol, target)])
    for line in open(d / "data.noun", encoding="utf8"):
        if line.startswith("  "):
            continue
        head, _, gloss = line.partition("|")
        f = head.split()
        wc = int(f[3], 16)
        words = [f[4 + 2 * i] for i in range(wc)]
        p = 4 + 2 * wc
        ptrs = []
        for i in range(int(f[p])):
            sym, tgt, pos = f[p + 1 + 4 * i: p + 4 + 4 * i]
            if pos == "n":
                ptrs.append((sym, tgt))
        syn[f[0]] = (words, gloss.strip(), ptrs)
    idx = {}  # lemma -> synset offsets, commonest sense first
    for line in open(d / "index.noun", encoding="utf8"):
        if line.startswith("  "):
            continue
        f = line.split()
        idx[f[0]] = f[6 + int(f[3]):6 + int(f[3]) + int(f[2])]
    tags = {}  # (offset, lemma) -> how often that sense was seen in text (SemCor)
    for line in open(d / "index.sense", encoding="utf8"):
        key, off, _, cnt = line.split()
        tags[(off, key.split("%")[0])] = int(cnt)
    down, members = collections.defaultdict(set), collections.defaultdict(set)
    for off, (_, _, ptrs) in syn.items():
        for sym, tgt in ptrs:
            if sym in ("@", "@i"):
                down[tgt].add(off)
            elif sym == ";c":
                members[tgt].add(off)
    return syn, idx, down, members, tags


def closure(down, roots, members=None):
    seen, stack = set(), list(roots)
    while stack:
        o = stack.pop()
        if o in seen:
            continue
        seen.add(o)
        stack += down.get(o, ())
        if members is not None:
            stack += members.get(o, ())
    return seen


# ---------------------------------------------------------------- the lists
# WordNet puts people (human, female, soldier) under animals, and "kinds of" sometimes lead
# to the shapes, tools and slang of a theme: whole subtrees that are never of a theme
PRUNE = [("person", 1), ("juvenile", 1), ("adult", 1), ("worker", 1), ("slang", 1)]

# a word among this many of the commonest is generic: it counts for a theme only when
# its first meaning is of the theme (head, back, hand: yes; part, side, more: no)
COMMON = 2000
# a word only the Wiktionary names, for a sense of its own, must be rarer than this
WK_ONLY_AFTER = 3000


def frequency():
    # (the file is grouped by length, each group by count: the rank is by count)
    freq = {}
    for line in open(APP / "assets" / "words" / "en.txt", encoding="utf8"):
        p = line.split()
        if len(p) >= 2:
            freq[p[0]] = int(p[1])
    rank = {w: i + 1 for i, w in enumerate(sorted(freq, key=lambda w: -freq[w]))}
    return freq, rank


def hand(name):
    f = HAND / name
    out = []
    if f.exists():
        for line in f.read_text(encoding="utf8").splitlines():
            line = line.split("#")[0].strip()
            if line:
                out.append(line)
    return out


def fits(w, freq, deny):
    return (re.fullmatch(r"[a-z]{4,8}", w) and w in freq and w not in deny
            and not swears.is_swear("en", w) and not abbreviations.is_abbreviation("en", w))


def wiktionary_words(topics, roots):
    """The entries under the Wiktionary categories [(category, depth)], a level at a time."""
    pages, subs = topics["pages"], topics["subs"]
    got = set()
    for root, depth in roots:
        seen, frontier = {root}, [root]
        for level in range(depth + 1):
            nxt = []
            for c in frontier:
                got.update(pages.get(c, ()))
                for s in subs.get(c, ()):
                    if s not in seen and not any(k in s.lower() for k in WK_SKIP):
                        seen.add(s)
                        nxt.append(s)
            frontier = nxt
    return got


def main():
    check = "--check" in sys.argv
    syn, idx, down, members, tags = load_wordnet()

    def root(lemma, k):
        return idx[lemma][k - 1]

    if check:
        for t in THEMES.values():
            for s in t["subs"].values():
                for lemma, k in s["wn"] + s["domain"]:
                    o = root(lemma, k)
                    print(f"{lemma}.{k}: {syn[o][0][:3]} :: {syn[o][1][:70]}")
        return
    topics_file = DICT / "wiktionary-topics.json"
    topics = json.loads(topics_file.read_text(encoding="utf8")) if topics_file.exists() else {"pages": {}, "subs": {}}
    if not topics["pages"]:
        print("no tools/dictionaries/wiktionary-topics.json (python wiktionary_topics.py): WordNet only", file=sys.stderr)
    freq, rank = frequency()
    pruned = closure(down, [root(l, k) for l, k in PRUNE if l in idx])
    deny = set(hand("deny.txt"))
    allow = collections.defaultdict(set)  # (theme, subtheme) -> words
    for line in hand("allow.txt"):
        theme, sub, word = line.split(None, 2)
        allow[(theme, sub)].add(word)
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = []
    for tid, theme in THEMES.items():
        members_of = {}  # subtheme -> {word}
        wk_theme = set()
        for s in theme["subs"].values():
            wk_theme |= wiktionary_words(topics, s["wk"])
        for sid, s in theme["subs"].items():
            offs = closure(down, [root(l, k) for l, k in s["wn"]])
            offs |= closure(down, [root(l, k) for l, k in s["domain"]], members) if s["domain"] else set()
            offs -= pruned
            words = set()
            for o in offs:
                for w in syn[o][0]:
                    if w != w.lower() or not w.isalpha():
                        continue
                    if not fits(w, freq, deny):
                        continue
                    senses = idx.get(w, [])
                    if rank[w] <= COMMON:
                        # a generic word: the theme must be what it first means
                        if senses[:1] == [o]:
                            words.add(w)
                    elif o in senses[:2]:
                        # one of the two commonest senses; a word with other senses
                        # needs its sense seen in text, or a Wiktionary topic category
                        # of this theme naming it too: no "pacer", no "homer"
                        if len(senses) == 1 or tags.get((o, w), 0) > 0 or w in wk_theme:
                            words.add(w)
            for t in wiktionary_words(topics, s["wk"]):
                w = t
                if w == w.lower() and fits(w, freq, deny) and rank[w] > WK_ONLY_AFTER:
                    words.add(w)
            words |= {w for w in allow[(tid, sid)] if fits(w, freq, deny)}
            members_of[sid] = words
        everything = set().union(*members_of.values())
        shown = {sid: s for sid, s in theme["subs"].items() if not s["hidden"]}
        rows = sorted(everything, key=lambda w: (-freq[w], w))
        with open(OUT / f"{tid}.tsv", "w", encoding="utf8") as f:
            for w in rows:
                subs = [slug(sid) for sid in shown if w in members_of[sid]]
                f.write(f"{w}\t{','.join(subs)}\t{freq[w]}\n")
        entry = {"id": tid, "title": theme["title"], "subs": [
            {"id": "all", "label": "all", "counts": dict(sorted(collections.Counter(len(w) for w in everything).items()))}]}
        for sid, s in shown.items():
            entry["subs"].append({"id": slug(sid), "label": s["label"],
                                  "counts": dict(sorted(collections.Counter(len(w) for w in members_of[sid]).items()))})
        manifest.append(entry)
        print(f"{tid:9} {len(rows):>5} words   " + "  ".join(f"{sid}:{len(members_of[sid])}" for sid in shown))
    (OUT / "themes.json").write_text(json.dumps({"themes": manifest}, indent=1), encoding="utf8")


if __name__ == "__main__":
    main()
