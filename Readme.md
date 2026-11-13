<p align="center">
  <img src="app/assets/logo.svg" alt="lexodle logo: three tiles climbing from grey to yellow to green" width="112">
</p>

<h1 align="center">Lexodle</h1>

<p align="center">
  A word game that shows you how well you played.<br>
  17 languages, a daily word, four boards at once, and a score for every guess.
</p>

<p align="center">
  <a href="https://github.com/aaronified/lexodle/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/aaronified/lexodle?sort=semver&label=release&color=blue"></a>
  <a href="https://github.com/aaronified/lexodle/releases/latest"><img alt="Android APK" src="https://img.shields.io/badge/Android-APK-3DDC84?logo=android&logoColor=white"></a>
  <a href="https://github.com/aaronified/lexodle/releases"><img alt="APK downloads" src="https://img.shields.io/github/downloads/aaronified/lexodle/total?label=APK%20downloads&color=3DDC84"></a>
  <a href="https://aaronified.github.io/lexodle/"><img alt="Live demo" src="https://img.shields.io/badge/demo-in%20your%20browser-blue?logo=googlechrome&logoColor=white"></a>
  <img alt="Platforms" src="https://img.shields.io/badge/platforms-Android%20%C2%B7%20Web-lightgrey">
  <a href="https://flutter.dev"><img alt="Built with Flutter" src="https://img.shields.io/badge/built%20with-Flutter-02569B?logo=flutter&logoColor=white"></a>
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/github/license/aaronified/lexodle?color=blue"></a>
</p>

<p align="center">
  <a href="https://github.com/aaronified/lexodle/actions/workflows/pages.yml"><img alt="Demo build" src="https://img.shields.io/github/actions/workflow/status/aaronified/lexodle/pages.yml?label=demo%20build"></a>
  <a href="https://github.com/aaronified/lexodle/actions/workflows/release.yml"><img alt="APK build" src="https://img.shields.io/github/actions/workflow/status/aaronified/lexodle/release.yml?label=APK%20build"></a>
</p>

<p align="center">
  <a href="https://aaronified.github.io/lexodle/"><strong>Try the demo</strong></a> ·
  <a href="https://github.com/aaronified/lexodle/releases/latest"><strong>Get the Android APK</strong></a> ·
  <a href="https://github.com/aaronified/lexodle/wiki">Wiki</a> ·
  <a href="docs/paper">The maths</a>
</p>

---

<table>
  <tr>
    <td align="center"><img src="docs/screenshots/today.png" alt="The today tab: four chosen dailies each with its state and streak, a free play button and a pink play button pinned above the tab bar" width="230"></td>
    <td align="center"><img src="docs/screenshots/you.png" alt="The you tab: a profile chip, the classic streak card with a week of fires, the theme card, and rows for achievements with the lex balance, reminders, mode settings, history and backup" width="230"></td>
    <td align="center"><img src="docs/screenshots/words.png" alt="The words tab: saved and collected counts, a list of saved words with notes, and a trophy banner with a bar towards the next trophy" width="230"></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/screenshots/game.png" alt="A daily in play, with a blank pencilled into the third tile of the next guess" width="230"></td>
    <td align="center"><img src="docs/screenshots/quartet.png" alt="A quartet: four boards sharing every guess, with split keys on the keyboard" width="230"></td>
    <td align="center"><img src="docs/screenshots/hints.png" alt="A game with the hint tray open: three hold-to-buy hint rows with their free-hint prices and a link back to the keyboard" width="230"></td>
  </tr>
</table>

## What it does

<table>
  <tr>
    <td width="60%">
      <h3>📅 A daily word, in every language</h3>
      Everyone gets the same word on the same date, with no server picking it. Each language has
      its own streak and calendar, and the day is checked against the hosting server's clock so
      the device date cannot be wound forward.
      <a href="https://github.com/aaronified/lexodle/wiki/Daily-word">How it works</a>.
    </td>
    <td width="40%"><img src="docs/screenshots/features/game.png" width="100%" alt="A daily in play, with a blank pencilled into the third tile"></td>
  </tr>
