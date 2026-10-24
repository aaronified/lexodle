# Updates and support

## Updating the Android app

Each release is an APK attached to a [GitHub release](https://github.com/aaronified/lexodle/releases).
In the settings (Android only; the web page is always the latest) the **updates** section shows the
version and has:

- **check for updates**: asks GitHub's releases API for the newest release (one request, no account).
  It reads the tag as dotted numbers and compares it with this build's version number by number.
  A newest release without its APK reads as up to date, since the file is uploaded a minute after
  the release appears.
- **update**: appears when a newer version exists. It checks again first (for the newest version and
  its checksum), downloads the APK into the app's own storage (no storage permission), checks the
  SHA-256 GitHub gives for it, and opens Android's installer. If Android has not allowed lexodle to
  install apps, it says to turn on "Install unknown apps" for it, then try again. A download can be
  cancelled, and one that goes quiet for a minute counts as failed.
- **check automatically**: off until you choose it. When on, the app looks once a day, when it opens,
  and remembers what it found. Each check is a request to GitHub, which is why it is off by default.

Releases are built by a workflow when a version tag like `v0.1.2` is pushed, and signed with the
release key held in repository secrets; the version in `app/pubspec.yaml` must match the tag. A
build signed with a different key cannot be updated over one signed with another.

## Support

Lexodle is free and has no ads. The settings have a **support lexodle** section with a UPI ID
(copy it), its QR code (scan it from any UPI app) and a button that opens a UPI app with the payee
filled in; the amount is up to you. The app sends nothing: the code is drawn once by
`app/tools/make_donate_qr.py` and bundled.
