"""Summarise the output of first_guess.py.

Usage:
    python first_guess.py > first_guess.json          (about two minutes)
    python first_guess_summary.py first_guess.json results/first_guess.csv \
        > results/first_guess_summary.txt

Prints the best first guesses, the skill of some familiar ones under the linear
score used by the app and under a logarithmic alternative, and how the skills
of all words are distributed. Writes every word's E, groups, largest group and
skill to the CSV.
"""
import json
import math
import statistics
import sys

path, csv_path = sys.argv[1], sys.argv[2]
d = json.load(open(path, encoding='utf-8'))
N, e_best, rows = d['N'], d['E_best'], d['words']
by_word = {r['word']: r for r in rows}


def log_skill(e):
    """The logarithmic alternative: ln(N/E) / ln(N/E*), the share of the best
    achievable information (in the Renyi order-2 sense) that the guess gets."""
    return math.log(N / e) / math.log(N / e_best) * 100


with open(csv_path, 'w', encoding='utf-8') as f:
    f.write('word,expected_pool,groups,largest_group,skill\n')
    for r in rows:
        f.write(f"{r['word']},{r['E']:.4f},{r['groups']},{r['largest']},{r['skill']:.4f}\n")

print(f"English, five letters: N = {N} possible answers, every one a valid guess.")
print(f"Best first guess: {d['best_word']}, E* = {e_best:.2f} "
      f"(leaves about {e_best:.0f} of {N} words on average)")
print()
print('rank  word   E        groups  largest  skill(linear)  skill(log)')
for r in rows[:8]:
    print(f"{rows.index(r) + 1:>4}  {r['word']:<6} {r['E']:>7.1f} {r['groups']:>7} {r['largest']:>8}"
          f" {r['skill']:>13.2f} {log_skill(r['E']):>11.1f}")
print('...')
for w in ['slate', 'trace', 'crane', 'abbey', 'queue', 'mamma', 'fuzzy']:
    r = by_word[w]
    print(f"{rows.index(r) + 1:>4}  {w:<6} {r['E']:>7.1f} {r['groups']:>7} {r['largest']:>8}"
          f" {r['skill']:>13.2f} {log_skill(r['E']):>11.1f}")
worst = rows[-1]
print(f"{len(rows):>4}  {worst['word']:<6} {worst['E']:>7.1f} {worst['groups']:>7} {worst['largest']:>8}"
      f" {worst['skill']:>13.2f} {max(0.0, log_skill(worst['E'])):>11.1f}")

sk = [r['skill'] for r in rows]
lg = [log_skill(r['E']) for r in rows]
print()
print('Distribution over all first guesses (linear skill / logarithmic skill):')
print(f"  median            {statistics.median(sk):6.1f} / {statistics.median(lg):6.1f}")
print(f"  lowest            {min(sk):6.1f} / {min(lg):6.1f}")
for cut in (90, 95, 99):
    print(f"  share above {cut}   {sum(s > cut for s in sk) / len(sk) * 100:5.1f}% / "
          f"{sum(s > cut for s in lg) / len(lg) * 100:5.1f}%")
