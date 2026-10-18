"""Shared helpers for the experiments in the paper.

Everything reads the word list the app ships (app/assets/words/<lang>.txt, one
`word<TAB>weight` per line, most common first) and uses the same feedback rule
as the game (two passes: greens first, then yellows limited by the letters
left over), so the numbers here are the numbers the app computes.
"""
import collections
import os

HERE = os.path.dirname(os.path.abspath(__file__))
WORDS_DIR = os.path.join(HERE, '..', '..', '..', 'app', 'assets', 'words')


def load_words(lang='en', length=5):
    """The accepted words of `length` letters, most common first."""
    path = os.path.join(WORDS_DIR, lang + '.txt')
    with open(path, encoding='utf-8') as f:
        words = [line.split('\t')[0] for line in f]
    return [w for w in words if len(w) == length]


def pattern(target, guess):
    """Feedback of `guess` against `target` as one base-3 integer
    (0 grey, 1 yellow, 2 green; the first letter is the most significant)."""
    n = len(guess)
    r = [0] * n
    left = collections.Counter()
    for i in range(n):
        if guess[i] == target[i]:
            r[i] = 2
        else:
            left[target[i]] += 1
    for i in range(n):
        if r[i] == 0 and left[guess[i]] > 0:
            r[i] = 1
            left[guess[i]] -= 1
    k = 0
    for v in r:
        k = k * 3 + v
    return k


def group_sizes(words, guess):
    """The sizes of the groups `guess` splits `words` into, largest first."""
    groups = collections.Counter(pattern(w, guess) for w in words)
    return sorted(groups.values(), reverse=True)


def expected_pool(sizes):
    """E = sum(s^2) / N, the expected size of the pool landed in."""
    n = sum(sizes)
    return sum(s * s for s in sizes) / n


def skill(n, e, e_best):
    """ln(N / E) / ln(N / E*) * 100, clamped to [0, 100] (the score the app uses)."""
    import math
    if n <= 1 or math.log(n / e_best) <= 1e-12:
        return 100.0
    return max(0.0, min(100.0, math.log(n / e) / math.log(n / e_best) * 100))


def linear_skill(n, e, e_best):
    """(N - E) / (N - E*) * 100, the linear alternative, clamped to [0, 100]."""
    if n <= 1 or n - e_best <= 1e-12:
        return 100.0
    return max(0.0, min(100.0, (n - e) / (n - e_best) * 100))


def chance_luck(sizes, landed):
    """The chance of a bigger pool less the chance of a smaller one, in
    percent, for a guess whose groups have `sizes`, landing in a pool of
    `landed` words."""
    n = sum(sizes)
    bigger = sum(s for s in sizes if s > landed)
    smaller = sum(s for s in sizes if s < landed)
    return (bigger - smaller) / n * 100
