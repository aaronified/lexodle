# Skill, luck and daring

With *N* words still possible, a guess splits them into groups by the feedback they would give.
The answer follows a law: every possible word equally likely (frequency off, and every daily, which
is equal over the 3,000 most common words and zero elsewhere), or each word by how common it is
(frequency on). Each game is scored under the law it was drawn by. A group then has a chance *q*
of being landed in (its share of the weight), and the expected pool left is *E* = *N* Σ *q*²,
which is the plain Σ(group size)² / *N* when the words are equally likely. The maths, with proofs
and the experiments, is in the [paper](https://github.com/aaronified/lexodle/tree/main/docs/paper).

- **skill** = ln(*N* / *E*) / ln(*N* / *E*\*) × 100, where *E*\* is the smallest *E* any real
  guess reaches. 100 means as good as the best real guess, 0 means the guess tells you nothing.
  The logarithm keeps most guesses from crowding near 100. With one word left, playing it is 100
  and anything else 0. Skill shows as dots until the best real guess has been found in the
  background. On the last try nothing is left to learn, so skill is the chance your guess wins
  as a share of the best chance any guess has: 100 for the likeliest word that fits, 0 for a word
  that cannot be the answer.
- **luck**, from −100% to +100%: the chance of landing in a bigger pool than you did, less the
  chance of landing in a smaller one, a pool being as big as the weight in it. 0% is the middle
  outcome, and over every possible answer, under the law the answer was drawn by, it averages
  exactly 0. On the last try only a word that fits the clues can win, so luck is then
  about the pick itself.
- **daring**, from 0 to 100: how much your guess went for the whole word instead of the clues. A
  guess that cannot be the answer has none. One that can scores higher the more it cost in skill,
  the less likely that word was (by the same law as skill and luck), and the more tries you had left. With one
  try left going for the word is the only play, so it has none; neither does a guess that is both
  the best split and a possible answer. Good players seldom go above 10.
- **info gained** = (1 − ln(words left) / ln(words at the start)) × 100, cumulative, as in
  WordleBot. It reaches 100% when one word is left.

Skill, luck and daring are all worked out from the guesses alone, so they can be worked out again
if the maths changes (see [History and playstyles](History-and-playstyles)).

## Expected guesses

Skill, luck and daring together predict how many guesses a game takes. The history chart draws
the expected guesses of a period, and its details break it down:

`expected guesses 4.4 = 9.8 − 4.1 skill + 0.2 luck + 0.0 daring`

Skill only ever takes guesses off; luck takes them off when good and adds them when bad; daring
is measured from a typical level (10), so going for the word more takes guesses off and less adds
them. The weights are the mean of three linear fits on 2,500 simulated English five-letter games
each, one per answer law (`app/tools/predict_tries3.dart`, paper Section 9.6): guesses = 9.38 −
0.0563 skill − 0.0164 luck − 0.0445 daring. Fitted on half the games and read on the other half,
skill, luck and daring explain 36% of the variance in tries when answers are drawn by frequency
and 59% when every word is equally likely or for the daily. Luck explains almost none under the
frequency law. **They are not measured on people.**
