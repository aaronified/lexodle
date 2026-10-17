<p align="center">
  <img src="app/assets/logo.svg" alt="lexodle logo: three tiles climbing from grey to yellow to green" width="112">
</p>

# Lexodle

A minimal word game in 17 Latin-script languages.

**Play: <https://aaronified.github.io/lexodle/>**

## How to play

Guess the hidden word. After each guess every letter is marked:

- **green** – right letter, right place
- **yellow** – in the word, wrong place
- **grey** – not in the word

Before you start, choose:

| Setting    | Options                                                                  |
| ---------- | ------------------------------------------------------------------------ |
| Language   | English (US and UK spelling), Spanish, French, German, Italian, Portuguese (Brazil and Portugal), Dutch, Polish, Swedish, Danish, Norwegian, Turkish, Romanian, Czech, Indonesian, Hungarian, Catalan; each with its flag |
| Letters    | 4 to 8                                                                   |
| Difficulty | a 4 x 4 grid: tries (easy 8, normal 6, hard 4, brutal 3) by word pool (answers drawn from the 500, 1,500, 3,000 or 6,000 most common words) |

The letters and the helper are sliders: use the arrows, swipe or drag (the value slides and
fades with your finger), scroll sideways or hold shift and scroll the wheel, or click one and use
the arrow keys. Type on a keyboard or use the on-screen one, which adds each language's accented
letters.

### Skill and luck

The **helper** setting chooses what the game tells you while you play: *off*,
*skill only*, *skill + luck*, or *full help* (which adds how many possible words remain).
When a game ends, the **review** steps through your guesses one at a time (buttons,
the progress bar, or the arrow keys). Each step shows the board with a table of skill,
luck, words left and info gained; your guess beside the best picks at that point; how
the guess divided the pool of possible words, against the pool you landed in; and a
short reading of the step. Your guess can be a valid word that the game never uses as an
answer; the review says so, and nothing more.

With *N* words still possible, a guess splits them into groups by the feedback they
would give; the expected pool left is *E* = Σ(group size)² / *N*.

- **skill** = (*N* − *E*) / (*N* − 1) × 100. 100 means the guess splits the words into
  singletons (the best possible), 0 means it tells you nothing. With one word left,
  playing it is 100 and anything else 0.
- **luck** = (1 − words left / *E*) × 100, a signed percentage: how much smaller (+, green)
  or larger (−, red) than average the pool you landed in was. 0% is exactly average. With
  one word left, or a guess that cannot split the words, there is only one pool, so luck is
  0%.
- **info gained** = (1 − ln(words left) / ln(words at the start)) × 100, cumulative, as in
  WordleBot. It reaches 100% when one word is left.

Skill is the measure from the original Python game. Luck is not: the original compared
words removed with words expected to be removed, which saturates near 100 whenever most
words go either way, so a good result could never read much above average.

### Solver

The **solver** (on the home screen, for the chosen language and length) helps with a
game you are playing elsewhere. Type each guess, tap its tiles to match the colours the
game showed (grey, yellow, green), and add it. It lists the words still possible, most
likely first, and recommends the next guess: the word that leaves the fewest words in
expectation, drawn from the 600 most frequent words plus the possible answers. Tap a
word to use it as the next guess. Unlike the game, which picks its answers from the 2,000
most common words of a length, the solver considers every word the game accepts as a
guess (up to 6,000 per length), because the game you are solving may use any of them.

