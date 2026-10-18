"""Three definitions of luck compared on real first guesses and a late state.

  expectation   (E - A) / (E - 1)                 unbounded below
  rescaled      (E - A)/(E - 1) above E, (E - A)/(A_max - E) below
                                                  bounded, but not mean zero
  chance        P(bigger pool) - P(smaller pool)  bounded and mean zero

For each guess the script prints the luck of landing in the biggest pool, the
median-by-count pool and a single word, and the mean of each luck over every
possible answer (each word equally likely). Results: results/luck_definitions.txt

Usage:  python luck_definitions.py > results/luck_definitions.txt
"""
import random
import sys

from common import chance_luck, expected_pool, group_sizes, load_words, pattern

sys.stdout.reconfigure(encoding='utf-8')
words = load_words('en', 5)
N = len(words)


def expectation_luck(e, a):
    return 0.0 if e <= 1 else (e - a) / (e - 1) * 100


def rescaled_luck(e, a, biggest):
    if e <= 1 or biggest <= e:
        return 0.0
    return (e - a) / (e - 1) * 100 if a <= e else (e - a) / (biggest - e) * 100


def means(sizes):
    n = sum(sizes)
    e = expected_pool(sizes)
    big = sizes[0]
    m_exp = sum(s / n * expectation_luck(e, s) for s in sizes)
    m_res = sum(s / n * rescaled_luck(e, s, big) for s in sizes)
    m_cha = sum(s / n * chance_luck(sizes, s) for s in sizes)
    return e, big, m_exp, m_res, m_cha


print(f'First guesses, N = {N} five-letter English words')
print('guess   groups      E  biggest | luck in the biggest pool: '
      'expectation  rescaled  chance | mean over answers: expectation  rescaled  chance')
for g in ['tares', 'slate', 'crane', 'abbey', 'queue', 'mamma']:
    sizes = group_sizes(words, g)
    e, big, m_exp, m_res, m_cha = means(sizes)
    print(f'{g:>6} {len(sizes):>7} {e:>6.1f} {big:>8} | '
          f'{expectation_luck(e, big):>31.0f}% {rescaled_luck(e, big, big):>8.0f}% '
          f'{chance_luck(sizes, big):>6.0f}% | {m_exp:>29.1f}% {m_res:>8.1f}% {m_cha:>6.1f}%')

print()
print('Crane: luck by pool landed in')
sizes = group_sizes(words, 'crane')
G = len(sizes)
e = expected_pool(sizes)
print('landing in            pool  chance   expectation  rescaled  chance-weighted')
for k in [0, 1, 2, G // 4, G // 2, 3 * G // 4, G - 1]:
    s = sizes[k]
    print(f'group #{k + 1:>3} of {G:<3}  {s:>6}  {s / N * 100:5.2f}%  {expectation_luck(e, s):>10.0f}%'
          f'  {rescaled_luck(e, s, sizes[0]):>8.0f}%  {chance_luck(sizes, s):>14.0f}%')

print()
print('A late state: after crane and toils against one answer')
random.seed(3)
answer = random.choice(words[:1500])
left = words[:]
for g in ['crane', 'toils']:
    m = pattern(answer, g)
    left = [w for w in left if pattern(w, g) == m]
print(f'answer {answer}, {len(left)} words left')
for g in left[:3] + ['mumps']:
    sizes = group_sizes(left, g)
    e, big, m_exp, m_res, m_cha = means(sizes)
    print(f'{g:>6}: E={e:.1f} groups={len(sizes)} biggest={big}  '
          f'mean luck: expectation {m_exp:+.1f}%  rescaled {m_res:+.1f}%  chance {m_cha:+.1f}%')

print()
print('A pair among singletons: the expectation luck is unbounded below')
for n in [10, 100, 1000, 10000]:
    sizes = [2] + [1] * (n - 2)
    e = expected_pool(sizes)
    print(f'N={n:>6}: landing in the pair gives {expectation_luck(e, 2):>10.1f}%   '
          f'chance-weighted {chance_luck(sizes, 2):+.2f}%')
