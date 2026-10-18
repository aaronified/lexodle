"""How far the game's real answer draw moves the average luck away from zero.

The theory assumes every possible word is equally likely to be the answer. The
game draws its answer from the P most common words with probability proportional
to word frequency. For a first guess this prints the mean luck over the game's
real draw (P = 500, 1500, 3000, all) and over the uniform assumption.

Usage:  python prior_bias.py > results/prior_bias.txt
"""
import os
import sys

from common import WORDS_DIR, chance_luck, group_sizes, load_words, pattern

sys.stdout.reconfigure(encoding='utf-8')
rows = []
with open(os.path.join(WORDS_DIR, 'en.txt'), encoding='utf-8') as f:
    for line in f:
        w, c = line.rstrip('\n').split('\t')
        if len(w) == 5:
            rows.append((w, int(c)))
words = [w for w, _ in rows]
N = len(words)
print(f'English five-letter words, N = {N}; the player sees all {N} as possible.')
print('mean luck over the answer, by how the answer is drawn')
print('guess   uniform |  game draw from the most common 500   1500   3000   all')
for g in ['tares', 'slate', 'crane', 'abbey', 'mamma']:
    sizes = group_sizes(words, g)
    cls = {}
    for w in words:
        cls[w] = sum(1 for _ in ())  # placeholder replaced below
    # size of the class each word is in
    code = {w: pattern(w, g) for w in words}
    count = {}
    for w in words:
        count[code[w]] = count.get(code[w], 0) + 1
    luck_of = {w: chance_luck(sizes, count[code[w]]) for w in words}
    uniform = sum(luck_of[w] for w in words) / N
    out = []
    for p in (500, 1500, 3000, N):
        pool = rows[:p]
        total = sum(c for _, c in pool)
        out.append(sum(c * luck_of[w] for w, c in pool) / total)
    print(f'{g:>6} {uniform:+8.1f}% | {out[0]:>34.1f}% {out[1]:>6.1f}% {out[2]:>6.1f}% {out[3]:>6.1f}%')
