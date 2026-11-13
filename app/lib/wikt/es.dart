import 'package:html/dom.dart' show Element;
import 'package:html/parser.dart' as html;

import '../wiktionary.dart';
import 'common.dart';

const _esGender = {'masculino': 'm', 'femenino': 'f', 'neutro': 'n'};

const _esPos = [
  'sustantivo',
  'verbo',
  'adjetivo',
  'adverbio',
  'pronombre',
  'preposición',
  'conjunción',
  'interjección',
  'artículo',
  'numeral',
  'contracción',
  'locución',
  'forma',
  'prefijo',
  'sufijo',
  'letra',
  'símbolo',
  'abreviatura',
  'interrogativo',
  'onomatopeya',
  'participio',
  'determinante',
  'posposición',
];

/// Parses an es.wiktionary page: the Spanish section (h2 with the `es`
/// language mark), with its pronunciation, recording, parts of speech (h3 or
/// h4 headings), numbered senses (`dl` with a `dt` number), etymology,
/// synonyms and antonyms. Null when the page has no Spanish section.
WordInfo? parseSpanish(
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
  final blocks = <PosBlock>[];
  final syn = <String>[], ant = <String>[];
  var etymology = '';
  var inEs = false, found = false;
  var mode = '';
  PosBlock? current;
  var headed = false;
  Sense? last;

  for (final node in top.children) {
    final h = node.querySelector('h2,h3,h4,h5,h6');
    if (node.classes.contains('mw-heading') && h != null) {
      if (h.localName == 'h2') {
        final isEs = h.querySelector('span.headline-lang#es') != null;
        if (inEs && !isEs) break;
        inEs = isEs;
        found = found || isEs;
        mode = '';
        continue;
      }
      if (!inEs) continue;
      final text = squash(h.text).toLowerCase();
      final id = h.id.replaceFirst(RegExp(r'_\d+$'), '');
      if (id == 'Etimología') {
        mode = 'ety';
      } else if (_esPos.any(text.startsWith)) {
        final genders = <String>[
          for (final w in text.split(RegExp(r'\s+')))
            if (_esGender.containsKey(w)) _esGender[w]!,
        ];
        final pos = squash(
          text
              .split(RegExp(r'\s+'))
              .where((w) => !_esGender.containsKey(w) && w != 'y')
              .join(' '),
        );
        current = PosBlock(pos, gender: genders.join('/'));
        headed = false;
        last = null;
        blocks.add(current);
        mode = 'pos';
      } else {
        mode = '';
      }
      continue;
    }
    if (!inEs) continue;

    // the pronunciation table and the recording sit near the top
    final tables = [
      if (node.localName == 'table' && node.classes.contains('pron-graf'))
        node,
      ...node.querySelectorAll('table.pron-graf'),
    ];
    for (final t in tables) {
      for (final row in t.querySelectorAll('tr')) {
        final cells = row.children.where((c) => c.localName == 'td').toList();
        if (cells.length < 2 || !cells[0].text.contains('AFI')) continue;
        final c = plainCopy(cells[1], '.ext-phonos');
        for (final m in RegExp(r'\[[^\]]+\]').allMatches(c.text)) {
          final v = squash(m.group(0)!);
          if (!ipa.contains(v) && ipa.length < 3) ipa.add(v);
        }
        if (audio == null) {
          final a = cells[1].querySelector(
            'a[href\$=".mp3"], a[href\$=".ogg"], a[href\$=".oga"]',
          );
          final href = a?.attributes['href'];
          if (href != null) audio = absoluteUrl(href);
        }
      }
    }
    if (audio == null) {
      final src = node.querySelector('audio source')?.attributes['src'];
      if (src != null) audio = absoluteUrl(src);
    }

    if (mode == 'ety' && etymology.isEmpty && node.localName == 'p') {
      final t = squash(plainCopy(node).text);
      if (t.isNotEmpty && !t.toLowerCase().contains('pendiente')) {
        etymology = shorten(t, 220);
      }
    } else if (mode == 'pos' && current != null) {
      final c = current;
      if (node.localName == 'p' && !headed && node.querySelector('b') != null) {
        headed = true;
        final copy = plainCopy(node, 'b');
        final parts = [
          for (final p in copy.text.split('¦'))
            if (squash(p).isNotEmpty) squash(p),
        ];
        final forms = shorten(parts.join(' · '), 90);
        final i = blocks.indexOf(c);
        current = PosBlock(c.pos, gender: c.gender, forms: forms);
        if (i >= 0) blocks[i] = current;
      } else if (node.localName == 'dl') {
        final dt = node.querySelector('dt');
        final dd = node.querySelector('dd');
        if (dd == null) continue;
        final cur = current;
        if (dt != null) {
          // a numbered sense
          if (cur.senses.length >= maxDefs) {
            last = null;
            continue;
          }
          final copy = plainCopy(dd, 'ul,dl,.ref');
          final t = squash(copy.text);
          if (t.isEmpty) continue;
          last = Sense(t, labels: [], examples: []);
          cur.senses.add(last);
        }
        // the lines under the sense: usage, examples, synonyms, antonyms; an
        // example can sit in a dl of its own right after its sense
        for (final li in dd.querySelectorAll('li')) {
          final b = li.querySelector('b');
          final key = b == null ? '' : squash(b.text).toLowerCase();
          final body = _afterLabel(li, b);
          if (key.startsWith('sinónimo')) {
            if (!body.toLowerCase().startsWith('véase')) addNyms(syn, body);
          } else if (key.startsWith('antónimo')) {
            addNyms(ant, body);
          } else if (last == null) {
            continue;
          } else if (key.startsWith('uso') || key.startsWith('ámbito')) {
            for (final l in body.replaceAll(RegExp(r'\.$'), '').split(',')) {
              final v = squash(l).toLowerCase();
              if (v.isNotEmpty && !last.labels.contains(v)) {
                last.labels.add(v);
              }
            }
          } else if (key.startsWith('ejemplo') &&
              last.examples.length < maxExamples) {
            final cita = li.querySelector('span.cita');
            final t = cita != null ? squash(plainCopy(cita).text) : body;
            if (t.isNotEmpty) last.examples.add(Example(t));
          }
        }
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
        if (b.senses.isNotEmpty) b,
    ].take(maxBlocks).toList(),
    synonyms: syn.take(maxNyms).toList(),
    antonyms: ant.take(maxNyms).toList(),
    etymology: etymology,
  );
}

/// The text of a list item after its bold label ("Uso:"), without the
/// attribution of a quotation.
String _afterLabel(Element li, Element? label) {
  final c = plainCopy(li, '.ref,.mw-collapsible-toggle');
  if (label != null) {
    final b = c.querySelector('b');
    b?.remove();
  }
  return squash(c.text).replaceFirst(RegExp(r'^:\s*'), '');
}
