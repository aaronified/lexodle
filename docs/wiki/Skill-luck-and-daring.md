# Skill, luck and daring

With *N* words still possible, a guess splits them into groups by the feedback they would give;
the expected pool left is *E* = Σ(group size)² / *N*. The maths, with proofs and the
experiments, is in the [paper](https://github.com/aaronified/lexodle/tree/main/docs/paper).

- **skill** = ln(*N* / *E*) / ln(*N* / *E*\*) × 100, where *E*\* is the smallest *E* any real
  guess reaches. 100 means as good as the best real guess, 0 means the guess tells you nothing.
  The logarithm keeps most guesses from crowding near 100. With one word left, playing it is 100
  and anything else 0. Skill shows as dots until the best real guess has been found in the
  background.
- **luck**, from −100% to +100%: the chance of landing in a bigger pool than you did, less the
  chance of landing in a smaller one. 0% is the middle outcome, and over every possible answer it
  averages exactly 0. On the last try only a word that fits the clues can win, so luck is then
  about the pick itself.
- **daring**, from 0 to 100: how much your guess went for the whole word instead of the clues. A
  guess that cannot be the answer has none. One that can scores higher the more it cost in skill,
  the less likely that word was (by how common it is), and the more tries you had left. With one
  try left going for the word is the only play, so it has none; neither does a guess that is both
  the best split and a possible answer. Good players seldom go above 10.
- **info gained** = (1 − ln(words left) / ln(words at the start)) × 100, cumulative, as in
  WordleBot. It reaches 100% when one word is left.

Skill, luck and daring are all worked out from the guesses alone, so they can be worked out again
if the maths changes (see [History and playstyles](History-and-playstyles)).

## Expected guesses

Skill, luck and daring together predict how many guesses a game takes. The history chart draws
the expected guesses of a period, and its details break it down:

`expected guesses 4.4 = 7.8 − 3.6 skill + 0.3 luck + 0.0 daring`

Skill only ever takes guesses off; luck takes them off when good and adds them when bad; daring
is measured from a typical level (8), so going for the word more takes guesses off and less adds
them. The weights are the mean of three linear fits on simulated games
(`app/tools/predict_tries.dart`, paper Section 9.6). On simulated games skill and luck explain
about half of the variance in tries and daring adds 1.5 to 4 points of R². **They are not
measured on people.**
