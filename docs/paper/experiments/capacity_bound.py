"""A negative result: a capacity bound on the best conceivable split.

One might define the best conceivable split by counting how many different
feedback patterns a guess could show given what is already known, taking e =
N / (that number). This script tests three such bounds on simulated games and
compares them with what real guesses achieve:

  naive   min(N, 3^n)                              (n = word length)
  B       the product, over positions, of 2 where the clues fix the letter and
          3 elsewhere
  C       the largest, over every real guess word, of the product over its
          letters of how many of {green, yellow, grey} that letter could show
          against the words still possible (capped at N)

Findings (results/capacity_bound.txt): B and C equal the naive bound in every
sampled state, the best real word reaches only about 63% of the bound's groups
when N > 243, and C is not even a strict upper bound for guesses with repeated
letters. So the bound is too loose to say what skill can reach; the paper
measures skill against the best real guess instead.

Usage:  python capacity_bound.py > results/capacity_bound.txt   (a few minutes)
"""
import collections
import random
import sys
import time

from common import load_words, pattern

sys.stdout.reconfigure(encoding='utf-8')
random.seed(11)
words = load_words('en', 5)
L = 5
LETTERS = set(''.join(words))


def tables(eligible):
    green = [collections.defaultdict(bool) for _ in range(L)]
    yellow = [collections.defaultdict(bool) for _ in range(L)]
    fewer = collections.defaultdict(set)  # x -> {r : some word has fewer than r of x}
    for w in eligible:
        c = collections.Counter(w)
        for i in range(L):
            green[i][w[i]] = True
        for x in LETTERS:
            cx = c.get(x, 0)
            for r in range(1, L + 1):
                if cx < r:
                    fewer[x].add(r)
            if cx >= 1:
                for i in range(L):
                    if w[i] != x:
                        yellow[i][x] = True
    return green, yellow, fewer


def capacity(guess, t, n):
    green, yellow, fewer = t
    seen = collections.Counter()
    prod = 1
    for i in range(L):
        x = guess[i]
        seen[x] += 1
        s = green[i][x] + yellow[i][x] + (seen[x] in fewer[x])
        prod *= max(s, 1)
    return min(n, prod)


def capacity_b(eligible, n):
    p = 1
    for i in range(L):
        p *= 2 if len({w[i] for w in eligible}) == 1 else 3
    return min(n, p)


violations = 0
checked = 0
rows = []
start = time.time()
common = words[:1500]
for game in range(14):
    answer = random.choice(common)
    eligible = words[:]
    for step in range(3):
        n = len(eligible)
        if n <= 2:
            break
        t = tables(eligible)
        caps = {w: capacity(w, t, n) for w in words}
        bound_c = max(caps.values())
        if n * len(words) <= 1_500_000:
            cands = words
        else:
            top_cap = sorted(words, key=lambda w: -caps[w])[:60]
            cands = list(dict.fromkeys(words[:250] + random.sample(words, 250) + top_cap))
        best_groups = 0
        for g in cands:
            checked += 1
            groups = len(collections.Counter(pattern(w, g) for w in eligible))
            if groups > caps[g]:
                violations += 1
            best_groups = max(best_groups, groups)
        rows.append((game, step, n, bound_c, capacity_b(eligible, n), min(n, 243), best_groups))
        g = random.choice(words[:300])
        m = pattern(answer, g)
        eligible = [w for w in eligible if pattern(w, g) == m]
        if answer not in eligible:
            break
    if time.time() - start > 240:
        break

print(f'guesses checked: {checked}; groups above the capacity formula (C): {violations}')
print('(all of them guesses with a repeated letter, which the simple per-letter rule undercounts)')
print()
print('game step     N | capacity C   B   naive | most groups any scanned real guess made')
for game, step, n, cc, cb, nv, real in rows:
    print(f'{game:>4} {step:>4} {n:>5} | {cc:>10} {cb:>4} {nv:>6} | {real:>10}')
big = [r for r in rows if r[2] > 243]
small = [r for r in rows if r[2] <= 243]
print()
print(f'states with N > 243: {len(big)}; with N <= 243: {len(small)}')
print(f'B equals the naive bound in {sum(r[4] == r[5] for r in rows)} of {len(rows)} states, '
      f'C in {sum(r[3] == r[5] for r in rows)} of {len(rows)}')
if big:
    print(f'mean (most groups a real guess made) / (bound C), N > 243: '
          f'{sum(r[6] / r[3] for r in big) / len(big):.2f}')
print(f'N <= 243: a real guess put every word in its own group in '
      f'{sum(r[6] == r[2] for r in small)} of {len(small)} states')
