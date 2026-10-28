# Working in this repo

## Mockups

- A screen that is already built is not redrawn in a mockup. Reproduce it exactly from its code (`app/lib`) and from the screenshots in `docs/screenshots`, in the app's own look: JetBrains Mono, lowercase, hairline borders, flat surfaces, the pink accent on olive-black (dark) or cream (light).
- If an existing screen cannot be replicated faithfully, do not build a variant of it. Show a toast saying it remains as it is.
- A screen the change touches is built in the mockup: copy it exactly from the code, then apply the change (the game modes screen and the achievements screen for the daily quartet and relay and the tiered achievements). A screen the change does not touch is not built: tapping it shows a toast that it remains as it is (settings, history, how to play, the language popup, the solver, learn).
- Check mockup numbers against real data (the word lists in `app/assets/words`), not invented examples.

## Environment

- Dart and Flutter are not installed in the cloud session, but they can be: download the Flutter SDK from storage.googleapis.com into `/home/user/sdk` (pub.dev is reachable; the GitHub flutter repo is not), then `flutter pub get`, `dart analyze` and `flutter test` in `app`. Design in a mockup first, then build and test.
- No LaTeX is installed: check `docs/paper/*.tex` with `python docs/paper/check_tex.py`, and say the PDFs are stale.
