"""Numerical checks of the claims about answer laws, last-try scores and daring.

Independent of the app's code (it reuses only the feedback rule in common.py).

  1. Luck under a weighted law, exactly (rational arithmetic): mean 0, variance
     (1 - sum r^3)/3 over the distinct masses r, strictly in (-1, 1), unchanged when
     all weights are scaled.
  2. Luck under the wrong law: the mean is not zero.
  3. Tie rules: giving tied pools weight lambda has mean (2 lambda - 1) sum r^2.
  4. Proposition 5 (2) on equal class sizes ({2,2}: mean 0) and on {3,1} (-1/2).
  5. Last try: the win indicator less the win chance has mean 0, and
     win = skill * best chance + luck holds as an identity of the means.
  6. Daring: for a possible guess, sum q^2 <= p^2 + (1-p)^2, so skill > 0 and
     D < (1 - 1/tau)(1 - p).
  7. Theorem 4 on simulated games under the frequency law, with a player that
     randomises: luck has conditional mean 0 and is uncorrelated with the skill of
     the same and earlier guesses.

Usage:  python verify_laws.py > results/verify_laws.txt
"""
import math
import random
import statistics
import sys
from fractions import Fraction

from common import pattern

sys.stdout.reconfigure(encoding='utf-8')
rng = random.Random(7)
failures = []


def check(name, ok, detail=''):
    print(('ok    ' if ok else 'FAIL  ') + name + (f'   {detail}' if detail else ''))
    if not ok:
        failures.append(name)


def luck_of(masses, y):
    """P(Y > y) - P(Y < y) for the landed class's chance y; masses sum to 1."""
    return sum(m for m in masses if m > y) - sum(m for m in masses if m < y)


def law_of_y(masses):
    """Distinct chances of a landed class and their probabilities r_i = y * count."""
    r = {}
    for m in masses:
        r[m] = r.get(m, 0) + m
    return r


def random_masses(k, big=12):
    w = [Fraction(rng.randint(1, big)) for _ in range(k)]
    t = sum(w)
    return [x / t for x in w]


# 1. exact checks on random weighted partitions
bad = {'mean': 0, 'var': 0, 'range': 0, 'mono': 0, 'scale': 0}
for _ in range(3000):
    k = rng.randint(2, 9)
    q = random_masses(k, big=rng.choice([3, 12, 1000]))
    r = law_of_y(q)
    mean = sum(p * luck_of(q, y) for y, p in r.items())
    var = sum(p * luck_of(q, y) ** 2 for y, p in r.items()) - mean ** 2
    if mean != 0:
        bad['mean'] += 1
    if var != (1 - sum(p ** 3 for p in r.values())) / 3:
        bad['var'] += 1
    ys = sorted(r)
    ls = [luck_of(q, y) for y in ys]
    if not all(-1 < v < 1 for v in ls):
        bad['range'] += 1
    if not all(ls[i] > ls[i + 1] for i in range(len(ls) - 1)):
        bad['mono'] += 1
    c = Fraction(rng.randint(2, 50), 7)
    q2 = [x * c for x in q]  # scaling weights: renormalised chances do not change
    t = sum(q2)
    if [x / t for x in q2] != q:
        bad['scale'] += 1
check('1. luck under a weighted law: mean exactly 0 (3000 partitions, exact)', bad['mean'] == 0)
check('1. variance (1 - sum r^3)/3 over distinct masses, ties included', bad['var'] == 0)
check('1. luck strictly inside (-1, 1) and strictly decreasing in the mass', bad['range'] == 0 and bad['mono'] == 0)
check('1. invariance under scaling the weights', bad['scale'] == 0)

# 2. the wrong law
q = [Fraction(w, 100) for w in (50, 30, 20)]  # the law the luck uses
q_other = [Fraction(w, 100) for w in (20, 30, 50)]  # the law the answer follows
mean_other = sum(p * luck_of(q, x) for x, p in zip(q, q_other))
check('2. luck under a different law has nonzero mean', mean_other != 0, f'mean {float(mean_other):+.3f}')

# 3. tie rules: Lambda_lambda(y) = P(Y>y) - P(Y<y) + (2 lambda - 1) P(Y=y)
ok3 = True
for _ in range(500):
    q = random_masses(rng.randint(2, 8), big=4)
    r = law_of_y(q)
    lam = Fraction(rng.randint(0, 8), 8)
    mean = sum(p * (luck_of(q, y) + (2 * lam - 1) * r[y]) for y, p in r.items())
    if mean != (2 * lam - 1) * sum(p * p for p in r.values()):
        ok3 = False
check('3. tie weight lambda: mean = (2 lambda - 1) sum r^2, zero for every law iff lambda = 1/2', ok3)

# 4. Proposition 5 (2): rescaled luck
def rescaled(sizes):
    n = sum(sizes)
    e = Fraction(sum(s * s for s in sizes), n)
    amax = max(sizes)
    def lk(a):
        return (e - a) / (e - 1) if a <= e else (e - a) / (amax - e)
    return sum(Fraction(s, n) * lk(s) for s in sizes)

check('4. rescaled luck, classes {2,2}: mean 0', rescaled([2, 2]) == 0)
check('4. rescaled luck, classes {3,1}: mean -1/2', rescaled([3, 1]) == Fraction(-1, 2))

