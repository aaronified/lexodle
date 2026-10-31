import 'logic.dart' show Mark;

/// A submitted blind guess with its counts: right and in place, right
/// elsewhere.
class BlindRow {
  const BlindRow(this.word, this.green, this.yellow);
  final String word;
  final int green;
  final int yellow;
}

/// The colours a player of a blind game pencils on letters, with the rules
/// they must keep. Green and yellow belong to a letter at a position, grey to a
/// letter. A letter is green in at most one position, and a position is green
/// with at most one letter. A letter is yellow in at most length - 1 positions,
/// and when it is yellow in every other position it can still be, it can only
/// be green. A letter that is green or yellow cannot be grey. A row cannot have
/// more green, right or wrong letters than its counts say.
class BlindPencil {
  BlindPencil(this.length);

  final int length;
  final green = <String, int>{};
  final yellow = <String, Set<int>>{};
  final grey = <String>{};

  void clear() {
    green.clear();
    yellow.clear();
    grey.clear();
  }

  BlindPencil _copy() {
    final c = BlindPencil(length);
    c.green.addAll(green);
    for (final e in yellow.entries) {
      c.yellow[e.key] = {...e.value};
    }
    c.grey.addAll(grey);
    return c;
  }

  void _become(BlindPencil o) {
    clear();
    green.addAll(o.green);
    for (final e in o.yellow.entries) {
      yellow[e.key] = {...e.value};
    }
    grey.addAll(o.grey);
  }

  /// What the counts settle outright: a guess with no right letters rules all
  /// its letters out; one whose counts add up to the length has all its
  /// letters in the word, and every other letter of [letters] out.
  static Map<String, Mark> deduce(
    List<BlindRow> rows,
    Iterable<String> letters,
  ) {
    final d = <String, Mark>{};
    for (final r in rows) {
      final hit = r.green + r.yellow;
      if (hit == 0) {
        for (final ch in r.word.split('')) {
          d[ch] = Mark.absent;
        }
      } else if (hit == r.word.length) {
        for (final ch in letters) {
          d[ch] = r.word.contains(ch) ? Mark.present : Mark.absent;
        }
      }
    }
    return d;
  }

  /// The colour shown on letter [ch] at position [p]: what the counts settle
  /// first, then the player's own.
  Mark? shown(String ch, int p, Map<String, Mark> d) {
    final x = d[ch];
    if (x == Mark.absent) return Mark.absent;
    if (green[ch] == p) return Mark.correct;
    if (x == Mark.present) return Mark.present;
    if (yellow[ch]?.contains(p) ?? false) return Mark.present;
    if (grey.contains(ch)) return Mark.absent;
    return null;
  }

  /// The colour of each letter on the keyboard.
  Map<String, Mark> keyboard(Map<String, Mark> d) {
    final out = <String, Mark>{};
    for (final ch in {...green.keys, ...yellow.keys, ...grey, ...d.keys}) {
      final x = d[ch];
      if (x == Mark.absent) {
        out[ch] = Mark.absent;
      } else if (green.containsKey(ch)) {
        out[ch] = Mark.correct;
      } else if (x == Mark.present || (yellow[ch]?.isNotEmpty ?? false)) {
        out[ch] = Mark.present;
      } else if (grey.contains(ch)) {
        out[ch] = Mark.absent;
      }
    }
    return out;
  }

  bool _present(String ch, Map<String, Mark> d) =>
      d[ch] != Mark.absent &&
      (green.containsKey(ch) ||
          d[ch] == Mark.present ||
          (yellow[ch]?.isNotEmpty ?? false));

