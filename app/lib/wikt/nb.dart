import 'package:html/dom.dart' show Element;
import 'package:html/parser.dart' as html;

import '../wiktionary.dart';
import 'north_util.dart';

const _nbPos = {
  'substantiv',
  'verb',
  'adjektiv',
  'adverb',
  'pronomen',
  'determinativ',
  'preposisjon',
  'konjunksjon',
  'subjunksjon',
  'interjeksjon',
  'tallord',
  'artikkel',
  'partikkel',
  'prefiks',
  'suffiks',
  'egennavn',
  'forkortelse',
  'uttrykk',
  'symbol',
};

/// Parses a no.wiktionary page (the Wiktionary of Norwegian, `no`): the
/// section "Norsk" (`h2`), with its parts of speech (`h3`), senses (`ol`),
/// examples, and the `h4` sections for origin, pronunciation, inflection,
/// synonyms and antonyms. Null when the page has no Norwegian section, or when
/// every part of speech in it is marked nynorsk only.
///
/// One section covers Bokmål, Riksmål and Nynorsk: the headword line carries
/// small-caps labels ("bokmål/nynorsk"), and the inflection table has one row
/// per variety with its label in the last cell.
WordInfo? parseNorwegian(
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
  final blocks = <_Block>[];
  final syn = <String>[], ant = <String>[];
  var etymology = '';
  var inNorwegian = false, found = false;
  var mode = '';
  _Block? current;

  void addNym(List<String> into, String t) {
    t = squash(t);
    if (t.isEmpty || into.contains(t)) return;
    into.add(t);
  }

  for (final node in top.children) {
    final h = node.querySelector('h2,h3,h4,h5,h6');
    if (node.classes.contains('mw-heading') && h != null) {
      final title = squash(h.text).toLowerCase();
      if (h.localName == 'h2') {
        final isNo = h.id == 'Norsk';
        if (inNorwegian && !isNo) break;
        inNorwegian = isNo;
        found = found || isNo;
        mode = '';
      } else if (!inNorwegian) {
        continue;
      } else if (h.localName == 'h3') {
        if (_nbPos.contains(title)) {
          current = _Block(title);
          if (blocks.length < maxBlocks) blocks.add(current);
          mode = 'pos';
        } else {
          mode = '';
        }
      } else {
        // "Ordsoge" is the nynorsk spelling of "Etymologi"
        mode = switch (title) {
          'etymologi' || 'ordsoge' || 'opphav' => 'ety',
          'uttale' => 'pron',
          'grammatikk' => 'gram',
          'synonymer' => 'syn',
          'antonymer' => 'ant',
          _ => '',
        };
      }
      continue;
    }
    if (!inNorwegian || current == null) continue;
    final c = current;

    switch (mode) {
      case 'pos':
        if (node.localName == 'p' && !c.headed) {
          c.headed = true;
          _headline(node, c);
        } else if (node.localName == 'ol' && c.senses.isEmpty) {
          _senses(node, c.senses, maxDefs, maxExamples);
        }
      case 'ety' when etymology.isEmpty:
        // a paragraph, or a definition list
        final t = tidy(
          squash(
            without(
              node.localName == 'dl'
                  ? (node.querySelector('dd') ?? node)
                  : node,
              'sup,style',
            ).text,
          ),
        );
        if ((node.localName == 'p' || node.localName == 'dl') && t.isNotEmpty) {
          etymology = shorten(t, 220);
        }
      case 'pron':
        if (audio == null) {
          for (final s in node.querySelectorAll('audio source')) {
            if (s.attributes['type'] == 'audio/mpeg') {
              audio = absUrl(s.attributes['src'] ?? '');
              break;
            }
          }
        }
        for (final e in node.querySelectorAll('span.IPA')) {
          final t = squash(e.text);
          if (t.isNotEmpty && ipa.length < 3 && !ipa.contains(t)) ipa.add(t);
        }
        final m = RegExp(r'IPA:\s*(\S+)').firstMatch(squash(node.text));
        if (m != null && ipa.length < 3 && !ipa.contains(m.group(1))) {
          ipa.add(m.group(1)!);
        }
      case 'gram' when c.forms.isEmpty && node.localName == 'table':
        c.forms = _forms(node);
      case 'syn' || 'ant' when node.localName == 'ul':
        for (final li in node.children.where((x) => x.localName == 'li')) {
          for (final a in li.querySelectorAll('a')) {
            // links inside italics are notes; "pla (nynorsk)" is not bokmål
            if (a.parent?.localName == 'i') continue;
            final next = a.nextElementSibling;
            if (next != null && squash(next.text) == 'nynorsk') continue;
            addNym(mode == 'syn' ? syn : ant, a.text);
          }
        }
    }
  }

  if (!found) return null;
  final shown = [
    for (final b in blocks)
      if (b.senses.isNotEmpty && !b.nynorskOnly)
        PosBlock(b.pos, gender: b.gender, forms: b.forms)
          ..senses.addAll(b.senses),
  ];
  if (shown.isEmpty && blocks.isNotEmpty) return null;
  return WordInfo(
    url: url,
    ipa: ipa,
    audio: audio,
    blocks: shown,
    synonyms: syn.take(maxNyms).toList(),
    antonyms: ant.take(maxNyms).toList(),
    etymology: etymology,
  );
}

