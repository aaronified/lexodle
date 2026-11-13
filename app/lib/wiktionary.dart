import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:html/dom.dart' show Element, Text;
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

/// A usage example of one sense, with its translation when Wiktionary gives one.
class Example {
  const Example(this.text, [this.translation = '']);
  final String text;
  final String translation;

  Map<String, dynamic> toJson() => {
    'text': text,
    if (translation.isNotEmpty) 'tr': translation,
  };

  static Example fromJson(Map<String, dynamic> j) =>
      Example(j['text'] as String? ?? '', j['tr'] as String? ?? '');
}

/// One numbered sense: its register labels ("informal", "transitive"), the
/// gloss and a few examples.
class Sense {
  Sense(this.text, {this.labels = const [], this.examples = const []});
  final String text;
  final List<String> labels;
  final List<Example> examples;

  Map<String, dynamic> toJson() => {
    'text': text,
    if (labels.isNotEmpty) 'labels': labels,
    if (examples.isNotEmpty) 'examples': [for (final e in examples) e.toJson()],
  };

  static Sense fromJson(Map<String, dynamic> j) => Sense(
    j['text'] as String? ?? '',
    labels: [for (final l in j['labels'] ?? []) l as String],
    examples: [
      for (final e in j['examples'] ?? [])
        Example.fromJson((e as Map).cast<String, dynamic>()),
    ],
  );
}

class PosBlock {
  PosBlock(this.pos, {this.gender = '', this.forms = ''});
  final String pos;

  /// Grammatical gender as Wiktionary abbreviates it ("m", "f", "n"), if any.
  final String gender;

  /// The rest of the headword line, e.g. "(plural maisons)".
  final String forms;
  final List<Sense> senses = [];

  List<String> get definitions => [for (final s in senses) s.text];

  Map<String, dynamic> toJson() => {
    'pos': pos,
    if (gender.isNotEmpty) 'gender': gender,
    if (forms.isNotEmpty) 'forms': forms,
    'senses': [for (final s in senses) s.toJson()],
  };

  static PosBlock fromJson(Map<String, dynamic> j) {
    final b = PosBlock(
      j['pos'] as String? ?? '',
      gender: j['gender'] as String? ?? '',
      forms: j['forms'] as String? ?? '',
    );
    for (final s in j['senses'] ?? []) {
      b.senses.add(Sense.fromJson((s as Map).cast<String, dynamic>()));
    }
    return b;
  }
}

class WordInfo {
  WordInfo({
    required this.url,
    this.ipa = const [],
    this.audio,
    this.blocks = const [],
    this.synonyms = const [],
    this.antonyms = const [],
    this.etymology = '',
  });
  final String url;
  final List<String> ipa;
  final String? audio;
  final List<PosBlock> blocks;
  final List<String> synonyms;
  final List<String> antonyms;

  /// The first paragraph of the etymology, shortened.
  final String etymology;

  bool get isEmpty => blocks.isEmpty && ipa.isEmpty;

  /// The entry as it is kept in a saved word: everything that is shown.
  Map<String, dynamic> toJson() => {
    'url': url,
    if (ipa.isNotEmpty) 'ipa': ipa,
    if (audio != null) 'audio': audio,
    'blocks': [for (final b in blocks) b.toJson()],
    if (synonyms.isNotEmpty) 'syn': synonyms,
    if (antonyms.isNotEmpty) 'ant': antonyms,
    if (etymology.isNotEmpty) 'etym': etymology,
  };

  static WordInfo fromJson(Map<String, dynamic> j) => WordInfo(
    url: j['url'] as String? ?? '',
    ipa: [for (final i in j['ipa'] ?? []) i as String],
    audio: j['audio'] as String?,
    blocks: [
      for (final b in j['blocks'] ?? [])
        PosBlock.fromJson((b as Map).cast<String, dynamic>()),
    ],
    synonyms: [for (final s in j['syn'] ?? []) s as String],
    antonyms: [for (final s in j['ant'] ?? []) s as String],
    etymology: j['etym'] as String? ?? '',
  );
}

