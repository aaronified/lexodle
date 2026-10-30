"""Builds assets/geography/places.tsv, the place names of the themed wordle.

Input: a folder with the GeoNames dump files (https://download.geonames.org/export/dump/):
allCountries.txt, alternateNamesV2.txt, countryInfo.txt. Run:

    python tools/build_geography.py <geonames folder>

A place is kept when it is a country, a first-level region, a city of at least
15,000 people (or a capital), or a named water or land feature. Its name is the English one (the preferred English name of
GeoNames, else its ASCII name), reduced to letters a-z with spaces and accents
removed, so "Rio de Janeiro" is riodejaneiro. Names of 4 to 8 letters stay.

Each name is in the "well known" tier when it is a country, a capital, a city
of at least 500,000 people, a region with a Wikipedia page, a sea or ocean, or
any other feature with names in at least 6 languages.
"""

import collections
import re
import sys
import unicodedata
from pathlib import Path

LENGTHS = range(4, 9)
CITY_MIN = 15_000
KNOWN_CITY = 500_000
KNOWN_LANGS = 6
# a feature without an English Wikipedia page needs names in this many languages
OBSCURE_LANGS = 2

# GeoNames feature code -> what the info dot calls it
KINDS = {
    'STM': 'river', 'LK': 'lake', 'LKS': 'lakes', 'SEA': 'sea', 'OCN': 'ocean',
    'BAY': 'bay', 'GLF': 'gulf', 'STRT': 'strait', 'CHN': 'channel',
    'FJD': 'fjord', 'LGN': 'lagoon', 'FLLS': 'waterfall', 'RSV': 'reservoir',
    'CNL': 'canal', 'MT': 'mountain', 'MTS': 'mountains', 'PK': 'peak',
    'VLC': 'volcano', 'RGN': 'region', 'DSRT': 'desert', 'ISL': 'island',
    'ISLS': 'islands', 'PEN': 'peninsula', 'CAPE': 'cape', 'VAL': 'valley',
    'PLAT': 'plateau', 'RNG': 'mountain range', 'PASS': 'pass',
    'GLCR': 'glacier', 'FRST': 'forest', 'RF': 'reef', 'ATOL': 'atoll',
    'CLF': 'cliff', 'HLL': 'hill', 'PLN': 'plain', 'DLTA': 'delta',
    'OAS': 'oasis', 'BCH': 'beach', 'CST': 'coast', 'PT': 'point',
}
PHYSICAL = set(KINDS)
SEAS = {'SEA', 'OCN'}


def letters(name):
    name = unicodedata.normalize('NFKD', name)
    name = ''.join(c for c in name if not unicodedata.combining(c))
    return re.sub(r'[^a-z]', '', name.lower())


def english_names(path, wanted):
    """geonameid -> English name (preferred first), geonameid -> Wikipedia title,
    and geonameid -> how many languages have a name for it."""
    en, wiki, langs = {}, {}, collections.defaultdict(set)
    for line in open(path, encoding='utf8'):
        f = line.rstrip('\n').split('\t')
        if len(f) < 4 or f[1] not in wanted:
            continue
        if f[2] == 'link' and 'en.wikipedia.org/wiki/' in f[3]:
            wiki[f[1]] = f[3].split('/wiki/', 1)[1]
        elif 2 <= len(f[2]) <= 3:
            langs[f[1]].add(f[2])
            if f[2] != 'en':
                continue
            preferred = len(f) > 4 and f[4] == '1'
            colloquial = len(f) > 5 and f[5] == '1'
            if colloquial:
                continue
            if preferred or f[1] not in en:
                en[f[1]] = f[3]
    return en, wiki, {k: len(v) for k, v in langs.items()}


def main(folder):
    folder = Path(folder)
    countries = {}
    for line in open(folder / 'countryInfo.txt', encoding='utf8'):
        if line.startswith('#'):
            continue
        f = line.rstrip('\n').split('\t')
        if len(f) > 4:
            countries[f[0]] = f[4]
    rows = []
    for line in open(folder / 'allCountries.txt', encoding='utf8'):
        f = line.split('\t')
        fc, code, pop = f[6], f[7], int(f[14] or 0)
        kind = None
        if code.startswith('PCL') or code == 'TERR':
            kind = 'country'
        elif code in ('ADM1', 'ADM2') and (code == 'ADM1' or pop >= 50_000):
            kind = 'region'
        elif code == 'PPLC':
            kind = 'capital'
        elif fc == 'P' and pop >= CITY_MIN:
            kind = 'city'
        elif code in PHYSICAL:
            kind = KINDS[code]
        if kind:
            rows.append((f[0], f[1], f[2], kind, code, pop, f[8]))
    wanted = {r[0] for r in rows}
    en, wiki, langs = english_names(folder / 'alternateNamesV2.txt', wanted)
    best = {}
    for gid, name, ascii_, kind, code, pop, cc in rows:
        physical = code in PHYSICAL
        if physical and gid not in wiki and langs.get(gid, 0) < OBSCURE_LANGS:
            continue
        if kind == 'country' and gid in en:
            shown = en[gid]
        else:
            shown = en.get(gid) or ascii_ or name
        key = letters(shown)
        if len(key) not in LENGTHS:
            continue
        known = (kind in ('country', 'capital')
                 or (kind == 'city' and pop >= KNOWN_CITY)
                 or (kind == 'region' and gid in wiki)
                 or code in SEAS
                 or (physical and langs.get(gid, 0) >= KNOWN_LANGS))
        rank = (known, langs.get(gid, 0), pop)
        row = (key, shown, kind, countries.get(cc, ''), 'k' if known else 'a',
               wiki.get(gid, ''))
        if key not in best or rank > best[key][0]:
            best[key] = (rank, row)
    out = Path(__file__).resolve().parent.parent / 'assets' / 'geography'
    out.mkdir(parents=True, exist_ok=True)
    with open(out / 'places.tsv', 'w', encoding='utf8') as w:
        for key in sorted(best, key=lambda k: (len(k), k)):
            w.write('\t'.join(best[key][1]) + '\n')
    c = collections.Counter((len(k), best[k][1][4]) for k in best)
    for n in LENGTHS:
        print(n, 'all', c[n, 'a'] + c[n, 'k'], 'well known', c[n, 'k'])


if __name__ == '__main__':
    main(sys.argv[1])
