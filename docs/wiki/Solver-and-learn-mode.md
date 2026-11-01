# Solver and learn mode

## Solver

The **solver** (open it from game modes) helps with a game you are playing
elsewhere. It uses the same settings as the game: the language, the letters and the difficulty
(the answer is one of the words of the chosen pool, and it counts the tries). Type each guess, tap
its tiles to match the colours the game showed (grey, yellow, green), and add it. It lists the
words still possible, most likely first, and recommends the next guess: the word that leaves the
fewest words in expectation, drawn from the 600 most frequent words plus the possible answers.

The advice follows the tries left: with two left it picks the guess most likely to solve it by the
last try (the most groups, weighted by how common each word is), and with one left only the
likeliest word that fits, since nothing else can win. Tap a word to use it as the next guess.
Guesses are scored over every word the game accepts (up to 6,000 per length), and the answer is
looked for among all of them; the frequency checkbox in the game modes sets whether commoner
words are weighted as likelier.

In the **quartet** and the **relay race** the solver follows the mode too (and counts the extra
tries those modes give). Type each guess once. In a quartet, tap the colours each unsolved board
showed; in a relay race, those of the board that is on. It narrows every board and recommends the
next guess for them together, the one with the best skill across the boards (each weighted by how
much is left to find out on it, as in the review), and on the last try the word that fits the most
boards. When a relay race opens the next board it already has every earlier guess applied, so tap
in the colours that board showed for each of them; any row can be corrected by tapping its tiles.

## Learn mode

**Learn** (the last button of game modes) opens the learn home: the opening lesson and four things
to practise, each
with how it has been going in the language and length you chose (a row of blocks for the skill of
the last twelve, and the last result), and the days in a row you have learned something. What
you do there is kept on the phone, in backups, apart from the game history.

**Practise a word** shows you the answer and asks you to find the best
guess at each step. Guess as usual; after each guess it gives the skill of the guess and the best
guesses there were, and the words that still fit the clues are listed at the bottom (the 120 most
common; tap one to use it). It uses the language, length and pool you set, has no tries, is not
scored and is not kept in the history. Solve the word and start another.

**Why a guess scored as it did.** Tap the line under a guess. It says how the guess split the
words that fitted (the groups, the biggest group, the words expected to be left and the bits),
how the best guess split them, and what the difference was: more groups, a smaller worst case, or
that the best guess could itself have been the answer.

**Hint.** Before you guess, the hint button gives the best guess in three steps: its first letter,
then the word (tap it to use it), then why it is the best. Each press is one step.

**Undo** takes the last guess back, with the words that fitted before it, so you can try another.

**Choose the best** shows a position, the guesses made so far with their colours and how many
words still fit, and four words. Pick the one that tells the words that fit apart best. It says
whether you were right (nothing offered did better), the skill of every option, and why, in the
same words as learn mode. **Show the groups** lays out every option step by step: the colours each
group of words would show, how many words are in it, the chance the answer is there, the bits that
gains, and what it adds to the words left on average (the sum is the number shown), with the group
the answer was in marked. A round is ten positions, with how many you got right and the average
skill at the end. The positions come from a random word of your language and length that one or two
common guesses have been played against. Words already played, or that tell nothing, are not
offered. It is not scored and not kept in the history.

**Closing** is the endgame: three to ten words fit and two or three tries are left. Four guesses are
offered and the right one is the guess most likely to win in time. Each is graded by the exact
chance, worked out over what could follow, so a word that cannot be the answer but splits the rest
(so that the next guess is nearly sure) can beat a word that fits. It says for each: whether it can
be right now, how it splits the rest, and the chance it wins within the tries. Ten positions make a
round.

**The opening** is a lesson, not a quiz: the best first guess for your language and length, how it
splits the words, and the first guesses nearly as good (tap one to compare). Below it, the twelve
likeliest colours the first guess can show; for each, the best second guess and about how many words
are left after it. Tap an outcome for the other good second guesses and the words that fit it. The
second guesses are worked out one outcome at a time, so the list fills in.

**Three words** asks for three words to play first, whatever the answer. The better the colours of
the three tell the words apart together, the surer the fourth or fifth guess. Each set is scored on
every word of the list: the bits after each word, the groups the answers fall into, the words left
on average, and the chance of winning by the fourth guess (the best word of each group) and by the
fifth (the best word, then the best of what its colours leave; a lower bound for very large
groups). Skill is its bits against the best sequence the app found: a search that takes the best
opening guesses and adds, one at a time, the word that tells the most, so there may be a better set.
The three need not start with the best opener, and the order does not change what they tell.

**Achievements.** Learning earns [achievements](Achievements): words practised well, flawless
words, rounds and perfect rounds of the drills, sets of three words, a streak of days, and a full
lesson (every mode in one day). A word typed straight in, with the answer in front of you, does not count; what counts
is the quality of the guesses. They show at the end of a word or a round, and are kept once for
you, not per language.