const _posIds = {
  'Noun',
  'Proper_noun',
  'Verb',
  'Adjective',
  'Adverb',
  'Pronoun',
  'Preposition',
  'Postposition',
  'Conjunction',
  'Interjection',
  'Article',
  'Determiner',
  'Numeral',
  'Particle',
  'Participle',
  'Contraction',
  'Phrase',
  'Prefix',
  'Suffix',
  'Letter',
  'Symbol',
  'Abbreviation',
};

String _squash(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Parses one language section of an en.wiktionary page (the HTML returned by
/// `action=parse&section=N`). Pure, so it is tested against saved responses.
WordInfo parseSection(
  String markup,
  String url, {
  int maxBlocks = 3,
  int maxDefs = 4,
  int maxNyms = 8,
  int maxExamples = 2,
}) {
  final root = html.parseFragment(markup);
  final top = root.querySelector('.mw-parser-output') ?? root;

  final ipa = <String>[];
  for (final e in top.querySelectorAll('span.IPA')) {
    final t = _squash(e.text);
    if (t.isNotEmpty && !ipa.contains(t)) ipa.add(t);
    if (ipa.length >= 3) break;
  }

  String? audio;
  for (final s in top.querySelectorAll('audio source')) {
    final src = s.attributes['src'];
    if (src != null && s.attributes['type'] == 'audio/mpeg') {
      audio = src.startsWith('//') ? 'https:$src' : src;
      break;
    }
  }

  final blocks = <PosBlock>[];
  PosBlock? current;
  var inPos = false;
  var mode = '';
  final syn = <String>[], ant = <String>[];
  var etymology = '';

  void addNym(List<String> into, String t) {
    t = _squash(t);
    if (t.isEmpty || t.startsWith('Thesaurus:') || into.contains(t)) return;
    into.add(t);
  }

  for (final node in top.children) {
    final h = node.querySelector('h2,h3,h4,h5,h6');
    if (node.classes.contains('mw-heading') && h != null) {
      final id = (h.id).replaceFirst(RegExp(r'_\d+$'), '');
      if (_posIds.contains(id)) {
        // the headword line follows the heading, so it is read further down
        current = PosBlock(_squash(h.text).toLowerCase());
        if (blocks.length < maxBlocks) blocks.add(current);
        inPos = true;
        mode = 'pos';
      } else if (id == 'Etymology') {
        mode = 'ety';
      } else if (id == 'Synonyms') {
        mode = 'syn';
      } else if (id == 'Antonyms') {
        mode = 'ant';
      } else {
        mode = '';
      }
      continue;
    }
    if (mode == 'ety' && etymology.isEmpty && node.localName == 'p') {
      etymology = _shorten(_squash(_withoutNoise(node).text), 220);
    } else if (mode == 'pos' &&
        inPos &&
        node.localName == 'p' &&
        current != null &&
        node.querySelector('.headword-line, .headword') != null) {
      current = _withHeadline(current, node, blocks);
    } else if (mode == 'pos' &&
        inPos &&
        node.localName == 'ol' &&
        current != null &&
        current.senses.isEmpty) {
      for (final li in node.children.where((c) => c.localName == 'li')) {
        if (current.senses.length >= maxDefs) break;
        final examples = <Example>[];
        for (final ex in li.querySelectorAll('.h-usage-example')) {
          if (ex.parent?.localName == 'li' && ex.parent != li) continue;
          final text = ex.querySelector('.e-example');
          if (text == null) continue;
          final tr = ex.querySelector('.e-translation');
          examples.add(
            Example(_squash(text.text), tr == null ? '' : _squash(tr.text)),
          );
          if (examples.length >= maxExamples) break;
        }
        // the sense's own text: without nested lists, notes and its labels
        final copy = li.clone(true);
        for (final x in copy.querySelectorAll(
          'ul,ol,dl,div,style,sup,.defdate',
        )) {
          x.remove();
        }
        final labels = <String>[
          for (final l in copy.querySelectorAll('span.usage-label-sense'))
            ..._labelsOf(l),
        ];
        for (final x in copy.querySelectorAll('span.usage-label-sense')) {
          x.remove();
        }
        final t = _squash(copy.text).replaceFirst(RegExp(r'\s*:$'), '');
        if (t.isNotEmpty) {
          current.senses.add(Sense(t, labels: labels, examples: examples));
        }
      }
    } else if ((mode == 'syn' || mode == 'ant') &&
        (node.localName == 'ul' || node.localName == 'div')) {
      for (final li in node.querySelectorAll('li')) {
        addNym(
          mode == 'syn' ? syn : ant,
          li.querySelector('a')?.text ?? li.text,
        );
      }
    }
  }

  for (final (cls, into) in [('synonym', syn), ('antonym', ant)]) {
    for (final span in top.querySelectorAll('span.nyms.$cls')) {
      for (final a in span.querySelectorAll('a')) {
        addNym(into, a.text);
      }
    }
  }

  return WordInfo(
    url: url,
    ipa: ipa,
    audio: audio,
    blocks: [
      for (final b in blocks)
        if (b.senses.isNotEmpty) b,
    ],
    synonyms: syn.take(maxNyms).toList(),
    antonyms: ant.take(maxNyms).toList(),
    etymology: etymology,
  );
}

List<String> _labelsOf(dynamic span) => [
  for (final c in span.querySelectorAll('.ib-content'))
    if (_squash(c.text).isNotEmpty) _squash(c.text),
];

/// A copy of [node] without footnote marks and styles, for plain text.
dynamic _withoutNoise(dynamic node) {
  final copy = node.clone(true);
  for (final x in copy.querySelectorAll('sup,style')) {
    x.remove();
  }
  return copy;
}

String _shorten(String s, int max) {
  if (s.length <= max) return s;
  final cut = s.substring(0, max);
  final end = cut.lastIndexOf(RegExp(r'[.;,] '));
  return '${(end > max ~/ 2 ? cut.substring(0, end) : cut.trimRight())}…';
}

/// Reads gender and inflected forms from a headword line into [block].
PosBlock _withHeadline(PosBlock block, dynamic line, List<PosBlock> blocks) {
  final gender = _squash(
    [for (final g in line.querySelectorAll('.gender')) g.text].join(' '),
  );
  final copy = line.clone(true);
  for (final x in copy.querySelectorAll('.headword,.gender,sup,style')) {
    x.remove();
  }
  final forms = _squash(copy.text);
  final filled = PosBlock(block.pos, gender: gender, forms: forms);
  final i = blocks.indexOf(block);
  if (i >= 0) blocks[i] = filled;
  return filled;
}

/// One Wiktionary edition: where it lives, how its link reads, and how its
/// pages are parsed. To add an edition, add one entry to [editions] and one
/// parser here.
class Edition {
  const Edition(this.host, this.linkLabel, [this.parsePage]);

  /// The edition's host, e.g. "fr.wiktionary.org".
  final String host;

  /// The text of the link to the entry.
  final String linkLabel;

  /// Parses a whole page of this edition (the HTML of `action=parse` with
  /// `prop=text`) into the entry of its language, or null when the page has
  /// none. Null means the English edition, whose pages are read by section
  /// (see [parseSection]).
  final WordInfo? Function(String markup, String url)? parsePage;

  String get api => 'https://$host/w/api.php';
  String get wikiBase => 'https://$host/wiki/';
}

const _english = Edition('en.wiktionary.org', 'wiktionary ↗');

/// The editions by language code: a word is looked up in the Wiktionary of its
/// own language. A language that is not here uses the English edition.
const editions = <String, Edition>{
  'fr': Edition('fr.wiktionary.org', 'wiktionnaire ↗', parseFrench),
};

Edition editionOf(String lang) => editions[lang] ?? _english;

/// How the link of an entry reads, from the edition its [url] points to.
String linkLabelFor(String url) {
  for (final e in editions.values) {
    if (url.startsWith(e.wikiBase)) return e.linkLabel;
  }
  return _english.linkLabel;
}

const _frGender = {'masculin': 'm', 'féminin': 'f', 'neutre': 'n'};

/// Parses a fr.wiktionary page: the section of the French language (heading
/// `fr`), with its pronunciation, parts of speech, senses, etymology,
/// synonyms and antonyms. Null when the page has no French section.
WordInfo? parseFrench(
  String markup,
  String url, {
  int maxBlocks = 3,
  int maxDefs = 4,
  int maxNyms = 8,
  int maxExamples = 2,
}) {
  final root = html.parseFragment(markup);
  final top = root.querySelector('.mw-parser-output') ?? root;

  final ipa = <String>[];
  String? audio;
  final blocks = <_FrBlock>[];
  final syn = <String>[], ant = <String>[];
  var etymology = '';
  var inFrench = false, found = false;
  var mode = '';
  _FrBlock? current;

  void addNym(List<String> into, String t) {
    t = _squash(t);
    if (t.isEmpty || into.contains(t)) return;
    into.add(t);
  }

  for (final node in top.children) {
    final h = node.querySelector('h2,h3,h4,h5,h6');
    if (node.classes.contains('mw-heading') && h != null) {
      if (h.localName == 'h2') {
        final isFr = h.querySelector('span.sectionlangue#fr') != null;
        if (inFrench && !isFr) break;
        inFrench = isFr;
        found = found || isFr;
        mode = '';
        continue;
      }
      if (!inFrench) continue;
      final id = h.id.replaceFirst(RegExp(r'_\d+$'), '');
      final def = h.querySelector('span.titredef');
      if (def != null) {
        current = _FrBlock(
          _squash(def.text).toLowerCase().replaceFirst(RegExp(r'\s+\d+$'), ''),
        );
        if (blocks.length < maxBlocks) blocks.add(current);
        mode = 'pos';
      } else if (h.querySelector('span.titreetym') != null) {
        mode = 'ety';
      } else if (id == 'Synonymes') {
        mode = 'syn';
      } else if (id == 'Antonymes') {
        mode = 'ant';
      } else {
        mode = '';
      }
      continue;
    }
    if (!inFrench) continue;

    // pronunciations and recordings can sit in any part of the section
    for (final e in node.querySelectorAll('span.API')) {
      if (e.parent?.classes.contains('audio-ipa') ?? false) continue;
      final t = _squash(e.text);
      // \…\ is the pronunciation; […] are variants and liaisons
      if (t.startsWith('\\') && !ipa.contains(t) && ipa.length < 3) ipa.add(t);
    }
    if (audio == null) {
      for (final a in node.querySelectorAll('audio source')) {
        final src = a.attributes['src'];
        if (src != null && a.attributes['type'] == 'audio/mpeg') {
          audio = src.startsWith('//') ? 'https:$src' : src;
          break;
        }
      }
    }

    if (mode == 'ety' && etymology.isEmpty && node.localName == 'dl') {
      final dd = node.querySelector('dd');
      if (dd != null) {
        final copy = dd.clone(true);
        for (final x in copy.querySelectorAll(
          'sup,style,.siècle,.date,#refnec,span[style*="vertical-align:super"]',
        )) {
          x.remove();
        }
        // "(nom commun 1)" pointers to the part of speech the note is for
        for (final x in copy.querySelectorAll('i')) {
          if (x.querySelector('a[href^="#fr-"]') != null) x.remove();
        }
        final t = _squash(copy.text);
        if (!t.toLowerCase().startsWith('étymologie manquante') &&
            !t.toLowerCase().startsWith('étymologie à ajouter')) {
          etymology = _shorten(t, 220);
        }
      }
    } else if (mode == 'pos' && current != null) {
      final c = current;
      if (node.localName == 'p' &&
          !c.headed &&
          (node.querySelector('.ligne-de-forme, span.API') != null)) {
        c.headed = true;
        final g = _squash(
          [for (final x in node.querySelectorAll('.ligne-de-forme')) x.text]
              .join(' '),
        ).toLowerCase();
        c.gender = _frGender[g] ?? g;
        // a verb's headword line gives its group ("1er groupe"); the rest of
        // it (regions, "ou") is not kept
        final group = RegExp(r'\d+\S*\s+groupe').firstMatch(_squash(node.text));
        if (group != null) c.forms = group.group(0)!;
      } else if (node.localName == 'table' && c.forms.isEmpty) {
        // the inflection table: "singulier | pluriel" over the forms
        final heads = [
          for (final x in node.querySelectorAll('th')) _squash(x.text),
        ];
        final cells = [
          for (final x in node.querySelectorAll('td'))
            if (x.attributes['colspan'] == null) _squash(x.text),
        ];
        final i = heads.indexOf('Pluriel');
        if (i >= 0 && i < cells.length && cells[i].isNotEmpty) {
          c.forms = 'pluriel ${cells[i]}';
        }
      } else if (node.localName == 'ol' && c.senses.isEmpty) {
        for (final li in node.children.where((x) => x.localName == 'li')) {
          if (c.senses.length >= maxDefs) break;
          final examples = <Example>[];
          for (final ex in li.querySelectorAll('span.example')) {
            final q = ex.querySelector('q') ?? ex;
            final t = _squash(q.text);
            if (t.isNotEmpty) examples.add(Example(t));
            if (examples.length >= maxExamples) break;
          }
          final copy = li.clone(true);
          for (final x in copy.querySelectorAll('ul,ol,dl,div,style,sup')) {
            x.remove();
          }
          // the labels lead the sense: "(informal)" in italics, or the
          // emploi and registre spans
          final labels = <String>[];
          for (final n in copy.nodes.toList()) {
            if (n is Text) {
              if (n.text.trim().isEmpty) continue;
              break;
            }
            if (n is! Element) break;
            final isLabel =
                n.classes.contains('emploi') ||
                n.classes.contains('registre') ||
                (n.localName == 'i' &&
                    RegExp(r'^\(.+\)$').hasMatch(_squash(n.text)));
            if (!isLabel) break;
            final l = _squash(n.text).replaceAll(RegExp(r'^\(|\)$'), '');
            if (l.isNotEmpty) labels.add(l.toLowerCase());
            n.remove();
          }
          final t = _squash(copy.text);
          if (t.isNotEmpty) {
            c.senses.add(Sense(t, labels: labels, examples: examples));
          }
        }
      }
    } else if ((mode == 'syn' || mode == 'ant') &&
        (node.localName == 'ul' || node.localName == 'div')) {
      for (final li in node.querySelectorAll('li')) {
        addNym(
          mode == 'syn' ? syn : ant,
          li.querySelector('a')?.text ?? li.text,
        );
      }
    }
  }

  if (!found) return null;
  return WordInfo(
    url: url,
    ipa: ipa,
    audio: audio,
    blocks: [
      for (final b in blocks)
        if (b.senses.isNotEmpty)
          PosBlock(b.pos, gender: b.gender, forms: b.forms)
            ..senses.addAll(b.senses),
    ],
    synonyms: syn.take(maxNyms).toList(),
    antonyms: ant.take(maxNyms).toList(),
    etymology: etymology,
  );
}

/// A part of speech of a French entry while it is being read.
class _FrBlock {
  _FrBlock(this.pos);
  final String pos;
  String gender = '', forms = '';
  bool headed = false;
  final senses = <Sense>[];
}

/// Candidate page titles: Wiktionary titles are case-sensitive and German
/// nouns, for one, are capitalised.
List<String> titleCandidates(String word, String lang) {
  if (word.isEmpty) return [word];
  var first = word[0];
  first = switch ((lang, first)) {
    ('tr', 'i') => 'İ',
    ('tr', 'ı') => 'I',
    _ => first.toUpperCase(),
  };
  final cap = first + word.substring(1);
  if (cap == word) return [word];
  // German nouns live on the capitalised page; the lowercase page is usually
  // just a verb form, so it goes second.
  return lang == 'de' ? [cap, word] : [word, cap];
}

/// Combines lookups of the same word under different titles.
WordInfo mergeInfos(
  List<WordInfo> infos, {
  int maxBlocks = 3,
  int maxNyms = 8,
}) {
  List<String> union(Iterable<List<String>> lists) =>
      {for (final l in lists) ...l}.take(maxNyms).toList();
  return WordInfo(
    url: infos.first.url,
    ipa: infos
        .map((i) => i.ipa)
        .firstWhere((l) => l.isNotEmpty, orElse: () => const []),
    audio: infos.map((i) => i.audio).whereType<String>().firstOrNull,
    blocks: [for (final i in infos) ...i.blocks].take(maxBlocks).toList(),
    etymology: infos
        .map((i) => i.etymology)
        .firstWhere((e) => e.isNotEmpty, orElse: () => ''),
    synonyms: union(infos.map((i) => i.synonyms)),
    antonyms: union(infos.map((i) => i.antonyms)),
  );
}

/// Whether the game screens look up their answers while the game is played.
/// The tests turn it off (see test/flutter_test_config.dart) so no request is
/// left pending when one ends; the one test of the behaviour turns it on.
bool prefetchDefinitions = true;

class Wiktionary {
  Wiktionary({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  /// The one the app asks, so every screen shares its lookups and its queue.
  /// Tests put one with a fake client here.
  static Wiktionary shared = Wiktionary();

  /// Lookups already made or under way, by language and word. Keeping the
  /// future, not the result, means a lookup started while the game is played
  /// is the very one the end screen waits on, instead of a second request.
  static final _cache = <String, Future<WordInfo?>>{};

  /// Wikimedia asks for one request at a time, so every lookup, whoever asked,
  /// waits for the one before it.
  static Future<void> _tail = Future.value();

  /// Forgets every lookup and the queue, for tests that each need a clean
  /// start (a test that ends with a lookup unfinished would hold up the next).
  @visibleForTesting
  static void reset() {
    _cache.clear();
    _tail = Future.value();
  }

  Future<Map<String, dynamic>> _get(Edition ed, Map<String, String> q) async {
    final uri = Uri.parse(ed.api).replace(
      queryParameters: {
        ...q,
        'format': 'json',
        'formatversion': '2',
        'origin': '*',
      },
    );
    final r = await _client.get(uri).timeout(const Duration(seconds: 12));
    return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
  }

  /// Looks [word] up in the [section] language heading (English name, e.g.
  /// "French"). Returns null when Wiktionary has no entry in that language;
  /// throws on network failure (which is not remembered, so asking again
  /// tries again). Asking twice for the same word shares one lookup.
  Future<WordInfo?> lookup(String word, String lang, String section) {
    final key = '${editionOf(lang).host}:$lang:$word';
    final hit = _cache[key];
    if (hit != null) return hit;
    final run = _tail.then((_) => _fetch(word, lang, section));
    _tail = run.then<void>((_) {}, onError: (_) {});
    // a failure must not stay in the cache; this listener also means nobody
    // has to await a lookup started ahead of time for its error to be handled
    run.then<void>(
      (_) {},
      onError: (_) {
        _cache.remove(key);
      },
    );
    return _cache[key] = run;
  }

  /// Starts a lookup now for a word that may be wanted later, such as the
  /// answer of the game being played. Never throws.
  void prefetch(String word, String lang, String section) {
    lookup(word, lang, section).then<void>((_) {}, onError: (_) {});
  }

  Future<WordInfo?> _fetch(String word, String lang, String section) async {
    final ed = editionOf(lang);
    final found = <WordInfo>[];
    for (final title in titleCandidates(word, lang)) {
      final page = ed.parsePage;
      if (page != null) {
        // an edition read by whole page: one request, the parser picks the
        // section of the language
        final t = await _get(ed, {
          'action': 'parse',
          'page': title,
          'prop': 'text',
          'disablelimitreport': '1',
          'disableeditsection': '1',
        });
        if (t['error'] != null) continue; // missing page
        final info = page(
          t['parse']['text'] as String,
          '${ed.wikiBase}${Uri.encodeComponent(title.replaceAll(' ', '_'))}#$lang',
        );
        if (info != null) found.add(info);
        continue;
      }
      final s = await _get(ed, {
        'action': 'parse',
        'page': title,
        'prop': 'sections',
      });
      if (s['error'] != null) continue; // missing page
      final secs = (s['parse']['sections'] as List)
          .cast<Map<String, dynamic>>();
      final idx = secs
          .where((x) => x['line'] == section && x['toclevel'] == 1)
          .map((x) => x['index'] as String)
          .firstOrNull;
      if (idx == null) continue;
      final t = await _get(ed, {
        'action': 'parse',
        'page': title,
        'section': idx,
        'prop': 'text',
        'disablelimitreport': '1',
        'disableeditsection': '1',
      });
      final url =
          '${ed.wikiBase}'
          '${Uri.encodeComponent(title.replaceAll(' ', '_'))}#'
          '${Uri.encodeComponent(section.replaceAll(' ', '_'))}';
      found.add(parseSection(t['parse']['text'] as String, url));
    }
    return found.isEmpty ? null : mergeInfos(found);
  }
}
