"""How simulated players score on the logarithmic skill, to calibrate thresholds.

Two players on the English five-letter list (answer uniform on the words):

  strong  opens with the best-known openers and then always plays the consistent
          word that leaves the fewest words on average;
  casual  opens with a random common word and then plays a random consistent word.

Each guess is scored as in the app: skill = ln(N/E) / ln(N/E*), with E* the best
over a large set of real guesses (the common words, a random sample and the words
still possible; scanning every word at every step would take too long here, so E*
is slightly too high and the skills slightly too generous).

Usage:  python play_skill.py > results/play_skill.txt    (a few minutes)
"""
import math
import random
import statistics
import sys

from common import expected_pool, group_sizes, load_words, pattern

sys.stdout.reconfigure(encoding='utf-8')
rng = random.Random(7)
words = load_words('en', 5)
N0 = len(words)
common = words[:300]
FIRST_BEST_E = 114.36  # tares, from first_guess.py (exact over all words)


def log_skill(n, e, best):
    if n <= 1:
        return 100.0
    room = math.log(n / best)
    return 100.0 if room <= 1e-12 else max(0.0, min(100.0, math.log(n / e) / room * 100))


def best_e(left):
    cands = list(dict.fromkeys(common + rng.sample(words, 150) + left[:200]))
    return min(expected_pool(group_sizes(left, g)) for g in cands)


def play(strategy):
    answer = rng.choice(words)
    left = words
    skills = []
    for t in range(8):
        n = len(left)
        if strategy == 'strong':
            if t == 0:
                guess = rng.choice(['slate', 'tares', 'crane', 'trace', 'raise'])
            else:
                guess = min(left[:400], key=lambda w: expected_pool(group_sizes(left, w)))
        else:
            guess = rng.choice(common) if t == 0 else rng.choice(left)
        sizes = group_sizes(left, guess)
        e = expected_pool(sizes)
        best = FIRST_BEST_E if t == 0 else (1.0 if n <= 2 else best_e(left))
        skills.append(log_skill(n, e, best))
        if guess == answer:
            return skills, True
        m = pattern(answer, guess)
        left = [w for w in left if pattern(w, guess) == m]
    return skills, False


GAMES = 60
print(f'{GAMES} games each, answers uniform on {N0} words; skill is the logarithmic one\n')
for strategy in ('strong', 'casual'):
    results = [play(strategy) for _ in range(GAMES)]
    won = [s for s, ok in results if ok]
    every = [min(s) for s in won]
    mean = [statistics.fmean(s) for s in won]
    allg = [x for s, _ in results for x in s]
    print(f'{strategy}: won {len(won)} of {GAMES}; guesses per win {statistics.fmean(len(s) for s in won):.1f}')
    print(f'  per guess: median {statistics.median(allg):.0f}, mean {statistics.fmean(allg):.0f}, '
          f'share above 50/70/80/90: ' + ' / '.join(f'{sum(x > c for x in allg) / len(allg) * 100:.0f}%' for c in (50, 70, 80, 90)))
    print(f'  per won game, the average skill: median {statistics.median(mean):.0f}; '
          f'share of wins above 60/70/80: ' + ' / '.join(f'{sum(x > c for x in mean) / len(mean) * 100:.0f}%' for c in (60, 70, 80)))
    print(f'  per won game, the lowest guess:  median {statistics.median(every):.0f}; '
          f'share of wins with every guess above 50/60/70/80/90: '
          + ' / '.join(f'{sum(x > c for x in every) / len(every) * 100:.0f}%' for c in (50, 60, 70, 80, 90)))
    print()
