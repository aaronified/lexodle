"""Build the equations of the equations mode (assets/equations/6.txt, 7.txt, 8.txt).

One equation per line, sorted. An equation has exactly one `=`, with a sum on
the left (two or more whole numbers joined by + - * /, no sign in front of a
number and no leading zero) and one whole number on the right. A lone 0 is not
allowed, on either side (10 and 105 are): it makes dull equations (0*0*10=0). The sum is read
with the usual order of operations, in exact fractions (so 6/4*2=3 holds) and
it never divides by zero. In the files `*` and `/` stand for the times and
divide signs, which the game draws.
Run:  python3 tools/build_equations.py
"""
from fractions import Fraction
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "assets" / "equations"
LENGTHS = (6, 7, 8)


def value(tokens):
    """The value of a sum given as numbers and operators, or None (a division by zero)."""
    # first * and /, left to right, then + and -
    terms = [Fraction(int(tokens[0]))]
    ops = []
    i = 1
    while i < len(tokens):
        op, num = tokens[i], Fraction(int(tokens[i + 1]))
        if op == "*":
            terms[-1] *= num
        elif op == "/":
            if num == 0:
                return None
            terms[-1] /= num
        else:
            ops.append(op)
            terms.append(num)
        i += 2
    total = terms[0]
    for op, t in zip(ops, terms[1:]):
        total = total + t if op == "+" else total - t
    return total


def sums(length):
    """Every sum of exactly [length] characters, as a list of tokens."""
    out = []

    def numbers(room):
        # numbers of 1 to room digits without a leading zero, and not 0
        for d in range(1, room + 1):
            lo = 1 if d == 1 else 10 ** (d - 1)
            for n in range(lo, 10**d):
                yield str(n)

    def build(tokens, used):
        # tokens end with a number
        if used == length:
            if len(tokens) >= 3:
                out.append(list(tokens))
            return
        for op in "+-*/":
            for n in numbers(length - used - 1):
                tokens.extend((op, n))
                build(tokens, used + 1 + len(n))
                del tokens[-2:]

    for first in numbers(length - 2):
        build([first], len(first))
    return out


def equations(n):
    found = set()
    for left in range(3, n - 1):
        right = n - 1 - left
        for toks in sums(left):
            v = value(toks)
            if v is None or v.denominator != 1 or v <= 0:
                continue
            r = str(int(v))
            if len(r) == right:
                found.add("".join(toks) + "=" + r)
    return sorted(found)


if __name__ == "__main__":
    OUT.mkdir(exist_ok=True)
    for n in LENGTHS:
        eqs = equations(n)
        (OUT / f"{n}.txt").write_text("\n".join(eqs) + "\n")
        print(n, len(eqs))