  /// Why the pencil breaks a rule, or null. [focus] is the letter being
  /// pencilled, so the reason can speak of it.
  String? _violation(String focus, List<BlindRow> rows, Map<String, Mark> d) {
    // a position is green with one letter only
    final at = <int, String>{};
    for (final e in green.entries) {
      if (d[e.key] == Mark.absent) continue;
      final other = at[e.value];
      if (other != null) {
        final who = e.key == focus ? other : e.key;
        return 'position ${e.value + 1} is already green with $who';
      }
      at[e.value] = e.key;
    }
    // a letter that is green or yellow is not grey
    for (final ch in grey) {
      if (d[ch] == null && _present(ch, d)) {
        return '$ch is already green or yellow';
      }
    }
    // a letter that is yellow needs a position left to be in
    final letters = <String>{...green.keys, ...yellow.keys};
    for (final e in d.entries) {
      if (e.value == Mark.present) letters.add(e.key);
    }
    for (final ch in letters) {
      if (!_present(ch, d) || green.containsKey(ch)) continue;
      final no = <int>{...?yellow[ch]};
      if (d[ch] == Mark.present) {
        for (final r in rows) {
          for (var i = 0; i < r.word.length; i++) {
            if (r.word[i] == ch) no.add(i);
          }
        }
      }
      var left = 0;
      for (var p = 0; p < length; p++) {
        if (no.contains(p)) continue;
        final g = at[p];
        if (g != null && g != ch) continue;
        left++;
      }
      if (left == 0) {
        return ch == focus
            ? 'already yellow in all other available positions'
            : '$ch would have no position left';
      }
    }
    // a row cannot show more than its counts
    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      var greens = 0, wrong = 0;
      final right = <String>{};
      for (var i = 0; i < row.word.length; i++) {
        final ch = row.word[i];
        final m = shown(ch, i, d);
        if (m == Mark.correct) greens++;
        if (m == Mark.correct || m == Mark.present) right.add(ch);
        if (m == Mark.absent) wrong++;
      }
      if (greens > row.green) {
        return 'row ${r + 1} has only ${row.green} in place';
      }
      if (right.length > row.green + row.yellow) {
        return 'row ${r + 1} has only ${row.green + row.yellow} right';
      }
      final out = row.word.length - row.green - row.yellow;
      if (wrong > out) return 'row ${r + 1} has only $out wrong';
    }
    return null;
  }

  void _set(String ch, int p, Mark? m) {
    if (green[ch] == p) green.remove(ch);
    final ys = yellow[ch];
    if (ys != null) {
      ys.remove(p);
      if (ys.isEmpty) yellow.remove(ch);
    }
    switch (m) {
      case null:
        grey.remove(ch);
      case Mark.correct:
        grey.remove(ch);
        final q = green[ch];
        green[ch] = p;
        // the older green goes back to yellow
        if (q != null && q != p) (yellow[ch] ??= {}).add(q);
      case Mark.present:
        grey.remove(ch);
        (yellow[ch] ??= {}).add(p);
      case Mark.absent:
        grey.add(ch);
    }
  }

  static const _cycle = <Mark?>[Mark.correct, Mark.present, Mark.absent, null];

  /// A tap on letter [ch] at position [p]: the next colour of none, green,
  /// yellow, grey that keeps the rules. Returns why a colour was passed over,
  /// or null.
  String? tap(String ch, int p, List<BlindRow> rows, Map<String, Mark> d) {
    if (d[ch] == Mark.absent) return 'ruled out by the counts';
    final now = shown(ch, p, d);
    final List<Mark?> order;
    if (d[ch] == Mark.present) {
      // settled as in the word: only yellow and green
      order = [now == Mark.correct ? Mark.present : Mark.correct];
    } else {
      final i = _cycle.indexOf(now);
      order = [for (var k = 1; k <= _cycle.length; k++) _cycle[(i + k) % 4]];
    }
    String? passed;
    for (final m in order) {
      final hyp = _copy().._set(ch, p, m);
      final why = m == null ? null : hyp._violation(ch, rows, d);
      if (why == null) {
        _become(hyp);
        return passed;
      }
      passed ??= why;
    }
    return passed;
  }
}
