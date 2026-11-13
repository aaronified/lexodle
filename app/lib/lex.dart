import 'medal.dart';
import 'store.dart';

/// Lex, the hint currency (issue #89): earned with achievements, spent on
/// hints. This file is the logic only; [AppState] keeps one [Lex] and saves it.

/// The three hints and what each costs in lex.
enum HintKind {
  grey(10),
  yellow(25),
  green(50);

  const HintKind(this.price);
  final int price;

  static HintKind? named(Object? n) {
    for (final k in values) {
      if (k.name == n) return k;
    }
    return null;
  }
}

/// A new player starts with this many free hints (the first one is a free
/// trial; see the issue comments).
const startingFreeHints = 1;

/// A new player sees lex from this game on (the 10th); a veteran, at once.
const lexUnlockGames = 10;

/// The most ledger lines kept (the oldest go first), to bound what is saved.
const lexLedgerCap = 500;

/// What a medal earns: bronze 1, silver 2, gold 3, platinum 5.
int medalValue(Medal m) => switch (m) {
  Medal.bronze => 1,
  Medal.silver => 2,
  Medal.gold => 3,
  Medal.platinum => 5,
};

/// The one-time starting grant of a veteran: the sum of the [medalValue] of
/// every achievement level already held. [held] is the achievement states
/// (the global ones, and each language's). A level held is one below
/// [AchState.times]; an achievement without levels counts as one bronze once
/// earned.
///
/// AWAITING PRODUCT CONFIRMATION: the formula is not final (issue #89, the
/// last comment). In particular this counts every level held (bronze, silver,
/// gold and platinum of one achievement all pay), in every language, not only
/// the highest level of each.
int veteranGrant(Iterable<Map<String, AchState>> held) {
  var total = 0;
  for (final states in held) {
    for (final e in states.entries) {
      final a = achievementById(e.key);
      final times = e.value.times;
      if (a == null || times <= 0) continue;
      if (a.levels.isEmpty) {
        total += medalValue(Medal.bronze);
        continue;
      }
      for (var i = 0; i < times && i < a.count; i++) {
        total += medalValue(a.levels[i].medal);
      }
    }
  }
  return total;
}

/// One hint bought (or taken free) in a game.
class HintPurchase {
  HintPurchase(this.kind, this.free, this.guesses);
  final HintKind kind;

  /// Paid with a free hint, not lex.
  final bool free;

  /// How many guesses the game had when it was taken: it can be undone only
  /// while the game still has this many.
  final int guesses;
}

/// The hints one game has used, for the game screen to hold. A game with any
/// hint in it pays no lex (see [Lex.earn]); its kinds go on the [GameResult].
class GameHints {
  final _bought = <HintPurchase>[];

  List<HintPurchase> get bought => List.unmodifiable(_bought);
  bool get hinted => _bought.isNotEmpty;
  List<HintKind> get kinds => [for (final p in _bought) p.kind];
}

/// One line of the ledger: lex gained or lost (0 for a free hint) and why
/// (`earn:<achievement>:<level>`, `hint:<kind>`, `free:<kind>`,
/// `refund:<kind>`, `refund-free:<kind>`, `grant`). Never a word or a guess.
class LexEntry {
  const LexEntry(this.at, this.delta, this.why, [this.lang = '']);
  final int at;
  final int delta;
  final String why;
  final String lang;

  List<Object> toJson() => [at, delta, why, lang];

  static LexEntry? fromJson(Object? j) {
    if (j is! List || j.length < 3) return null;
    final at = j[0], d = j[1], w = j[2];
    if (at is! int || d is! int || w is! String) return null;
    return LexEntry(
      at,
      d,
      w,
      j.length > 3 && j[3] is String ? j[3] as String : '',
    );
  }
}

/// The balance, the free hints and the ledger.
class Lex {
  Lex();

  int balance = 0;
  int freeHints = startingFreeHints;

  /// Whether the starting grant has been decided (once, ever).
  bool activated = false;

  /// Whether the player was a veteran at activation, so sees lex at once.
  bool veteran = false;

  final ledger = <LexEntry>[];

  /// The day each achievement last paid, per language (`lang|id` -> date): an
  /// achievement pays once a day in a language.
  final _paid = <String, String>{};