</table>

<table>
  <tr>
    <td width="40%"><img src="docs/screenshots/features/quartet.png" width="100%" alt="A quartet: four boards sharing every guess"></td>
    <td width="60%">
      <h3>🔢 Four words at once</h3>
      A quartet plays one guess on four boards, each key split in four. A relay race plays the
      boards one after the other, each starting with every earlier guess applied. Pick the word
      length (4 to 8), the tries and how common the answers are.
      <a href="https://github.com/aaronified/lexodle/wiki/How-to-play">The rules</a>.
    </td>
  </tr>
</table>

<table>
  <tr>
    <td width="60%">
      <h3>💡 Lex and hints</h3>
      Lex is the currency of hints. Open the hint tray in any game and hold a row to buy a hint: rule
      a letter out, name a letter that is in the word, or place one. A free hint goes first, and
      undo takes it back. A game with a hint in it pays no lex, and your streak stays safe. Medals
      on achievements pay lex (bronze 1, silver 2, gold 3, platinum 5), and the chip on the
      achievements page opens what you have earned in total.
    </td>
    <td width="20%"><img src="docs/screenshots/hints.png" width="100%" alt="The hint tray: a lamp on each of three rows, rule one out, a letter that is in, a letter in its place"></td>
    <td width="20%"><img src="docs/screenshots/lex-dropdown.png" width="100%" alt="The achievements header with the lex chip, opened to the total earned and what each medal pays"></td>
  </tr>
</table>

<table>
  <tr>
    <td width="40%"><img src="docs/screenshots/words.png" width="100%" alt="My words: the saved list with a note on one word, and the banner counting towards the next trophy"></td>
    <td width="60%">
      <h3>📖 My words</h3>
      The words tab keeps two lists: the words you chose to save, each with a note of your own and a
      copy of its Wiktionary entry that opens offline, and every word you have won, collected like
      trophies. Filter by language, search, sort, and watch the banner count towards the next trophy.
    </td>
  </tr>
</table>

<table>
  <tr>
    <td width="60%">
      <h3>🌱 A first game that teaches</h3>
      A new player starts in a guided game, not a lesson: no step counter, one quiet line under the
      board only when it applies, and a hint to try. The tabs open as you play: words after nine
      games, learn after twenty-four. It can be replayed from the you tab.
    </td>
    <td width="40%"><img src="docs/screenshots/first-game.png" width="100%" alt="The first game mid-play: two coloured guesses, a third being typed, and the coloured keyboard"></td>
  </tr>
</table>

<table>
  <tr>
    <td width="40%"><img src="docs/screenshots/reminders.png" width="100%" alt="The reminders page: a switch, the dailies it reminds about, two nudge times with their weekdays, and a sample message"></td>
    <td width="60%">
      <h3>⏰ Reminders</h3>
      On the phone app, a nudge when a daily you chose is still waiting (up to two a day, on the
      weekdays you pick), and optionally one notification when the dailies open. The messages never
      carry a word.
    </td>
  </tr>
</table>

<table>
  <tr>
    <td width="60%">
      <h3>🎛 Mode settings</h3>
      Free play is yours to change for every mode: the word length and tries, how common the answers
      are, the helper, and each mode's own settings such as hearts. The daily never changes, so it
      is the same for everyone.
    </td>
    <td width="40%"><img src="docs/screenshots/mode-settings.png" width="100%" alt="The mode settings page: the daily rules for each mode, the mode pills, and the difficulty grid with word draw and helper choices"></td>
  </tr>
</table>

<table>
  <tr>
    <td width="60%">
      <h3>🔒 Lockdown</h3>
      One word and six tries, with hearts: 10, 7, 5, 3 or 1. A letter in the right place locks
      and stays locked, and a word that is not in the list costs a heart, which breaks with a
      rumble and a crack. The last three hearts throb. It has a daily of its own.
      <a href="https://github.com/aaronified/lexodle/wiki/How-to-play">The rules</a>.
    </td>
    <td width="40%"><img src="docs/screenshots/lockdown.png" width="100%" alt="A lockdown game: two letters locked in the next guess, three hearts left and two lost"></td>
  </tr>
