"""Calibrating "boldness" of a guess and the thresholds of risk achievements.

The risk of a guess is the gap H - H2 between the Shannon and the collision
entropy of its split (bits): the part of its expected reduction that comes from
gambling. Its boldness is the percentile of that gap among every real guess
available in the same position (ties at their mid-rank). A strong and a casual
simulated player (as in play_skill.py) are scored; the script prints how their
boldness is distributed and what shares of games meet candidate thresholds.

Usage:  python boldness_calibration.py > results/boldness_calibration.txt
"""
import math
import random
import statistics
import sys

from common import group_sizes, load_words, pattern

sys.stdout.reconfigure(encoding='utf-8')
rng = random.Random(13)
words = load_words('en', 5)
common = words[:300]
LN2 = math.log(2)


def risk_bits(sizes):
    n = sum(sizes)
    e = sum(s * s for s in sizes) / n
    slogs = sum(s * math.log(s) for s in sizes) / n
    return (math.log(e) - slogs) / LN2


def boldness(left, guess, cands):
    mine = risk_bits(group_sizes(left, guess))
    risks = [risk_bits(group_sizes(left, g)) for g in cands]
    less = sum(r < mine - 1e-9 for r in risks)
    same = sum(abs(r - mine) <= 1e-9 for r in risks)
    return (less + same / 2) / len(risks) * 100


def play(strategy):
    answer = rng.choice(words)
    left = words
    out = []
    first = {'tares': None}
    for t in range(8):
        n = len(left)
        if strategy == 'strong':
            guess = rng.choice(['slate', 'tares', 'crane', 'trace', 'raise']) if t == 0 else \
                min(left[:300], key=lambda w: sum(s * s for s in group_sizes(left, w)))
        else:
            guess = rng.choice(common) if t == 0 else rng.choice(left)
        if n > 2:
            cands = list(dict.fromkeys(common + rng.sample(words, 120) + left[:150]))
            out.append(boldness(left, guess, cands))
        if guess == answer:
            break
        m = pattern(answer, guess)
        left = [w for w in left if pattern(w, guess) == m]
    return out


GAMES = 60
print(f'{GAMES} games per player; boldness = percentile of the gap H - H2 among real guesses\n')
for strategy in ('strong', 'casual'):
    games = [g for g in (play(strategy) for _ in range(GAMES)) if len(g) >= 2]
    allg = [x for g in games for x in g]
    avg = [statistics.fmean(g) for g in games]
    print(f'{strategy}: {len(games)} games with at least two scored guesses')
    print(f'  per guess: median {statistics.median(allg):.0f}, mean {statistics.fmean(allg):.0f}, '
          f'share above 70 / below 30: {sum(x > 70 for x in allg) / len(allg) * 100:.0f}% / '
          f'{sum(x < 30 for x in allg) / len(allg) * 100:.0f}%')
    print(f'  per game, the average: median {statistics.median(avg):.0f}; share above 60/65/70/75: '
          + ' / '.join(f'{sum(a > c for a in avg) / len(avg) * 100:.0f}%' for c in (60, 65, 70, 75)))
    print(f'  per game, every guess below 30/35/40/45: '
          + ' / '.join(f'{sum(max(g) < c for g in games) / len(games) * 100:.0f}%' for c in (30, 35, 40, 45)))
    print()
