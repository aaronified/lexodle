/// The row a guess is typed into: [length] slots, a cursor, and blanks.
///
/// A blank is a pencil mark, not a letter: `a_ode` records that the second
/// letter is not known yet. It lives only here; a guess can be submitted only
/// when [complete], so a blank never reaches scoring, the word lists or the
/// analysis.
///
/// The cursor is the slot the next letter goes into. Typing fills it and moves
/// on to the next slot that is not a letter (wrapping round to the first one),
/// so after `a_ode` the cursor sits on the blank, ready for the missing letter.
/// When every slot is a letter the cursor parks past the end and typing does
/// nothing until a tile is selected, as a full row always did. Backspace clears
/// the selected slot, or, from an empty one, the slot before it.
class GuessInput {
  GuessInput(this.length) : _slots = List.filled(length, '');

  /// What a blank slot holds (the space bar types it).
  static const blank = ' ';

  final int length;
  final List<String> _slots;
  int _cursor = 0;

  /// The selected slot, or [length] when the row is full and nothing is.
  int get cursor => _cursor;

  /// Each slot: '' when untouched, [blank], or a letter.
  List<String> get slots => List.unmodifiable(_slots);

  String slot(int i) => _slots[i];

  bool isLetter(int i) => _slots[i].isNotEmpty && _slots[i] != blank;

  bool get hasBlank => _slots.contains(blank);

  /// Every slot holds a letter, so the row is a guess that can be submitted.
  bool get complete => List.generate(length, isLetter).every((l) => l);

  /// The guess; meaningful only when [complete].
  String get word => _slots.join();

  /// Types [ch] at the cursor: a letter of [letters], or a blank for a space or
  /// an underscore. Returns the slot written, or -1 when nothing was.
  int type(String ch, Set<String> letters) {
    final c = ch == '_' ? blank : ch;
    if (_cursor >= length || (c != blank && !letters.contains(c))) return -1;
    final at = _cursor;
    _slots[at] = c;
    _cursor = _nextOpen(at);
    return at;
  }

  /// Clears the selected slot, or from an empty one the slot before it. Returns
  /// the slot cleared, or -1 when there was nothing to clear.
  int back() {
    var at = _cursor;
    if (at >= length || _slots[at].isEmpty) at--;
    if (at < 0) return -1;
    _slots[at] = '';
    _cursor = at;
    return at;
  }

  /// Selects slot [i] (a tap on its tile).
  void select(int i) {
    if (i >= 0 && i < length) _cursor = i;
  }

  void clear() {
    _slots.fillRange(0, length, '');
    _cursor = 0;
  }

  /// Puts a whole word in, as the solver's "use this" does.
  void setWord(String word) {
    for (var i = 0; i < length; i++) {
      _slots[i] = i < word.length ? word[i] : '';
    }
    _cursor = _nextOpen(-1);
  }

  /// The first slot after [from] that is not a letter, else the first anywhere,
  /// else [length] (the row is full).
  int _nextOpen(int from) {
    for (var i = from + 1; i < length; i++) {
      if (!isLetter(i)) return i;
    }
    for (var i = 0; i <= from && i < length; i++) {
      if (!isLetter(i)) return i;
    }
    return length;
  }
}