</table>

<table>
  <tr>
    <td width="40%"><img src="docs/screenshots/themed.png" width="100%" alt="A themed game in English: places, each guess with an info dot"></td>
    <td width="60%">
      <h3>🌍 Themed: geography</h3>
      Place names in English only: countries, cities, rivers, mountains, lakes and bays, in their short
      and long forms (<code>indus</code> and Indus River). Only places are valid guesses, the answer is
      drawn by how well known a place is (or from every place), and every guess has an info dot with
      what it is and a link to Wikipedia. More themes are on the way.
      <a href="https://github.com/aaronified/lexodle/wiki/How-to-play">The rules</a>.
    </td>
  </tr>
</table>

<table>
  <tr>
    <td width="60%">
      <h3>🔍 Blind</h3>
      A guess shows only how many letters are right and in place, and how many are right elsewhere,
      in every language. Tap a letter of a guess to pencil a colour on it and keep track of what you
      have worked out. Ten tries by default.
      <a href="https://github.com/aaronified/lexodle/wiki/How-to-play">The rules</a>.
    </td>
    <td width="40%"><img src="docs/screenshots/blind.png" width="100%" alt="A blind game in Indonesian: the counts as big as the tiles, and colours pencilled on a guess"></td>
  </tr>
</table>

<table>
  <tr>
    <td width="40%">
      <h3>🔗 Share a puzzle</h3>
      Send any game as a link: the puzzle alone, with its word hashed so the link does not give it away,
      or with your guesses, which opens already played. The link button is in every game and beside every
      past game in the history. Whoever opens a link plays it as practice, and the Android app opens
      these links itself.
    </td>
    <td width="30%"><img src="docs/screenshots/features/share.png" width="100%" alt="The link button of a game, with its two choices"></td>
    <td width="30%"><img src="docs/screenshots/features/share-history.png" width="100%" alt="The history: a link button beside each past game"></td>
  </tr>
</table>

<table>
  <tr>
    <td width="40%"><img src="docs/screenshots/features/languages.png" width="100%" alt="The list of the 17 languages, each with its flag"></td>
    <td width="60%">
      <h3>🌐 Seventeen languages</h3>
      English, Spanish, French, German, Italian, Portuguese, Dutch, Polish, Swedish, Danish,
      Norwegian, Turkish, Romanian, Czech, Indonesian, Hungarian and Catalan, each with its own
      word list, keyboard letters, daily, streak and achievements.
      <a href="https://github.com/aaronified/lexodle/wiki/Languages">The languages</a>.
    </td>
  </tr>
</table>

<table>
  <tr>
    <td width="60%">
      <h3>🎯 Every guess is analysed</h3>
      <b>Skill</b> says how many bits the guess was expected to gain, <b>luck</b> how the answer fell,
      and <b>risk</b> how far you leaned on a rare big gain. The review steps
      through your game against the best picks at each point.
      <a href="https://github.com/aaronified/lexodle/wiki/Skill-luck-and-risk">What the numbers mean</a>.
    </td>
    <td width="40%"><img src="docs/screenshots/review.png" width="100%" alt="The review of a game: skill, luck and words left per guess"></td>
  </tr>
</table>

<table>
  <tr>
    <td width="40%"><img src="docs/screenshots/features/history.png" width="100%" alt="The overall numbers, a line chart of skill, luck and risk over 50 weeks, and the playstyle card under it"></td>
    <td width="60%">
      <h3>📈 A history that explains your play</h3>
      Every game is kept, however many, with a chart over the last 50 weeks or months of skill,
      luck and risk, and your playstyle card under it.
      <a href="https://github.com/aaronified/lexodle/wiki/History-and-playstyles">History</a>.
    </td>
  </tr>
