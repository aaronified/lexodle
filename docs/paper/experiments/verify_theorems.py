"""Numerical checks of the claims in the paper, independent of the app's code.

  1. Example 1 (twenty words in groups of 10, 5, 3, 1, 1).
  2. On random partitions: luck is strictly between -1 and 1, strictly decreasing in
     the pool, scale invariant, has mean exactly 0 and variance (1 - sum q^3)/3.
  3. Proposition 5: the counterexamples to the other two luck definitions.
  4. Theorem 4 on simulated games: with the answer uniform on the words and a
     player whose guesses depend only on the past, the luck of each guess has mean
     zero and is uncorrelated with the skill of every guess so far and with the
     luck of the guesses before it.

Usage:  python verify_theorems.py > results/verify_theorems.txt   (about a minute)
"""
import math
import random
import statistics
import sys

from common import chance_luck, expected_pool, group_sizes, linear_skill, load_words, pattern, skill

sys.stdout.reconfigure(encoding='utf-8')
rng = random.Random(2026)
failures = []


def check(name, ok, detail=''):
    print(('ok    ' if ok else 'FAIL  ') + name + (f'   {detail}' if detail else ''))
    if not ok:
        failures.append(name)


def luck(sizes, landed):
    return chance_luck(sizes, landed) / 100


# 1. Example 1
sizes = [10, 5, 3, 1, 1]
check('Example 1: E = 6.8', abs(expected_pool(sizes) - 6.8) < 1e-12)
check('Example 1: skill with E* = 1 is 36.0 (log) and 69.5 (linear)',
      abs(skill(20, 6.8, 1) - 36.0116) < 1e-3 and abs(linear_skill(20, 6.8, 1) - 69.4737) < 1e-3)
want = {10: -0.50, 5: 0.25, 3: 0.65, 1: 0.90}
check('Example 1: luck -50, +25, +65, +90', all(abs(luck(sizes, k) - v) < 1e-12 for k, v in want.items()))
check('Example 1: mean luck 0', abs(sum(s / 20 * luck(sizes, s) for s in sizes)) < 1e-12)

# 2. random partitions
worst_mean = worst_var = 0.0
bounded = decreasing = scale_ok = True
for _ in range(20000):
    k = rng.randint(1, 40)
    sz = [rng.randint(1, 400) for _ in range(k)]
    n = sum(sz)
    values = sorted(set(sz), reverse=True)
    q = {x: x * sz.count(x) / n for x in values}
    lucks = {x: luck(sz, x) for x in values}
    mean = sum(q[x] * lucks[x] for x in values)
    var = sum(q[x] * lucks[x] ** 2 for x in values) - mean ** 2
    formula = (1 - sum(v ** 3 for v in q.values())) / 3
    worst_mean = max(worst_mean, abs(mean))
    worst_var = max(worst_var, abs(var - formula))
    bounded &= all(-1 < lucks[x] < 1 or (len(values) == 1 and lucks[x] == 0) for x in values)
    decreasing &= all(lucks[values[i]] < lucks[values[i + 1]] for i in range(len(values) - 1))
    c = rng.randint(2, 9)
    scaled = [s * c for s in sz]
    scale_ok &= all(abs(luck(scaled, x * c) - lucks[x]) < 1e-12 for x in values)
check('20,000 partitions: |mean luck| <= 1e-12', worst_mean < 1e-12, f'worst {worst_mean:.2e}')
check('20,000 partitions: variance equals (1 - sum q^3)/3', worst_var < 1e-12, f'worst {worst_var:.2e}')
check('20,000 partitions: luck strictly inside (-1, 1)', bounded)
check('20,000 partitions: luck strictly increases as the pool shrinks', decreasing)
check('20,000 partitions: scaling every class changes nothing', scale_ok)

# 3. counterexamples
for n in (10, 100, 1000):
    pair = [2] + [1] * (n - 2)
    e = expected_pool(pair)
    exp_luck = (e - 2) / (e - 1)
    check(f'expectation luck of the pair among {n - 2} singletons is -(N-2)/2',
          abs(exp_luck + (n - 2) / 2) < 1e-6, f'{exp_luck:.1f}')
sz = [3, 1]
e = expected_pool(sz)
res = {a: ((e - a) / (e - 1) if a <= e else (e - a) / (max(sz) - e)) for a in sz}
mean_res = sum(a / 4 * res[a] for a in sz)
check('rescaled luck of {3,1}: -1 and +1, mean -1/2',
      abs(res[3] + 1) < 1e-12 and abs(res[1] - 1) < 1e-12 and abs(mean_res + 0.5) < 1e-12)
check('chance luck of {3,1}: -25% and +75%, mean 0',
      abs(luck(sz, 3) + 0.25) < 1e-12 and abs(luck(sz, 1) - 0.75) < 1e-12)

# 4. Theorem 4 on simulated games
words = load_words('en', 5)
common = words[:300]
GAMES, GUESSES = 1500, 4
lucks = [[] for _ in range(GUESSES)]
skills = [[] for _ in range(GUESSES)]
for _ in range(GAMES):
    answer = rng.choice(words)  # uniform, as assumption (U)
    left = words
    for t in range(GUESSES):
        if len(left) < 2:
            lucks[t].append(0.0)
            skills[t].append(1.0)
            continue
        # the player's guess depends only on the past: common words, then a consistent one
        guess = rng.choice(common) if t < 2 else rng.choice(left)
        sz = group_sizes(left, guess)
        n = len(left)
        e = expected_pool(sz)
        landed = sum(1 for w in left if pattern(w, guess) == pattern(answer, guess))
        lucks[t].append(luck(sz, landed))
        skills[t].append((n - e) / (n - 1))  # absolute skill: any past-measurable number will do
        left = [w for w in left if pattern(w, guess) == pattern(answer, guess)]


def corr(a, b):
    ma, mb = statistics.fmean(a), statistics.fmean(b)
    num = sum((x - ma) * (y - mb) for x, y in zip(a, b))
    den = math.sqrt(sum((x - ma) ** 2 for x in a) * sum((y - mb) ** 2 for y in b))
    return num / den if den else 0.0


tol = 4 / math.sqrt(GAMES)  # about four standard errors of a correlation or a mean / sd
for t in range(GUESSES):
    m = statistics.fmean(lucks[t])
    sd = statistics.pstdev(lucks[t])
    check(f'guess {t + 1}: mean luck {m:+.3f} (sd {sd:.3f}) is zero within sampling error',
          abs(m) < 4 * sd / math.sqrt(GAMES))
for t in range(GUESSES):
    for s in range(t + 1):
        r = corr(lucks[t], skills[s])
        check(f'corr(luck {t + 1}, skill {s + 1}) = {r:+.3f}', abs(r) < tol)
for t in range(GUESSES):
    for s in range(t):
        r = corr(lucks[t], lucks[s])
        check(f'corr(luck {t + 1}, luck {s + 1}) = {r:+.3f}', abs(r) < tol)

print()
print('ALL CHECKS PASSED' if not failures else f'{len(failures)} CHECK(S) FAILED: {failures}')
sys.exit(1 if failures else 0)
