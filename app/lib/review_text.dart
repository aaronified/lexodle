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

/// skill: the guess's expected gain against the best guess's (100).
String skillLine(double skill) =>
    'skill ${skill.round()}: the bits this guess was expected to gain, as a '
    'share of the best guess\'s (100).';

/// luck: the sign says whether the clues were kinder or harsher than usual.
String luckLine(double luck) {
  final r = luck.round();
  return r == 0
      ? 'luck 0: the clues were about average for this guess.'
      : r > 0
      ? 'luck ${signedLuck(luck)}: the clues gained more than usual for this '
            'guess.'
      : 'luck ${signedLuck(luck)}: the clues gained less than usual for this '
            'guess.';
}

/// risk: how far the guess leaned on a rare big gain.
String riskLine(double? risk) => risk == null
    ? 'risk –: nothing to gamble on, one word or one try was left.'
    : risk.round() == 0
    ? 'risk 0: the guess gained about the same however the clues fell.'
    : 'risk ${risk.round()}: the guess usually gains less than expected and '
          'sometimes much more; 100 is the riskiest guess there was.';

/// bits: what the clues gave, against what was expected.
String bitsLine(double gain, double expected) =>
    'bits ${gain.toStringAsFixed(2)}: the clues cut the words by '
    '${gain.toStringAsFixed(2)} bits; the guess was expected to cut '
    '${expected.toStringAsFixed(2)}.';

const bitsHelp =
    'a bit halves the words still possible. each guess gains bits; the line '
    'at the right is the bits needed to find the word. the bar of a guess '
    'starts where the last ended: its mark is what was expected, its length '
    'what the clues gave.';

/// What the table columns mean, in one line each.
const tableHelp = [
  'skill: the expected bits of the guess, against the best guess (100).',
  'luck: plus means the clues gained more than usual, minus less.',
  'risk: how much the guess leaned on a rare big gain (0 for a safe one).',
];

/// The last try: nothing is left to learn.
const lastTryLine =
    'last try: only a word that fits can win; skill is its chance against '
    'the best.';
