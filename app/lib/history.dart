import 'logic.dart';
import 'modes.dart';

/// The version of the numbers cached on a guess row (skill, luck, daring, risk
/// and the pool sizes). Bump it whenever the maths in logic.dart changes: every
/// game saved under an older one is then stale and is worked out again from its
/// guesses, which are the facts (see [History.stale]).
const metricsVersion = 1;

/// The most games kept. The playstyle looks at the last 100 of them; the rest is
/// room for the player to look back, and keeps the saved file small.
const historyCap = 300;

/// One finished game: a row of the games table. Everything but [version] is a
/// fact of the game; the numbers that are worked out from it live on its
/// [GuessRow]s.
class GameRow {
  const GameRow({
    required this.id,
    required this.at,
    required this.lang,
    required this.mode,
    required this.length,
    required this.tries,
    required this.pool,
    required this.answers,
    required this.won,
    this.daily = '',
    this.version = metricsVersion,
  });

  /// Its key in the guesses table; counts up, and is never reused.
  final int id;

  /// When it ended, in milliseconds since the epoch (UTC).
  final int at;
  final String lang;
  final GameMode mode;
  final int length;
  final int tries;

  /// The answer-pool size it was played at.
  final int pool;

  /// The word or words to find: one in classic, four in quartet and relay race.
  final List<String> answers;
  final bool won;

  /// The date of the daily it was, or '' for an ordinary game.
  final String daily;

  /// The [metricsVersion] its guess rows were worked out under.
  final int version;

  bool get isDaily => daily.isNotEmpty;

  /// Only a classic game has per-guess numbers that mean the same thing on every
  /// row, so only those count towards a playstyle.
  bool get isClassic => mode == GameMode.classic;

  GameRow withVersion(int v) => GameRow(
    id: id,
    at: at,
    lang: lang,
    mode: mode,
    length: length,
    tries: tries,
    pool: pool,
    answers: answers,
    won: won,
    daily: daily,
    version: v,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'at': at,
    'lang': lang,
    'mode': mode.index,
    'length': length,
    'tries': tries,
    'pool': pool,
    'answers': answers,
    'won': won,
    if (daily.isNotEmpty) 'daily': daily,
    'v': version,
  };

  static GameRow fromJson(Map<String, dynamic> j) {
    final mode = _int(j['mode'], 0, GameMode.values.length - 1);
    final answers = j['answers'];
    if (answers is! List || answers.isEmpty || answers.length > 4) {
      throw const FormatException('answers');
    }
    final length = _int(j['length'], 1, 12);
    final daily = j['daily'] ?? '';
    if (daily is! String || (daily.isNotEmpty && daily.length != 10)) {
      throw const FormatException('daily');
    }
    final lang = j['lang'];
    if (lang is! String || lang.isEmpty || lang.length > 12) {
      throw const FormatException('lang');
    }
    final won = j['won'];
    if (won is! bool) throw const FormatException('won');
    return GameRow(
      id: _int(j['id'], 0, _big),
      // milliseconds: 1e13 is the year 2286
      at: _int(j['at'], 0, 10000000000000),
      lang: lang,
      mode: GameMode.values[mode],
      length: length,
      tries: _int(j['tries'], 1, 40),
      pool: _int(j['pool'], 0, 100000),
      answers: [
        for (final a in answers)
          a is String && a.length == length
              ? a
              : throw const FormatException('answer'),
      ],
      won: won,
      daily: daily,
      version: _int(j['v'] ?? 0, 0, 1000),
    );
  }
}

/// One guess of one game: a row of the guesses table. [word] and [n] are the
/// facts; the rest is cached from the maths of the [metricsVersion] the game
/// was saved under, so it can be thrown away and worked out again.
class GuessRow {
  const GuessRow({
    required this.game,
    required this.n,
    required this.word,
    this.skill = 0,
    this.luck = 0,
    this.daring,
    this.risk = 0,
    this.before = 0,
    this.after = 0,
  });

  /// The [GameRow.id] it belongs to, and its place in the game from 0.
  final int game;
  final int n;
  final String word;

  /// Skill (0 to 100), luck (-100 to 100), daring (0 to 100, null when not
  /// known or no choice was open) and risk (bits) of the guess. For a quartet
  /// or relay race, skill and luck are the step's weighted mean over its boards
  /// and there is no daring.
  final double skill;
  final double luck;
  final double? daring;
  final double risk;

  /// Words possible before and after it (0 for a quartet or relay race).
  final int before;
  final int after;

  GuessRow withGame(int id) => GuessRow(
    game: id,
    n: n,
    word: word,
    skill: skill,
    luck: luck,
    daring: daring,
    risk: risk,
    before: before,
    after: after,
  );

  Map<String, Object> toJson() => {
    'g': game,
    'n': n,
    'w': word,
    's': _r(skill),
    'l': _r(luck),
    if (daring != null) 'd': _r(daring!),
    'r': _r(risk),
    'b': before,
    'a': after,
  };

  static GuessRow fromJson(Map<String, dynamic> j) {
    final word = j['w'];
    if (word is! String || word.isEmpty || word.length > 12) {
      throw const FormatException('word');
    }
    final d = j['d'];
    return GuessRow(
      game: _int(j['g'], 0, _big),
      n: _int(j['n'], 0, 40),
      word: word,
      skill: _num(j['s'], 0, 100),
      luck: _num(j['l'], -100, 100),
      daring: d == null ? null : _num(d, 0, 100),
      risk: _num(j['r'], 0, 100),
      before: _int(j['b'], 0, 1000000),
      after: _int(j['a'], 0, 1000000),
    );
  }
}

