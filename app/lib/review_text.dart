import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'daily.dart';
import 'modes.dart';
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
    : 'risk ${risk.round()}: usually gains less than expected, sometimes much '
          'more; 100 is the riskiest guess.';

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

/// How the answer of a game was drawn, which is also the chances the scores
/// weigh the possible words by: the curve (a daily from [dailyCurveFrom], or the
/// setting), the old daily (the 3,000 commonest words, each as likely), every
/// word equally, or by frequency.
enum DrawKind {
  curve,
  oldDaily,
  equal,
  frequency,

  /// The themed wordle: the best known places on a curve, or every place.
  placesCurve,
  placesEqual,

  /// A made wordle: a word a friend chose, not drawn.
  chosen,
}

/// The [DrawKind] of a game drawn under [draw]; a daily ([daily] is its date)
/// has its own rule.
DrawKind drawKindOf(
  Draw draw, {
  String daily = '',
  GameMode? mode,
  bool chosen = false,
}) => chosen
    ? DrawKind.chosen
    : mode == GameMode.themed
    ? (draw == Draw.equal ? DrawKind.placesEqual : DrawKind.placesCurve)
    : daily.isNotEmpty
    ? (dailyUsesCurve(daily) ? DrawKind.curve : DrawKind.oldDaily)
    : switch (draw) {
        Draw.sigmoid => DrawKind.curve,
        Draw.equal => DrawKind.equal,
        Draw.frequency => DrawKind.frequency,
      };

String _thousands(int n) => n.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+$)'),
  (m) => '${m[1]},',
);

/// The chances in a few words.
String drawPhrase(DrawKind kind) {
  switch (kind) {
    case DrawKind.curve:
      return 'the commonest 2,500 words about equally likely, then fewer and '
          'fewer, and almost none past the 3,500th';
    case DrawKind.oldDaily:
      return 'the ${_thousands(dailyAnswers)} commonest words, each equally '
          'likely';
    case DrawKind.equal:
      return 'every word of the length equally likely';
    case DrawKind.frequency:
      return 'each word by how common it is';
    case DrawKind.placesCurve:
      return 'the best known 1,200 places about equally likely, then fewer '
          'and fewer, and almost none past the 2,000th';
    case DrawKind.placesEqual:
      return 'every place of the length equally likely';
    case DrawKind.chosen:
      return 'a word a friend chose, as likely as any word of the list';
  }
}

/// The sentence for the skill section: the chances it is worked out under.
String skillDrawLine(DrawKind kind, {bool daily = false}) =>
    'skill counts each word still possible by its chance of being '
    '${daily ? "the daily's word" : 'the answer'}: ${drawPhrase(kind)}.';

/// The sentence for the luck section: the same chances.
String luckDrawLine(DrawKind kind, {bool daily = false}) =>
    'luck is measured against the same chances'
    '${daily ? ' as the daily was drawn by' : ' as the answer was drawn by'}: '
    '${drawPhrase(kind)}.';

/// For the skill section of a blind game: what its outcomes are.
const blindLine =
    'a blind guess shows only how many letters are right and in place, and '
    'how many are right elsewhere: its outcomes are those count pairs, at '
    'most 20 for five letters, not the tile patterns.';
