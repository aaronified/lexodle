"""Does the reduction of the guess space split exactly into skill + risk + luck?

A guess takes the N words still possible down to the A words of the group the
answer is in: the total reduction is  rho = log2(N / A)  bits. With p_i = s_i / N
the group sizes' shares and X the pool (P(X = s) = s * m_s / N):

  skill  H2 = log2(N / E)  = -log2 sum p_i^2     (the reduction on the cautious,
                                                  collision reckoning; the app's skill
                                                  is this over the best guess's)
  risk   H - H2 >= 0                              (Shannon minus collision entropy: the
                                                  extra expected reduction a gamble
                                                  brings; 0 for equal groups)
  luck   rho - H                                  (the realised reduction less its
                                                  expected value: mean zero)

so  rho = H2 + (H - H2) + (rho - H)  holds exactly, for every outcome.

This prints, for real first guesses and two synthetic splits, the three terms, the
spread of the reduction, and checks the identity and that the luck term has mean
zero over all answers.

Usage:  python reduction_accounting.py > results/reduction_accounting.txt
"""
import math
import sys

from common import expected_pool, group_sizes, load_words

sys.stdout.reconfigure(encoding='utf-8')


def terms(sizes):
    n = sum(sizes)
    p = [s / n for s in sizes]
    h = -sum(x * math.log2(x) for x in p)
    h2 = math.log2(n / expected_pool(sizes))
    return n, h, h2


def report(name, sizes):
    n, h, h2 = terms(sizes)
    # over every answer: a group of s words is landed in with chance s / n
    rho = {s: math.log2(n / s) for s in set(sizes)}
    mean_rho = sum(s / n * rho[s] for s in sizes)
    luck = {s: rho[s] - h for s in rho}
    mean_luck = sum(s / n * luck[s] for s in sizes)
    sd = math.sqrt(sum(s / n * (rho[s] - mean_rho) ** 2 for s in sizes))
    worst = max(abs(h2 + (h - h2) + luck[s] - rho[s]) for s in rho)
    print(f'{name:>16}: N={n:>5} groups={len(sizes):>4}  skill H2={h2:5.2f}  risk H-H2={h - h2:5.2f}'
          f'  expected reduction H={h:5.2f} bits | spread of the reduction (sd) {sd:4.2f}'
          f' | mean luck {mean_luck:+.1e} | identity error {worst:.1e}')
    return h, h2, rho


print('Bits of reduction: skill + risk + luck = total (exact), by guess')
words = load_words('en', 5)
for g in ['tares', 'slate', 'crane', 'abbey', 'queue', 'mamma']:
    report(g, group_sizes(words, g))
print()
print('Two splits of 100 words with the same number of "small" outcomes available:')
even = [10] * 10
risky = [91] + [1] * 9
for name, sizes in (('ten of ten', even), ('91 and nine ones', risky)):
    h, h2, rho = report(name, sizes)
print()
print('The risky split, outcome by outcome (bits):')
n, h, h2 = terms(risky)
for s in sorted(set(risky), reverse=True):
    rho = math.log2(n / s)
    print(f'  land in {s:>2} (chance {s * risky.count(s) / n * 100:4.0f}%): total {rho:5.2f} = skill {h2:4.2f}'
          f' + risk {h - h2:4.2f} + luck {rho - h:+5.2f}')
print()
print('Crane, outcome by outcome (bits):')
sizes = group_sizes(words, 'crane')
n, h, h2 = terms(sizes)
G = len(sizes)
for k in (0, 2, G // 4, G // 2, 3 * G // 4, G - 1):
    s = sizes[k]
    rho = math.log2(n / s)
    print(f'  land in {s:>3} (chance {s / n * 100:5.2f}%): total {rho:5.2f} = skill {h2:4.2f}'
          f' + risk {h - h2:4.2f} + luck {rho - h:+5.2f}')
