---
name: changelog
description: Write the changelog entry for a change in CHANGELOG.md. Use after any user-visible change, or before a release, to add points under "Unreleased".
---

# Writing the changelog

Edit `CHANGELOG.md`, section `## Unreleased` (create it at the top if missing).

One point per user-visible change:

```
- summary line
  details, indented two spaces, as many lines as needed
```

- **Summary** (the `- ` line): shown in the app after an update. Lowercase, plain
  words, what changed for the player, under 80 characters, no period, no
  commit jargon.
- **Details** (indented lines): shown only in the GitHub release notes and
  `CHANGELOG.md`. Say why, what exactly changed, numbers, and what is untouched.
- Skip changes the player cannot see (refactors, tests, CI).
- Merge into an existing point when the same feature changes twice.
- Check any number against the real data (`app/assets/words`).

Do not touch `app/assets/changelog.txt` (the release workflow fills it) or add a
version heading (the workflow renames `Unreleased` to the version).
