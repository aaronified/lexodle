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
    <td align="center"><img src="docs/screenshots/home.png" alt="The home screen: language, daily streak with a week of fires, letters, difficulty grid, and the player's playstyle at the top right" width="230"></td>
    <td align="center"><img src="docs/screenshots/game.png" alt="A daily in play, with a blank pencilled into the third tile of the next guess" width="230"></td>
    <td align="center"><img src="docs/screenshots/quartet.png" alt="A quartet: four boards sharing every guess, with split keys on the keyboard" width="230"></td>
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
    <td width="40%"><img src="docs/screenshots/game.png" width="100%" alt="A daily in play, with a blank pencilled into the third tile"></td>
  </tr>
</table>

<table>
  <tr>
    <td width="40%"><img src="docs/screenshots/quartet.png" width="100%" alt="A quartet: four boards sharing every guess"></td>
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
      <h3>🎯 Every guess is scored</h3>
      <b>Skill</b> says how well the guess split the words left, <b>luck</b> how the answer fell,
      and <b>daring</b> how far you went for the word instead of the clues. The review steps
      through your game against the best picks at each point.
      <a href="https://github.com/aaronified/lexodle/wiki/Skill-luck-and-risk">What the numbers mean</a>.
    </td>
    <td width="40%"><img src="docs/screenshots/review.png" width="100%" alt="The review of a game: skill, luck and words left per guess"></td>
  </tr>
</table>

<table>
  <tr>
    <td width="40%"><img src="docs/screenshots/features/history.png" width="100%" alt="The overall numbers and a line chart of skill, luck, daring and expected guesses over 50 weeks"></td>
    <td width="60%">
      <h3>📈 A history that explains your play</h3>
      Every game is kept, however many, with a chart over the last 50 weeks or months of skill,
      luck, daring and the guesses a game is expected to take, broken into what each one added
      or took off.
      <a href="https://github.com/aaronified/lexodle/wiki/History-and-playstyles">History</a>.
    </td>
  </tr>
</table>

<table>
  <tr>
    <td width="60%">
      <h3>🎭 Six playstyles</h3>
      From analyst to wildcard: skill tells how sharp you are, daring whether you work the clues or
      go for the word. It moves as you play, and each language has its own.
      <a href="https://github.com/aaronified/lexodle/wiki/History-and-playstyles#playstyles">The six</a>.
    </td>
    <td width="40%"><img src="docs/screenshots/features/playstyle.png" width="100%" alt="The playstyle card: a maverick, its skill and daring, and the six styles with those held marked"></td>
  </tr>
</table>

<table>
  <tr>
    <td width="40%"><img src="docs/screenshots/features/learn.png" width="100%" alt="Learn mode: the answer shown, a guess graded against the best picks, and the words that still fit"></td>
    <td width="60%">
      <h3>🎓 Learn mode</h3>
      The answer is shown. Find the guess that cuts the words left the most; each guess is graded
      against the best, and the words that still fit are listed at the bottom.
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
    <td width="40%"><img src="docs/screenshots/features/achievements.png" width="100%" alt="Achievements in English, each with its flag; bilingual shows three flags"></td>
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
[paper](docs/paper) has the maths of skill, risk, luck and daring with its experiments.

## Credits

Words from [wordfreq](https://github.com/rspeer/wordfreq) filtered with Hunspell dictionaries;
meanings from [Wiktionary](https://en.wiktionary.org); JetBrains Mono; [Tabler](https://tabler.io/icons)
icons; [Twemoji](https://github.com/jdecked/twemoji) flags. Licences are in
[the wiki](https://github.com/aaronified/lexodle/wiki/Word-lists#credits-and-licences) and the code is under [LICENSE](LICENSE).
