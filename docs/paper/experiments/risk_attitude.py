"""Does valuing risky splits help? Four ways to value a guess, played out.

A guess splits the N words still possible into groups of sizes s_i (p_i = s_i/N).
Four valuations, from cautious to adventurous, all with the same endpoints idea
(more is better), correspond to Renyi entropies of order alpha:

  worst     alpha = infinity  minimise the biggest group (the worst case)
  expected  alpha = 2         minimise E = sum(s^2)/N      (the app's skill)
  shannon   alpha = 1         maximise -sum p ln p          (information)
  groups    alpha = 0         maximise the number of groups (ignore their sizes)

The last two give a lot of credit to a guess that makes a few small groups even if
it leaves one big one (a gamble). For each valuation a greedy player picks the
guess it ranks best (its first guess over every word, later guesses among the
words still possible and a sample of common ones), the same answers for all, and
we record how many guesses it takes.

Usage:  python risk_attitude.py > results/risk_attitude.txt     (several minutes)
"""
import collections
import math
import random
import statistics
import sys
import time

from common import expected_pool, load_words, pattern

sys.stdout.reconfigure(encoding='utf-8')
words = load_words('en', 5)
N0 = len(words)
common = words[:150]

VALUATIONS = {
    'worst':    lambda s, n: -max(s),
    'expected': lambda s, n: -sum(x * x for x in s) / n,
    'shannon':  lambda s, n: -sum(x / n * math.log(x / n) for x in s),
    'groups':   lambda s, n: float(len(s)),
}


def sizes_of(left, guess):
    return list(collections.Counter(pattern(w, guess) for w in left).values())


def choose(left, valuation, candidates):
    n = len(left)
    best, best_score = None, -1e18
    for g in candidates:
        s = sizes_of(left, g)
        score = VALUATIONS[valuation](s, n)
        # ties go to a word that could be the answer
        if score > best_score + 1e-12 or (abs(score - best_score) <= 1e-12 and g in left_set(left)):
            best, best_score = g, score
    return best


_cache = {}


def left_set(left):
    key = id(left)
    if key not in _cache:
        _cache.clear()
        _cache[key] = set(left)
    return _cache[key]


start = time.time()
# the first guess is the same for every game: scan every word once
first_sizes = {g: sizes_of(words, g) for g in words}
print(f'N = {N0} five-letter English words, answers uniform; first guesses scanned over all words '
      f'({time.time() - start:.0f}s)')
firsts = {}
for name, f in VALUATIONS.items():
    g = max(words, key=lambda w: (f(first_sizes[w], N0), w in words[:3000]))
    firsts[name] = g

rng = random.Random(5)
GAMES = 1000
answers = [rng.choice(words) for _ in range(GAMES)]
print()
print(f'{GAMES} games per valuation, the same answers for all; shares with their standard errors')
print('valuation  first guess   E     groups  largest | guesses to solve: mean (se)   <=3        <=4        <=5        <=6   | unsolved')
for name in VALUATIONS:
    g1 = firsts[name]
    s1 = first_sizes[g1]
    counts = []
    for answer in answers:
        left = words
        guess = g1
        for t in range(1, 11):
            if guess == answer:
                counts.append(t)
                break
            m = pattern(answer, guess)
            left = [w for w in left if pattern(w, guess) == m]
            if len(left) == 1:
                guess = left[0]
                continue
            cands = list(dict.fromkeys(left[:150] + common[:100]))
            guess = choose(left, name, cands)
        else:
            counts.append(11)
    solved = [c for c in counts if c <= 10]
    def share(k):
        p = sum(c <= k for c in counts) / len(counts)
        return f'{p * 100:4.1f}+-{math.sqrt(p * (1 - p) / len(counts)) * 100:.1f}'
    se = statistics.pstdev(solved) / math.sqrt(len(solved))
    print(f'{name:>9}  {g1:>10} {expected_pool(s1):>6.1f} {len(s1):>7} {max(s1):>8} |'
          f' {statistics.fmean(solved):>13.2f} ({se:.2f}) {share(3):>9} {share(4):>10} {share(5):>10} {share(6):>10} |'
          f' {len(counts) - len(solved)}')
print(f'\n({time.time() - start:.0f}s in all)')