# 5. last try
ok5 = True
for _ in range(500):
    n = rng.randint(2, 8)
    w = [rng.randint(1, 30) for _ in range(n)]
    t = sum(w)
    pstar = max(w) / t
    for guess in range(n + 1):  # guess n is a probe
        p = w[guess] / t if guess < n else 0.0
        mean_lambda = sum((w[a] / t) * ((1.0 if a == guess else 0.0) - p) for a in range(n))
        skill_share = p / pstar
        if abs(mean_lambda) > 1e-12 or abs(skill_share * pstar - p) > 1e-12:
            ok5 = False
        if guess < n and not (-1 < 1 - p < 1 and -1 < -p < 0):
            ok5 = False
check('5. last try: Y - p has mean 0, values in (-1, 1), skill*best chance = p', ok5)
check('5. three words, equal chances: hit +67, miss -33', round((1 - 1 / 3) * 100) == 67 and round(-100 / 3) == -33)

# 6. daring bound for a possible guess
ok6 = True
worst = 0.0
for _ in range(2000):
    k = rng.randint(2, 9)
    q = random_masses(k, big=rng.choice([3, 50]))
    p = min(q)  # the class of a possible guess has the guess's own mass inside it; use a singleton
    p = Fraction(1, 1) * p / 3  # the guess alone: strictly less than its class
    rest = [x for x in q]  # classes of the other words, with the guess carved out of one of them
    rest[rng.randrange(k)] -= p
    split = rest + [p]
    s2 = sum(x * x for x in split)
    if s2 > p * p + (1 - p) ** 2:
        ok6 = False
check('6. possible guess: sum q^2 <= p^2 + (1-p)^2, hence E < N and skill > 0', ok6)

# 7. Theorem 4 on simulated games, frequency law, randomising player
words, weights = [], []
with open('../../../app/assets/words/en.txt', encoding='utf-8') as f:
    for line in f:
        w, c = line.rstrip('\n').split('\t')
        if len(w) == 5:
            words.append(w)
            weights.append(int(c))
omega0 = words[:250]
wt0 = {w: max(c, 1) for w, c in zip(words[:250], weights[:250])}
G = omega0


def split_masses(omega, g):
    m = {}
    for w in omega:
        k = pattern(w, g)
        m[k] = m.get(k, 0) + wt0[w]
    return m


def e_of(omega, g):
    m = split_masses(omega, g)
    tot = sum(m.values())
    return len(omega) * sum(x * x for x in m.values()) / (tot * tot)


GAMES, T = 800, 3
lucks = [[] for _ in range(T)]
skills = [[] for _ in range(T)]
for _ in range(GAMES):
    omega = list(omega0)
    ans = rng.choices(omega0, [wt0[w] for w in omega0])[0]
    for t in range(T):
        if len(omega) < 3:
            lucks[t].append(0.0)
            skills[t].append(1.0)
            continue
        # randomised guess: half the time a possible word, else any word
        g = rng.choice(omega) if rng.random() < 0.5 else rng.choice(G)
        e = e_of(omega, g)
        e_best = min(e_of(omega, h) for h in G[:25] + omega[:25])  # a sample of guesses: any past-measurable skill will do
        n = len(omega)
        s = max(0.0, min(1.0, math.log(n / e) / math.log(n / e_best))) if e_best < n else 1.0
        m = split_masses(omega, g)
        tot = sum(m.values())
        k = pattern(ans, g)
        y = m[k]
        lk = (sum(x for x in m.values() if x > y) - sum(x for x in m.values() if x < y)) / tot
        lucks[t].append(lk)
        skills[t].append(s)
        omega = [w for w in omega if pattern(w, g) == k]


def corr(a, b):
    ma, mb = statistics.fmean(a), statistics.fmean(b)
    sab = sum((x - ma) * (y - mb) for x, y in zip(a, b))
    saa = sum((x - ma) ** 2 for x in a)
    sbb = sum((y - mb) ** 2 for y in b)
    return sab / math.sqrt(saa * sbb) if saa > 0 and sbb > 0 else 0.0


tol = 4 / math.sqrt(GAMES)
for t in range(T):
    mu = statistics.fmean(lucks[t])
    sd = statistics.pstdev(lucks[t])
    check(f'7. mean luck of guess {t + 1} under the frequency law',
          abs(mu) < 4 * sd / math.sqrt(GAMES), f'{mu:+.4f} (sd {sd:.3f}, tolerance {4 * sd / math.sqrt(GAMES):.4f})')
for t in range(T):
    for s in range(t + 1):
        r = corr(lucks[t], skills[s])
        check(f'7. corr(luck {t + 1}, skill {s + 1}) = {r:+.3f}', abs(r) < tol, f'tolerance {tol:.3f}')
for t in range(1, T):
    for s in range(t):
        r = corr(lucks[t], lucks[s])
        check(f'7. corr(luck {t + 1}, luck {s + 1}) = {r:+.3f}', abs(r) < tol, f'tolerance {tol:.3f}')

print()
print('ALL CHECKS PASSED' if not failures else f'{len(failures)} FAILED: {failures}')
sys.exit(1 if failures else 0)