class _Block {
  _Block(this.pos);
  final String pos;
  String gender = '', forms = '';
  bool headed = false, nynorskOnly = false;
  final senses = <Sense>[];
}

/// "skole m (bokmål/nynorsk), c (riksmål)": the first gender, and whether the
/// labels leave Bokmål and Riksmål out.
void _headline(Element p, _Block b) {
  final g = squash(p.querySelector('i')?.text ?? '');
  b.gender = const {'m', 'f', 'n', 'c'}.contains(g) ? g : '';
  final labels = squash(
    [
      for (final s in p.querySelectorAll('span'))
        if ((s.attributes['style'] ?? '').contains('small-caps')) s.text,
    ].join(' '),
  ).toLowerCase();
  b.nynorskOnly =
      labels.isNotEmpty &&
      !labels.contains('bokmål') &&
      !labels.contains('riksmål');
}

void _senses(Element ol, List<Sense> into, int maxDefs, int maxExamples) {
  for (final li in ol.children.where((x) => x.localName == 'li')) {
    if (into.length >= maxDefs) return;
    final examples = <Example>[];
    for (final dl in li.children.where((x) => x.localName == 'dl')) {
      for (final dd in dl.children.where((x) => x.localName == 'dd')) {
        final t = squash(without(dd, 'sup,style').text);
        if (t.isNotEmpty && examples.length < maxExamples) {
          examples.add(Example(t));
        }
      }
    }
    final copy = without(li, 'ol,ul,dl,sup,style');
    var t = squash(copy.text);
    final labels = <String>[];
    while (true) {
      final m = RegExp(r'^\(([^)]*)\)\s*').firstMatch(t);
      if (m == null) break;
      if (m.group(1)!.isNotEmpty) labels.add(m.group(1)!.toLowerCase());
      t = t.substring(m.end);
    }
    if (t.isNotEmpty) {
      into.add(Sense(t, labels: labels, examples: examples));
    }
  }
}

/// One short line from an inflection table, read from the row of Bokmål (the
/// first row whose label names Bokmål or Riksmål, or the first with none):
/// a noun's plural, a verb's present, preterite and perfect, an adjective's
/// comparison.
String _forms(Element table) {
  final heads = [for (final x in table.querySelectorAll('th')) squash(x.text)];
  if (heads.contains('Hankjønn')) return ''; // agreement, not comparison

  List<String>? row;
  for (final r in table.querySelectorAll('tr')) {
    final tds = [for (final x in r.querySelectorAll('td')) squash(x.text)];
    if (tds.length < 3) continue;
    final marker = RegExp(r'^\((.*)\)$').firstMatch(tds.last)?.group(1) ?? '';
    final cells = marker.isEmpty ? tds : tds.sublist(0, tds.length - 1);
    if (marker.isEmpty ||
        marker.contains('bokmål') ||
        marker.contains('riksmål')) {
      row = cells;
      break;
    }
  }
  if (row == null) return '';

  if (heads.contains('Infinitiv') && row.length >= 4) {
    return 'presens ${row[1]}, preteritum ${row[2]}, perfektum ${row[3]}';
  }
  if (heads.contains('Komparativ') && row.length >= 3) {
    return 'komparativ ${row[1]}, superlativ ${row[2]}';
  }
  if (heads.contains('Flertall') && row.length >= 4) {
    return 'flertall ${row[2]}';
  }
  return '';
}
