import 'dart:convert';

import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

class PosBlock {
  PosBlock(this.pos, this.definitions);
  final String pos;
  final List<String> definitions;
}

class WordInfo {
  WordInfo({
    required this.url,
    this.ipa = const [],
    this.audio,
    this.blocks = const [],
    this.synonyms = const [],
    this.antonyms = const [],
  });
  final String url;
  final List<String> ipa;
  final String? audio;
  final List<PosBlock> blocks;
  final List<String> synonyms;
  final List<String> antonyms;

  bool get isEmpty => blocks.isEmpty && ipa.isEmpty;
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
        current = PosBlock(_squash(h.text).toLowerCase(), []);
        if (blocks.length < maxBlocks) blocks.add(current);
        inPos = true;
        mode = 'pos';
      } else if (id == 'Synonyms') {
        mode = 'syn';
      } else if (id == 'Antonyms') {
        mode = 'ant';
      } else {
        mode = '';
      }
      continue;
    }
    if (mode == 'pos' &&
        inPos &&
        node.localName == 'ol' &&
        current != null &&
        current.definitions.isEmpty) {
      for (final li in node.children.where((c) => c.localName == 'li')) {
        final copy = li.clone(true);
        for (final x in copy.querySelectorAll('ul,ol,dl,div,style,sup')) {
          x.remove();
        }
        final t = _squash(copy.text).replaceFirst(RegExp(r'\s*:$'), '');
        if (t.isNotEmpty && current.definitions.length < maxDefs) {
          current.definitions.add(t);
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
        if (b.definitions.isNotEmpty) b,
    ],
    synonyms: syn.take(maxNyms).toList(),
    antonyms: ant.take(maxNyms).toList(),
  );
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
    synonyms: union(infos.map((i) => i.synonyms)),
    antonyms: union(infos.map((i) => i.antonyms)),
  );
}

class Wiktionary {
  Wiktionary({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  static final _cache = <String, WordInfo?>{};

  static const _api = 'https://en.wiktionary.org/w/api.php';

  Future<Map<String, dynamic>> _get(Map<String, String> q) async {
    final uri = Uri.parse(_api).replace(
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
  /// throws on network failure.
  Future<WordInfo?> lookup(String word, String lang, String section) async {
    final key = '$lang:$word';
    if (_cache.containsKey(key)) return _cache[key];
    final found = <WordInfo>[];
    for (final title in titleCandidates(word, lang)) {
      final s = await _get({
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
      final t = await _get({
        'action': 'parse',
        'page': title,
        'section': idx,
        'prop': 'text',
        'disablelimitreport': '1',
        'disableeditsection': '1',
      });
      final url =
          'https://en.wiktionary.org/wiki/'
          '${Uri.encodeComponent(title.replaceAll(' ', '_'))}#'
          '${Uri.encodeComponent(section.replaceAll(' ', '_'))}';
      found.add(parseSection(t['parse']['text'] as String, url));
    }
    return _cache[key] = found.isEmpty ? null : mergeInfos(found);
  }
}
