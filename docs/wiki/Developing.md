# Developing

The app is in [`app/`](https://github.com/aaronified/lexodle/tree/main/app) (Flutter, Material 3).

```
cd app
flutter pub get
flutter test
flutter run -d chrome
```

`flutter build apk` also works; the `android/` platform is scaffolded.

## File map

| Path | What it is |
| ---- | ---------- |
| `app/lib/logic.dart` | Guess scoring, eligible-word filter, skill, luck, risk and daring, the recommenders, weighted word pick |
| `app/lib/solver.dart`, `multi_solver.dart`, `learn.dart` | The solver (one board, and the quartet / relay race) and learn mode |
| `app/lib/multi_analysis.dart`, `modes.dart` | The maths and the state of the quartet and the relay race |
| `app/lib/keyboard.dart`, `guess_input.dart` | The on-screen keyboard and the row a guess is typed into |
| `app/lib/words.dart`, `difficulty.dart` | The per-language word lists, and the difficulty grid |
| `app/lib/daily.dart`, `clock.dart`, `daily_streak.dart` | The daily word, the trusted clock, and the streak card |
| `app/lib/history.dart`, `replay.dart`, `history_page.dart` | The history tables (saved a month at a time), rebuilding a game from them, and the page |
| `app/lib/analysis.dart`, `period_chart.dart` | Adding games up, overall and by week and month, the expected guesses, and the line chart |
| `app/lib/playstyle.dart`, `style_chip.dart` | The six playstyles and how a player is placed in one |
| `app/lib/store.dart`, `backup.dart` | Settings, the per-language state, the achievement definitions; the backup file |
| `app/lib/achievements_page.dart`, `language_picker.dart` | The achievements page and the flag picker |
| `app/assets/words/` | Generated word lists, one file per language |
| `app/tools/` | Word-list generator, a live Wiktionary check, `calibrate_styles.dart` (simulated players for the playstyle thresholds) and `predict_tries.dart` (tries against skill, luck and daring) |
| `docs/paper/` | The maths of skill, risk, luck and daring, with the experiments |
| `docs/wiki/` | These pages |
| `docs/screenshots/` | The pictures in the README |

`app/tools/live_check.dart` calls the real Wiktionary API (`dart run tools/live_check.dart`); the
unit tests use saved responses and need no network.

## Screenshots

The pictures in the README are taken from the real screens, rendered at phone size in a dark theme
with the app's own fonts and seeded state (a player a few weeks in, with a streak, a playstyle and
some games), so they can be taken again whenever the interface changes. It is a test that only
runs when asked:

```
cd app
LEXODLE_SCREENSHOTS=1 flutter test test/screenshots_test.dart      # PowerShell: $env:LEXODLE_SCREENSHOTS = 1
```

It writes `docs/screenshots/*.png`. A test draws every glyph as a box unless it is given the app's
fonts, so the harness loads them from files in the repository (`test/support/fonts.dart`). It reads
nothing from the Flutter SDK, the system or the network, and any test can use it.

## Deploy

The `Deploy web app to GitHub Pages` workflow tests, builds and publishes `app/` on every push to
`main` that touches `app/` or the workflow. It needs Settings → Pages → Source set to *GitHub
Actions*. You can also run it by hand from the Actions tab. The `wiki` workflow publishes
`docs/wiki` to this wiki.

## The experiments

`app/tools/calibrate_styles.dart` and `predict_tries.dart` (run from `app`, see the head of each)
write their results to `docs/paper/experiments/results`, where the paper reads them.

## The release build does not shrink code

The release build keeps the Android code shrinker (R8) off (`android/app/build.gradle.kts`). With it
on, the release APK lost a method of the `shared_preferences` plugin (`getAll`): every save and
load failed with a `NoSuchMethodError`, which the app swallowed, so no progress survived a restart
(updates and force-stops both looked like data loss). Debug builds do not shrink, so it only showed
in the release APK. `test/release_config_test.dart` fails if the shrinker is turned back on. To turn
it on again, first show with a release build that progress is saved and read after a force-stop.

## The log

Settings has a **log** section. The app writes its own steps to a log kept in its private storage
(`files/logs`, apart from the backups, which are pruned by age): each start, what the load found
(keys, games, played, rows skipped), every save that failed or could not be tried because storage
was not available, backups, restores, update checks and installs, recorded games (mode, length,
won or lost; never words or guesses), and errors. A line is `time level tag: message`, level `I`
(happened), `W` (could be wrong) or `E` (failed).

One run holds the newest 4,000 lines. At the next start it moves to a history of the newest 300,000
characters. **view this run** shows the last lines; **export this run** and **export everything**
save a text file to Downloads (`lexodle-log-run-…txt`, `lexodle-log-all-…txt`) to send with a
problem report. A failed save is counted and shown in the section's summary line.