  void _log(int at, int delta, String why, [String lang = '']) {
    ledger.add(LexEntry(at, delta, why, lang));
    if (ledger.length > lexLedgerCap) {
      ledger.removeRange(0, ledger.length - lexLedgerCap);
    }
  }

  /// Gives the one-time starting grant of [grant] lex; false when it was done
  /// before. [veteran]: the player has history, so sees lex at once.
  bool activate(int grant, {required bool veteran, int? now}) {
    if (activated) return false;
    activated = true;
    this.veteran = veteran;
    if (grant > 0) {
      balance += grant;
      _log(now ?? DateTime.now().millisecondsSinceEpoch, grant, 'grant');
    }
    return true;
  }

  /// Pays for the achievements a finished game of [lang] earned on [today]
  /// (local date, `2026-11-13`) and returns the lex paid. Only the highest
  /// level of each achievement pays, repeats pay in full, an achievement pays
  /// once a day per language, and a [hinted] game pays nothing (and uses up
  /// no day).
  int earn(
    Iterable<Achievement> earned, {
    required String lang,
    required String today,
    required bool hinted,
    int? now,
  }) {
    if (hinted) return 0;
    var paid = 0;
    final at = now ?? DateTime.now().millisecondsSinceEpoch;
    for (final a in topLevels(earned.toList())) {
      final key = '$lang|${a.id}';
      if (_paid[key] == today) continue;
      final v = medalValue(a.medal);
      _paid[key] = today;
      balance += v;
      paid += v;
      _log(at, v, 'earn:${a.id}:${a.level}', lang);
    }
    return paid;
  }

  /// Whether [kind] can be taken now, with a free hint or with lex.
  bool canAfford(HintKind kind, {bool free = false}) =>
      free ? freeHints > 0 : balance >= kind.price;

  /// Takes a hint into [game] when the player has [guesses] guesses made;
  /// null (nothing changes) when they cannot pay.
  HintPurchase? spend(
    GameHints game,
    HintKind kind, {
    required int guesses,
    bool free = false,
    int? now,
  }) {
    if (!canAfford(kind, free: free)) return null;
    final at = now ?? DateTime.now().millisecondsSinceEpoch;
    if (free) {
      freeHints--;
      _log(at, 0, 'free:${kind.name}');
    } else {
      balance -= kind.price;
      _log(at, -kind.price, 'hint:${kind.name}');
    }
    final p = HintPurchase(kind, free, guesses);
    game._bought.add(p);
    return p;
  }

  /// Undoes the last hint of [game] and gives back what it cost, allowed only
  /// while the game still has the guesses it had then (no guess since). False
  /// when it cannot be undone.
  bool refund(GameHints game, {required int guesses, int? now}) {
    if (game._bought.isEmpty || game._bought.last.guesses != guesses) {
      return false;
    }
    final p = game._bought.removeLast();
    final at = now ?? DateTime.now().millisecondsSinceEpoch;
    if (p.free) {
      freeHints++;
      _log(at, 0, 'refund-free:${p.kind.name}');
    } else {
      balance += p.kind.price;
      _log(at, p.kind.price, 'refund:${p.kind.name}');
    }
    return true;
  }

  Map<String, dynamic> toJson() => {
    'balance': balance,
    'free': freeHints,
    'activated': activated,
    'veteran': veteran,
    'ledger': [for (final e in ledger) e.toJson()],
    'paid': _paid,
  };

  /// The lex in [j]; what is not valid is left out rather than refusing the
  /// whole (a negative number, a bad line).
  static Lex fromJson(Object? j) {
    final l = Lex();
    if (j is! Map) return l;
    final b = j['balance'], f = j['free'];
    if (b is int && b >= 0) l.balance = b;
    if (f is int && f >= 0) l.freeHints = f;
    l.activated = j['activated'] == true;
    l.veteran = j['veteran'] == true;
    final led = j['ledger'];
    if (led is List) {
      for (final x in led) {
        final e = LexEntry.fromJson(x);
        if (e != null) l.ledger.add(e);
      }
      if (l.ledger.length > lexLedgerCap) {
        l.ledger.removeRange(0, l.ledger.length - lexLedgerCap);
      }
    }
    final p = j['paid'];
    if (p is Map) {
      for (final e in p.entries) {
        if (e.key is String && e.value is String) {
          l._paid[e.key as String] = e.value as String;
        }
      }
    }
    return l;
  }
}
