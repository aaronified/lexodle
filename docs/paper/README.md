# Skill, luck and risk in bits

> **The maths here is mostly AI-generated and has not been peer reviewed.** The definitions, proofs and experiments were written with an AI assistant and checked by running the code and the experiments, not by a mathematician. Treat it as a working draft: read it critically, and expect mistakes.

`main.tex` is a working paper on the maths behind the **skill**, **luck** and **risk**
scores in Lexodle's reviews. `plain.tex` is the same in words and small sums. They are
here so that you, or someone better at maths, can check, tighten and extend them. The
PDFs in this folder were made before the bits maths and are out of date until the
sources are compiled again (no LaTeX was available when they were rewritten;
`python check_tex.py main.tex` checks the source statically).

## What it contains

- **Gain and skill**: a guess splits the words still possible into groups; landing in a
  group of chance `q` gains `-log2 q` bits. The expected gain `H` is the Shannon entropy
  of the split. Skill is `100 * H / H*`, `H*` being the largest `H` of any real guess.
- **Luck**: the chance of gaining less than you did less the chance of gaining more
  (a mid-distribution percentile), strictly between -100 and +100, mean exactly 0;
  in bits, your gain less `H`. Over a game the luck terms are martingale differences,
  so luck is uncorrelated with skill and with itself.
- **Risk**: the chance of gaining less than `H` less the chance of gaining more, as a
  share of the largest over the guesses scored: how far a guess leaned on a rare large
  gain. A property of the guess, not of its outcome.
- **Bits over a game**: gains add to the bits needed to find the word, `-log2 p(answer)`
  (`log2 N` for equal chances): bits gained = bits expected + luck.
- The last try, several boards, the one plot of skill, risk and luck.
- **Playstyles**: five behaviours (gambler, maximiser, eliminator early; closer, prober
  at the end), habits, and six styles, with simulated players
  (`experiments/styles`: `node sim2.js [games]`).

The scripts in `experiments/*.py` belong to the earlier expected-pool version of the
maths (skill from the expected pool size, daring, the tries regression). They are kept
for the record and no claim in the paper rests on them.
