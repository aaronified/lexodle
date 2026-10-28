# Working in this repo

## Mockups

- A screen that is already built is not redrawn in a mockup. Reproduce it exactly from its code (`app/lib`) and from the screenshots in `docs/screenshots`, in the app's own look: JetBrains Mono, lowercase, hairline borders, flat surfaces, the pink accent on olive-black (dark) or cream (light).
- If an existing screen cannot be replicated faithfully, do not build a variant of it. Show a toast saying it remains as it is.
- Examples: the game modes screen is already built, so the home mockup shows a toast when the mode button is tapped. Settings, history, achievements, how to play and the language popup are the same.
- Check mockup numbers against real data (the word lists in `app/assets/words`), not invented examples.

## Environment

- Dart and Flutter are not installed in the cloud session. App code cannot be compiled or tested there, so design in a mockup first.
