# Working in this repo

## Mockups

- A screen that is already built is not redrawn in a mockup. Reproduce it exactly from its code (`app/lib`) and from the screenshots in `docs/screenshots`, in the app's own look: JetBrains Mono, lowercase, hairline borders, flat surfaces, the pink accent on olive-black (dark) or cream (light).
- If an existing screen cannot be replicated faithfully, do not build a variant of it. Show a toast saying it remains as it is.
- A screen the change touches is built in the mockup: copy it exactly from the code, then apply the change (the game modes screen and the achievements screen for the daily quartet and relay and the tiered achievements). A screen the change does not touch is not built: tapping it shows a toast that it remains as it is (settings, history, how to play, the language popup, the solver, learn).
- Check mockup numbers against real data (the word lists in `app/assets/words`), not invented examples.

## Environment

- Dart and Flutter are not installed in the cloud session, but they can be: download the Flutter SDK from storage.googleapis.com into `/home/user/sdk` (pub.dev is reachable; the GitHub flutter repo is not), then `flutter pub get`, `dart analyze` and `flutter test` in `app`. Design in a mockup first, then build and test.
- No LaTeX is installed: check `docs/paper/*.tex` with `python docs/paper/check_tex.py`, and say the PDFs are stale.

## Delegation

- For simple, straightforward coding jobs, use Haiku subagents.
- The lead acts as the Lead Mobile Architect: it produces the system architecture, writes the core state management, and breaks UI features down into small, isolated tasks for Haiku subagents to code.
- Break complex problems into byte-size pieces a Haiku can deal with.
- Haiku subagents never improvise. If something in the task is unclear, missing or does not fit, they stop and report the issue. The lead solves it and messages them back with the altered parameters.
- The lead reviews their work, fixes what is needed, and merges the PRs once they are green.
- Every Haiku-written piece of code that can fail (network lookups, storage, JSON, async callbacks, navigation) is wrapped in try/catch, and every caught issue is reported to the app log (`appLog.w` or `appLog.e` from `lib/app_log.dart`, with a short tag and the error), never swallowed silently. The app keeps working: it degrades, and logs. The log never records words or guesses, so log the error's type (`${e.runtimeType}`), not its text, which can carry a word or a URL.

## Testing and merging

- Do not run the full test suite locally: CI runs it on every pull request, so work goes through a PR on the working branch and the lead reads the CI result. Locally, run only what is needed to get a change compiling (`dart analyze` and the one test file being written), never the whole suite.
- A PR is opened for the work, reviewed, fixed if CI is red, and merged by the lead once it is green.