</table>

<table>
  <tr>
    <td width="60%">
      <h3>🎭 Six playstyles</h3>
      From analyst to gambler: an early habit (maximiser, eliminator or gambler) and an end habit
      (prober or closer), read from how each guess scored. It moves as you play, and each language has its own.
      <a href="https://github.com/aaronified/lexodle/wiki/History-and-playstyles#playstyles">The six</a>.
    </td>
    <td width="40%"><img src="docs/screenshots/features/playstyle.png" width="100%" alt="The playstyle card: a maverick, its habits, and the six styles with those held marked"></td>
  </tr>
</table>

<table>
  <tr>
    <td width="40%"><img src="docs/screenshots/features/learn.png" width="100%" alt="Learn mode: the answer shown, a guess graded against the best picks, and the words that still fit"></td>
    <td width="60%">
      <h3>🎓 Learn mode</h3>
      The answer is shown. Find the guess that cuts the words left the most; each guess is graded
      against the best, with the reason, and a hint and undo are there when you are stuck. Learn
      more besides: the opening (the best first guess, then the best second guess for each colour
      it can show), choose the best of four words in a position, closing (the endgame: which guess
      wins in time), and three words (find a set to play first that tells the answers apart best).
      Progress is kept per language and length.
    </td>
  </tr>
</table>

<table>
  <tr>
    <td width="60%">
      <h3>🧩 A solver for games played elsewhere</h3>
      Type the guesses, tap the colours the other game showed, and get the words left and the next
      guess, aware of the tries you have. It handles the quartet and the relay race too.
      <a href="https://github.com/aaronified/lexodle/wiki/Solver-and-learn-mode">Solver and learn mode</a>.
    </td>
    <td width="40%"><img src="docs/screenshots/features/solver.png" width="100%" alt="The solver: a guess entered with its colours, the words left, and the recommended next guess"></td>
  </tr>
</table>

<table>
  <tr>
    <td width="40%"><img src="docs/screenshots/features/achievements.png" width="100%" alt="Achievements in English with the lex chip: tiered medals, each with its flag and a bar to the next level"></td>
    <td width="60%">
      <h3>🏅 Achievements, by language</h3>
      49 achievements, each earned in a language and wearing its flag, with an all-languages
      view and a tower of babel for completing every language; the ones that count
      languages wear theirs. Playstyle, streak and history are kept per language too.
      <a href="https://github.com/aaronified/lexodle/wiki/Languages">Languages</a> ·
      <a href="https://github.com/aaronified/lexodle/wiki/Achievements">Achievements</a>.
    </td>
  </tr>
</table>

**And also:** an in-app update check for the Android app, a UPI donation button, blanks you can pencil in, a backup file for everything, light and dark themes, and nothing
fetched to draw: fonts, flags and icons are in the app
([offline and privacy](https://github.com/aaronified/lexodle/wiki/Offline-and-privacy)).

## Run it

```
cd app
flutter pub get
flutter test
flutter run -d chrome
```

`flutter build apk` also works; a version tag (`v0.1.0`) makes the [release workflow](.github/workflows/release.yml) build and attach the APK. The [wiki](https://github.com/aaronified/lexodle/wiki) has the file map,
how the [word lists](https://github.com/aaronified/lexodle/wiki/Word-lists) are built, the screenshots and the
deploy ([developing](https://github.com/aaronified/lexodle/wiki/Developing)); the
[paper](docs/paper) has the maths of skill, luck and risk in bits, with its simulations.

## Credits

Words from [wordfreq](https://github.com/rspeer/wordfreq) filtered with Hunspell dictionaries;
meanings from [Wiktionary](https://en.wiktionary.org); JetBrains Mono; [Tabler](https://tabler.io/icons)
icons; [Twemoji](https://github.com/jdecked/twemoji) flags. Licences are in
[the wiki](https://github.com/aaronified/lexodle/wiki/Word-lists#credits-and-licences) and the code is under [LICENSE](LICENSE).
