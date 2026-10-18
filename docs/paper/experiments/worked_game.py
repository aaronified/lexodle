"""A worked game: caret, then least, against agent.

After caret the answer agent leaves 18 words. This prints, for the second guess
least and for the best real guess, the skill, risk and luck terms (accounting.py's
decomposition) and the class sizes, to show how a guess that could itself be the
answer is a gamble the accounting prices.

Usage:  python worked_game.py > results/worked_game.txt
"""
import math
import sys

from common import expected_pool, group_sizes, load_words, pattern, skill

sys.stdout.reconfigure(encoding='utf-8')
words = load_words('en', 5)
answer = 'agent'
left = [w for w in words if pattern(w, 'caret') == pattern(answer, 'caret')]
N = len(left)
print(f'after caret against {answer}: {N} words left: {", ".join(left)}')


def terms(guess):
    sizes = group_sizes(left, guess)
    n = sum(sizes)
    p = [s / n for s in sizes]
    h = -sum(x * math.log2(x) for x in p)
    e = expected_pool(sizes)
    h2 = math.log2(n / e)
    landed = sum(1 for w in left if pattern(w, guess) == pattern(answer, guess))
    rho = math.log2(n / landed)
    return sizes, e, h2, h, landed, rho


scan = {g: expected_pool(group_sizes(left, g)) for g in words}
best_e = min(scan.values())
best = [g for g, e in scan.items() if abs(e - best_e) < 1e-9]
print(f'best real guess: E* = {best_e:.2f}; {len(best)} words reach it, e.g. {", ".join(best[:6])}')
print()
for g in ['least'] + best[:1]:
    sizes, e, h2, h, landed, rho = terms(g)
    possible = 'a possible answer' if g in left else 'not a possible answer'
    lk = (sum(s for s in sizes if s > landed) - sum(s for s in sizes if s < landed)) / N * 100
    print(f'{g} ({possible}): classes {sizes}')
    print(f'  E = {e:.2f}  skill {skill(N, e, best_e):.0f}  '
          f'bits: skill H2 = {h2:.2f}, risk H-H2 = {h - h2:.2f}, expected H = {h:.2f}')
    print(f'  the answer lands in a class of {landed}: total reduction {rho:.2f} bits = '
          f'{h2:.2f} + {h - h2:.2f} + luck {rho - h:+.2f};  percentile luck {lk:+.0f}%')
    print(f'  chance of finishing at once: {(1 / N * 100) if g in left else 0:.1f}%')
    print()
