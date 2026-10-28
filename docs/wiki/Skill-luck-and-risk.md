# Skill, luck and risk

Every guess is a question and the colours are the answer. Lexodle measures what a guess teaches in
**bits**: a bit cuts the words still possible in half. Finding the word means gaining all the bits
there are to find, *log₂ N* for *N* equally likely words.

With *N* words still possible, a guess splits them into groups by the colours they would give. The
answer follows a law: every possible word equally likely (frequency off, and every daily, which is
equal over the 3,000 most common words and zero elsewhere), or each word by how common it is
(frequency on). Each game is scored under the law it was drawn by. A group has a chance *q* of
being landed in (its share of the weight), and landing in it **gains** −log₂ *q* bits. The maths,
with proofs and the simulations, is in the
[paper](https://github.com/aaronified/lexodle/tree/main/docs/paper).

- **bits** = the gain of the group you landed in. The **expected gain** *H* = Σ *q* × gain is
  the Shannon entropy of the split.
- **skill** = *H* / *H*\* × 100, where *H*\* is the largest *H* any real guess reaches. 100 means
  as good as the best real guess, 0 means the guess tells you nothing. With one word left,
  playing it is 100 and anything else 0. Skill shows as dots until the best real guess has been
  found in the background. On the last try nothing is left to learn, so skill is the chance your
  guess wins as a share of the best chance any guess has: 100 for the likeliest word that fits,
  0 for a word that cannot be the answer.
- **luck**, from −100 to +100: the chance of gaining less than you did, less the chance of gaining
  more. 0 is the middle outcome, and over every possible answer, under the law the answer was
  drawn by, it averages exactly 0. In bits it is your gain less *H*. On the last try only a word
  that fits the clues can win, so luck is then your outcome less your chance of winning.
- **risk**, from 0 to 100: the chance of gaining less than *H*, less the chance of gaining more,
  as a share of the largest over every guess scored (never below 0). A risky guess usually gains
  less than expected and sometimes much more. It belongs to the guess, not to how it turned out.
  With one word or one try left there is nothing to gamble on.
- **words** before → after each guess, as in WordleBot.

Over a game the gains add up to the bits needed to find the word. **Bits gained = bits expected
(skill) + luck.** The review draws that as a waterfall: a bar for each guess, racing to the bits
needed.

## The review plot

One plot reads all three. A column for every way the guess could have come out, as wide as its
chance and as tall as its gain, the one that gains least on the left. The area under them is *H*
(dashed: the mean height; dotted: *H*\*, the best guess's), and skill is the first over the second.
The columns taller than the mean are the gamble a risky guess takes. A line splits the width in
half, where luck is 0; the column you landed in is outlined, named by the guess.

Skill, luck and risk are all worked out from the guesses alone, so they can be worked out again if
the maths changes (see [History and playstyles](History-and-playstyles)).
