import 'package:html/parser.dart' as html;

import '../wiktionary.dart';
import 'south_util.dart';

const _ptPos = [
  'substantivo',
  'adjetivo',
  'verbo',
  'forma verbal',
  'forma substantiva',
  'forma adjetiva',
  'forma adverbial',
  'advérbio',
  'pronome',
  'preposição',
  'conjunção',
  'interjeição',
  'artigo',
  'numeral',
  'locução',
  'prefixo',
  'sufixo',
  'contração',
  'sigla',
  'abreviatura',
  'letra',
  'símbolo',
  'particípio',
  'determinante',
  'onomatopeia',
];

/// Parses a pt.wiktionary page: the Portuguese section (the `h1` "Português",
/// which ends at the next `h1`: Galego, Galego-Português Medieval...). Parts
/// of speech, etymology, pronunciation and nyms are `h2` or `h3` headings
/// whose level changes from entry to entry, so they are told apart by name.
/// Null when the page has no Portuguese section.
WordInfo? parsePortuguese(
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
  var inPt = false, found = false;
  var mode = '';
  PosBlock? current;
  var headed = false;
  // the inflection table comes before the headword line: its rows are kept
  // until the line gives the gender
  var rows = <(String, String)>[];

  for (final node in top.children) {
    final h = node.querySelector('h1,h2,h3,h4,h5,h6');
    if (node.classes.contains('mw-heading') && h != null) {
      if (h.localName == 'h1') {
        final isPt = h.id == 'Português';
        if (inPt && !isPt) break;
        inPt = isPt;
        found = found || isPt;
        mode = '';
        continue;
      }
      if (!inPt) continue;
      final text = squash(h.text).toLowerCase();
      if (text.startsWith('etimologia')) {
        mode = 'ety';
      } else if (text.startsWith('pronúncia')) {
        mode = 'pron';
      } else if (text.startsWith('sinônimo') || text.startsWith('sinónimo')) {
        mode = 'syn';
      } else if (text.startsWith('antônimo') || text.startsWith('antónimo')) {
        mode = 'ant';
      } else if (_ptPos.any(text.startsWith)) {
        current = PosBlock(text.replaceFirst(RegExp(r'\s+\d+$'), ''));
        headed = false;
        rows = [];
        blocks.add(current);
        mode = 'pos';
      } else if (mode == 'pron' && h.localName == 'h3') {
        // Brasil, Portugal: still the pronunciation
      } else {
        mode = '';
      }
      continue;
    }
    if (!inPt) continue;

    if (mode == 'pron') {
      for (final li in node.querySelectorAll('li')) {
        final m = RegExp(r'AFI:\s*([/\[][^\s,;]+[/\]])').firstMatch(li.text);
        if (m != null && !ipa.contains(m.group(1)) && ipa.length < 3) {
          ipa.add(m.group(1)!);
        }
      }
      if (audio == null) {
        final src = node.querySelector('audio source')?.attributes['src'];
        if (src != null) audio = absoluteUrl(src);
      }
    } else if (mode == 'ety' && etymology.isEmpty) {
      if (node.localName == 'dl' || node.localName == 'p') {
        final t = squash(plainCopy(node).text);
        if (t.isNotEmpty) etymology = shorten(t, 220);
      }
    } else if ((mode == 'syn' || mode == 'ant') && node.localName == 'ul') {
      for (final li in node.children.where((x) => x.localName == 'li')) {
        addNyms(mode == 'syn' ? syn : ant, squash(plainCopy(li).text));
      }
    } else if (mode == 'pos' && current != null) {
      final c = current;
      if (node.localName == 'table' && node.classes.contains('flexpt')) {
        for (final tr in node.querySelectorAll('tr.forma')) {
          final tds = tr.children.where((x) => x.localName == 'td').toList();
          if (tds.length < 2) continue;
          rows.add((
            squash(tds.first.text).toLowerCase(),
            squash(tds.last.text),
          ));
        }
      } else if (node.localName == 'p' && !headed) {
        headed = true;
        final g = squash(node.querySelector('i')?.text ?? '').toLowerCase();
        final gender = switch (g) {
          'masculino' => 'm',
          'feminino' => 'f',
          'neutro' => 'n',
          _ when g.contains('masculino') && g.contains('feminino') => 'm/f',
          _ when g.contains('dois géneros') || g.contains('dois gêneros') =>
            'm/f',
          _ => '',
        };
        // the plural comes from the row of the gender (the first row when the
        // word is common to both)
        var plural = '';
        for (final (label, value) in rows) {
          if (gender == 'f' && !label.startsWith('feminino')) continue;
          if (value.isNotEmpty && value != '–') {
            plural = value;
            break;
          }
        }
        final filled = PosBlock(
          c.pos,
          gender: gender,
          forms: plural.isEmpty ? '' : 'plural $plural',
        );
        final i = blocks.indexOf(c);
        if (i >= 0) blocks[i] = filled;
        current = filled;
      } else if (node.localName == 'ol' && c.senses.isEmpty) {
        for (final li in node.children.where((x) => x.localName == 'li')) {
          if (c.senses.length >= maxDefs) break;
          final examples = <Example>[];
          for (final ex in li.querySelectorAll('ul > li')) {
            final t = squash(plainCopy(ex).text);
            if (t.isNotEmpty && examples.length < maxExamples) {
              examples.add(Example(shorten(t, 200)));
            }
          }
          var t = squash(plainCopy(li, 'ul,ol,dl,div').text);
          // the labels lead the sense: "(Brasil) ..."
          final labels = <String>[];
          for (;;) {
            final m = RegExp(r'^\(([^)]{1,30})\)\s*').firstMatch(t);
            if (m == null) break;
            labels.add(m.group(1)!.toLowerCase());
            t = t.substring(m.end);
          }
          t = t.replaceFirst(RegExp(r'\s*:$'), '');
          if (t.isNotEmpty) {
            c.senses.add(Sense(t, labels: labels, examples: examples));
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
