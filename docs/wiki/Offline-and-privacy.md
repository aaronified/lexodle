# Offline and privacy

Everything the app draws with is in the app, so a page or a phone asks no other site for a font, an
emoji, an icon or a flag:

- **Text** is JetBrains Mono, bundled. `python app/tools/check_glyphs.py` (needs
  `pip install fonttools`) checks that it has every character the app can show: all the letters of
  every word list, the language names and the interface text. A character it lacked would be drawn
  from a fallback font, which a web page fetches from a font server.
- **Flags** are SVG files in `app/assets/flags` (the Twemoji graphics, and the Catalan flag drawn
  for the project), not emoji: an emoji needs a font the device may not have, Windows draws no
  flags, and a web page fetches an emoji font.
- **Icons** are the Tabler SVGs in `app/assets/icons`; the Material icons font ships with Flutter.
- **The web build** is made with `--no-web-resources-cdn` (see the deploy workflow), so CanvasKit
  is served with the app instead of from a CDN.

What the app does ask for is Wiktionary, for the meaning of the answer when a game ends, and the
time, from the site it is hosted on (see [Daily word](Daily-word)). If either cannot be reached
the game carries on, quietly.

Nothing else leaves the device. Your games, playstyles, streaks and achievements are kept in the
browser's storage (or the phone's); the backup in the settings saves them all, per language, as one
file you keep.
