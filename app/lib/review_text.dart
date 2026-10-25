import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'wiki_links.dart';

/// The short explanations of the review screens, shared by the single-game and
/// the quartet / relay review so that both read alike. Each is one line; the
/// wiki has the rest, one small link away.

/// How the review screens open a wiki page. Tests set this to catch the page;
/// null means the real launcher.
Future<bool> Function(Uri uri)? wikiOpener;

/// A "learn more" link to [page] for under an explanation.
Widget reviewLink(WikiPage page, {String label = 'learn more'}) => Align(
  alignment: Alignment.centerLeft,
  child: WikiLink(
    page,
    label: label,
    open: (u) => (wikiOpener ?? (x) => launchUrl(x))(u),
  ),
);

/// Luck as a signed whole number, with a real minus sign: +40, −25, 0.
String signedLuck(double v) {
  final r = v.round();
  return r == 0 ? '0' : (r > 0 ? '+$r' : '−${-r}');
}

/// skill: how the guess did against the best real guess (100).
String skillLine(double skill) =>
    'skill ${skill.round()}: how well the guess narrowed the words, against '
    'the best possible guess (100).';

/// luck: the sign says whether the clues were kinder or harsher than usual.
/// (Luck is the chance of a bigger pool less the chance of a smaller one, so
/// plus is a smaller pool than usual.)
String luckLine(double luck) {
  final r = luck.round();
  return r == 0
      ? 'luck 0: the clues were about average for this guess.'
      : r > 0
      ? 'luck ${signedLuck(luck)}: the clues were kinder than usual for this '
            'guess.'
      : 'luck ${signedLuck(luck)}: the clues were harsher than usual for this '
            'guess.';
}

/// What the table columns mean, in one line each.
const tableHelp = [
  'skill: how well the guess narrowed the words, against the best possible '
      'guess (100).',
  'luck: plus means the clues were kinder than usual, minus harsher.',
  'daring: how much you went for the word itself, not the clues (0 for a probe).',
];

/// The last try: nothing is left to learn.
const lastTryLine =
    'last try: only a word that fits can win; skill is its chance against '
    'the best.';
