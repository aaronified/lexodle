"""Exact expected pool E(g) of every English five-letter word as a first guess.

Reads the word list the app ships (app/assets/words/en.txt, five-letter words,
most common first) and, for every word g, partitions the whole list by the
feedback g would give, then reports E(g) = sum(s^2)/N, the number of groups, the
largest group, and the skill of g against the best real guess.

Usage:  python first_guess.py  >  first_guess.json
"""
import collections, json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
WORDS = os.path.join(HERE, '..', '..', '..', 'app', 'assets', 'words', 'en.txt')
words = [l.split('\t')[0] for l in open(WORDS, encoding='utf-8') if len(l.split('\t')[0]) == 5]
L, N = 5, len(words)


def pattern(target, guess):
    """Feedback of `guess` against `target`, base 3 (0 grey, 1 yellow, 2 green)."""
    r = [0] * L
    rem = collections.Counter()
    for i in range(L):
        if guess[i] == target[i]:
            r[i] = 2
        else:
            rem[target[i]] += 1
    for i in range(L):
        if r[i] == 0 and rem[guess[i]] > 0:
            r[i] = 1
            rem[guess[i]] -= 1
    k = 0
    for v in r:
        k = k * 3 + v
    return k


rows = []
for g in words:
    groups = collections.Counter(pattern(w, g) for w in words)
    sizes = sorted(groups.values(), reverse=True)
    rows.append({'word': g, 'E': sum(s * s for s in sizes) / N, 'groups': len(sizes), 'largest': sizes[0]})
best = min(r['E'] for r in rows)
for r in rows:
    r['skill'] = (N - r['E']) / (N - best) * 100
rows.sort(key=lambda r: r['E'])
json.dump({'N': N, 'E_best': best, 'best_word': rows[0]['word'], 'words': rows}, sys.stdout)