/// The row for guess number [n] of a game, from how it scored. Its game is
/// filled in when the game is saved.
GuessRow guessRowOf(int n, GuessMetrics m) => GuessRow(
  game: 0,
  n: n,
  word: m.guess,
  skill: m.skill,
  luck: m.luck,
  daring: m.daring,
  risk: m.risk,
  before: m.before,
  after: m.after,
);

const _big = 1000000000;

/// Three decimals are plenty for a cached score and keep the file small.
double _r(double v) => (v * 1000).round() / 1000;

int _int(Object? v, int lo, int hi) {
  if (v is! int || v < lo || v > hi) throw FormatException('number $v');
  return v;
}

double _num(Object? v, double lo, double hi) {
  if (v is! num || v.isNaN || v < lo || v > hi) {
    throw FormatException('number $v');
  }
  return v.toDouble();
}

/// The play history, as two tables: the games, and a row for every guess of
/// every game. It keeps what was played, not just how it scored, so skill, luck
/// and daring can be worked out again if the maths changes.
class History {
  History({List<GameRow>? games, List<GuessRow>? guesses})
    : games = games ?? [],
      _guesses = guesses ?? [] {
    _index();
  }

  /// Oldest first.
  final List<GameRow> games;
  final List<GuessRow> _guesses;
  final _byGame = <int, List<GuessRow>>{};
  var _next = 0;

  /// Every guess row, by game then place.
  List<GuessRow> get guesses => List.unmodifiable(_guesses);

  void _index() {
    _byGame.clear();
    for (final g in _guesses) {
      (_byGame[g.game] ??= []).add(g);
    }
    for (final rows in _byGame.values) {
      rows.sort((a, b) => a.n.compareTo(b.n));
    }
    _next = games.fold<int>(0, (m, g) => g.id >= m ? g.id + 1 : m);
  }

  /// The guesses of game [id], in order.
  List<GuessRow> guessesOf(int id) => _byGame[id] ?? const [];

  GameRow? byId(int id) {
    for (final g in games) {
      if (g.id == id) return g;
    }
    return null;
  }

  /// Saves a finished game with its guesses (their `game` is filled in) and
  /// returns its row. The oldest games go once there are more than [historyCap].
  GameRow add({
    required int at,
    required String lang,
    required GameMode mode,
    required int length,
    required int tries,
    required int pool,
    required List<String> answers,
    required bool won,
    required List<GuessRow> guesses,
    String daily = '',
  }) {
    final row = GameRow(
      id: _next++,
      at: at,
      lang: lang,
      mode: mode,
      length: length,
      tries: tries,
      pool: pool,
      answers: List.of(answers),
      won: won,
      daily: daily,
    );
    games.add(row);
    final mine = [for (final g in guesses) g.withGame(row.id)];
    _guesses.addAll(mine);
    _byGame[row.id] = mine;
    while (games.length > historyCap) {
      final old = games.removeAt(0);
      _byGame.remove(old.id);
      _guesses.removeWhere((g) => g.game == old.id);
    }
    return row;
  }

  /// The last [n] classic games, oldest first: the ones a playstyle is read
  /// from.
  List<GameRow> recentClassic([int n = 100]) {
    final classic = [
      for (final g in games)
        if (g.isClassic) g,
    ];
    return classic.length <= n ? classic : classic.sublist(classic.length - n);
  }

  /// Games whose cached numbers are from an older [metricsVersion].
  List<GameRow> stale() => [
    for (final g in games)
      if (g.version != metricsVersion) g,
  ];

  /// Replaces the numbers of game [id] with [rows] (worked out afresh), under
  /// the current version.
  void replaceGuesses(int id, List<GuessRow> rows) {
    final i = games.indexWhere((g) => g.id == id);
    if (i < 0) return;
    _guesses.removeWhere((g) => g.game == id);
    final mine = [for (final g in rows) g.withGame(id)];
    _guesses.addAll(mine);
    _byGame[id] = mine;
    games[i] = games[i].withVersion(metricsVersion);
  }

  Map<String, Object> toJson() => {
    'games': [for (final g in games) g.toJson()],
    'guesses': [for (final g in _guesses) g.toJson()],
  };

  /// Reads what [toJson] wrote, strictly: a [FormatException] for anything that
  /// is not a history of this app, since a backup is taken whole or not at all.
  /// A guess row whose game is missing is dropped, and a game with no guesses
  /// is refused.
  static History fromJson(Object? raw) {
    if (raw is! Map) throw const FormatException('history');
    final gs = raw['games'], rs = raw['guesses'];
    if (gs is! List || rs is! List) throw const FormatException('history');
    if (gs.length > historyCap || rs.length > historyCap * 40) {
      throw const FormatException('history is too big');
    }
    final games = <GameRow>[];
    final ids = <int>{};
    for (final g in gs) {
      if (g is! Map) throw const FormatException('game');
      final row = GameRow.fromJson(g.cast<String, dynamic>());
      if (!ids.add(row.id)) throw const FormatException('duplicate game');
      games.add(row);
    }
    final guesses = <GuessRow>[];
    for (final r in rs) {
      if (r is! Map) throw const FormatException('guess');
      final row = GuessRow.fromJson(r.cast<String, dynamic>());
      if (ids.contains(row.game)) guesses.add(row);
    }
    final h = History(games: games, guesses: guesses);
    for (final g in games) {
      if (h.guessesOf(g.id).isEmpty) throw const FormatException('no guesses');
    }
    return h;
  }
}