When a game ends, the answer's pronunciation (IPA and audio), meaning, synonyms
and antonyms are fetched from [Wiktionary](https://en.wiktionary.org), with a
link to the full entry. If Wiktionary has no entry or is unreachable, the game
carries on without it.

### Achievements

17 achievements, each with its own icon, saved in your browser (nothing is sent
anywhere): first light, one shot, last breath, no mercy, brevity, long haul, **pure
skill** (win with every guess above 90 skill), **skill issue** (win 10 games with every
guess above 95 skill), full range, three in a row, seven in a row, polyglot, babel,
regular, veteran, dustwalker and persistent.

Numbered achievements show a progress bar. Once earned, they start again from 0 and can
be earned again; the other achievements can be earned again too (first light aside), and
every earning is counted. A history table lists each achievement you have earned: how many
times, the first day and the latest.

## Develop

The app is in [`app/`](app) (Flutter, Material 3).

```
cd app
flutter pub get
flutter test
flutter run -d chrome
```

`flutter build apk` also works; the `android/` platform is scaffolded.

| Path                     | What it is                                              |
| ------------------------ | ------------------------------------------------------- |
| `app/lib/logic.dart`     | Guess scoring, eligible-word filter, skill and luck, solver recommendation, weighted word pick |
| `app/lib/solver.dart`    | The solver page                                         |
| `app/lib/keyboard.dart`  | The on-screen keyboard, shared by game and solver       |
| `app/lib/words.dart`     | Loads the per-language word lists                       |
| `app/lib/wiktionary.dart`| Wiktionary lookup and parser                            |
| `app/lib/store.dart`     | Settings, stats and the achievement definitions         |
| `app/assets/words/`      | Generated word lists, one file per language             |
| `app/tools/`             | Word-list generator and a live Wiktionary check         |

`app/tools/live_check.dart` calls the real Wiktionary API (`dart run tools/live_check.dart`);
the unit tests use saved responses and need no network.

## Deploy

The `Deploy web app to GitHub Pages` workflow tests, builds and publishes `app/`
on every push to `main` that touches `app/` or the workflow. It needs Settings →
Pages → Source set to *GitHub Actions*. You can also run it by hand from the Actions tab.

## Word lists

`app/assets/words/` is generated by `app/tools/build_words.py`:

```
python -m venv app/tools/.venv
app/tools/.venv/Scripts/pip install wordfreq spylls pillow   # bin/pip on macOS/Linux
app/tools/.venv/Scripts/python app/tools/build_words.py
```

Every language is built the same way. The candidates are the words
[wordfreq](https://github.com/rspeer/wordfreq) knows, Latin letters only, 4 to 8 letters, most
frequent first. Each is kept only if the language's Hunspell dictionary accepts it, with
inflected forms included, using [spylls](https://github.com/zverok/spylls) and the
dictionaries from [wooorm/dictionaries](https://github.com/wooorm/dictionaries) (LibreOffice's
for Indonesian). Hunspell stores proper nouns capitalised and the candidates are lowercase,
so names and most abbreviations drop out; German nouns are capitalised in its dictionary, so
German also tries the capitalised form. Each language keeps up to 6,000 words per length as
valid guesses, with a weight from their frequency.

Spelling variants (English US / UK, Portuguese Brazil / Portugal) share one frequency list, since
wordfreq has one per language, and differ in the dictionary that filters it: `colour` passes the UK
dictionary and not the US one. Flags are emoji, except Catalan's, which has none and is drawn
(`app/assets/flags/ca.svg`).

Names are the weak point of a dictionary filter. The Portuguese dictionary stores many names as
ordinary lowercase entries (`brasil`, `lisboa`, `jorge`), so the two Portuguese lists get a second
filter: a word must also have its lowercase page on en.wiktionary.org as a Portuguese lemma or
non-lemma form, which names do not (`paulo`, `maria`, `pedro`). That is the same Wiktionary
the answer panel links to, so every Portuguese answer has an entry. **The filter is in the
generator, but the shipped Portuguese lists have not been rebuilt with it yet** and still contain
those names; run `python app/tools/build_words.py pt pt-PT` (about 15 minutes, mostly the one-off
download of Wiktionary's category lists). Finnish was removed: it has no
Hunspell dictionary in either collection, and a frequency-only list let names and abbreviations in.
`app/assets/words/SOURCES.md` lists every dictionary and the licence it states; only the filtered
word lists are shipped.

The difficulty grid's pool is the most frequent words at the chosen length, so a smaller pool
means more familiar answers. Some languages have fewer than 6,000 words at some lengths (for
example Indonesian has about 2,400 at five letters), and the grid shows each language's real
count. Words beyond the pool are still accepted as guesses.

## Credits and licences

- Word data: [wordfreq](https://github.com/rspeer/wordfreq) (CC BY-SA 4.0), filtered with Hunspell
  dictionaries from [wooorm/dictionaries](https://github.com/wooorm/dictionaries) and
  [LibreOffice](https://github.com/LibreOffice/dictionaries); licences in `app/assets/words/SOURCES.md`
- Definitions, IPA, audio, synonyms and antonyms: [Wiktionary](https://en.wiktionary.org),
  CC BY-SA 4.0, fetched live from the browser
- Font: JetBrains Mono (SIL OFL 1.1)
- Achievement icons: [Tabler Icons](https://tabler.io/icons) filled set (MIT, `app/assets/icons/LICENSE-tabler.txt`)
- Code: see [LICENSE](LICENSE)

This project was developed with assistance from [KiloCode](https://kilo.ai) and Claude Code, AI coding assistants.
