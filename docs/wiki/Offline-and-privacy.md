# Offline and privacy

Everything the app draws with is in the app, so a page or a phone asks no other site for a font, an
emoji, an icon or a flag:

- **Text** is JetBrains Mono, bundled. `python tools/check_glyphs.py` run from
  `app` (needs `pip install fonttools`) checks that it has every character the app can show: all the letters of
  every word list, the language names and the interface text. A character it lacked would be drawn
  from a fallback font, which a web page fetches from a font server.
- **Flags** are SVG files in `app/assets/flags` (the Twemoji graphics, and the Catalan flag drawn
  for the project), not emoji: an emoji needs a font the device may not have, Windows draws no
  flags, and a web page fetches an emoji font.
- **Icons** are the Tabler SVGs in `app/assets/icons`; the Material icons font ships with Flutter.
- **The web build** is made with `--no-web-resources-cdn` (see the deploy workflow), so CanvasKit
  is served with the app instead of from a CDN.

What the app does ask for:

- **Wiktionary**, for the meaning of a word. Each language is looked up in its own edition:
  en.wiktionary.org for English; fr, es, it, pt, ca, ro, de, nl, sv, da, pl, cs, hu, tr and id on
  the edition with that code; Norwegian (nb) on no.wiktionary.org. The answer is looked up as soon
  as a game starts, so the end screen has it (in the mastermind, when one word is left), and when
  you save a word or retry a saved one. The word looked up is sent; your name, games and guesses
  are not. A saved word keeps a copy of its entry and opens without a lookup.
- **English Wikipedia**, at the end of a geography game: the app asks for the place's summary and
  photo (en.wikipedia.org, and the photo from upload.wikimedia.org). Only the place is asked for,
  nothing else is sent. The map is drawn in the app.
- **Pronunciation audio**, from upload.wikimedia.org (Wikimedia Commons), only when you tap the
  speaker.
- **The time**, from the site the app is hosted on (see [Daily word](Daily-word)).
- **Updates** (Android only): unless "check automatically" is off, the app asks GitHub's releases
  API (api.github.com, no account) for the newest version each time it opens. Updating downloads the
  APK from the GitHub release. See [Updates and support](Updates-and-support).

If any of these cannot be reached the game carries on, quietly.

The opening of a word list (the best first guess, scored ahead) is the one other thing it asks for:
the web app reads it from this repository's `precomputed` branch on GitHub when a list is large, and
the phone downloads it only when you tap download in the settings (**faster openings**), after being
told the size. Both are plain requests for a public file; nothing about you or your games is sent.
Without them the app works the opening out itself, slower.

Links (learn more, the entry on Wiktionary, a place on Wikipedia, the UPI button) are opened by your
browser or UPI app only when you tap them. Nothing else leaves the device.

## Permissions (Android)

Internet, notifications (asked only when you switch reminders on) and run at startup (so reminders
come back after a restart). No storage, location, contacts or camera permission. The Downloads copy
of a backup needs none.

## What is kept, and where

Your games, playstyles, streaks and achievements are kept in the browser's storage (or the
phone's). The backup in the settings saves them all, per language, as one file you keep: with them
go the settings and reminders, the learn history, the saved words (with their entries), the
collected words and the lex balance. Not in it: your profile name and avatar, and the optional
photo.

- **Reminders** are local notifications scheduled on the phone (Android only). Nothing is sent.
- **The profile photo** is a copy of a picture you chose, kept as `profile.jpg` in the app's own
  storage on the phone. It is never uploaded and never backed up.
- **Also on the phone**, in the app's own files: the log (`files/logs`), the automatic backups
  (`files/backups`), downloaded openings (`files/lexodle-precomputed`) and a cache of up to ten
  openings.
