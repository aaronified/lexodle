import 'package:html/dom.dart' show Element;
import 'package:html/parser.dart' as html;

import '../wiktionary.dart';
import 'north_util.dart';

const _svPos = {
  'substantiv',
  'verb',
  'adjektiv',
  'adverb',
  'pronomen',
  'preposition',
  'konjunktion',
  'subjunktion',
  'interjektion',
  'räkneord',
  'artikel',
  'particip',
  'partikel',
  'förkortning',
  'prefix',
  'suffix',
  'egennamn',
  'förled',
  'efterled',
  'fras',
  'symbol',
};

/// Parses an sv.wiktionary page: the section of Swedish (`h2` "Svenska"), with
/// its pronunciation, parts of speech (`h3`), senses (`ol`), examples,
/// etymology, synonyms and antonyms. Null when the page has no Swedish
/// section.
///
/// Synonyms, antonyms and the etymology are `dd.semantic-relation` lines:
/// inside a sense for the ones that belong to it, in a `dl` after the list for
/// the ones that belong to the whole entry.
WordInfo? parseSwedish(
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
  var inSwedish = false, found = false;
  var mode = '';
  _Block? current;

  void addNym(List<String> into, String t) {
    t = squash(t);
    if (t.isEmpty || into.contains(t)) return;
    into.add(t);
  }

  void relations(Element node) {
    for (final dd in node.querySelectorAll('dd.semantic-relation')) {
      final cls = dd.className;
      if (cls.contains('template-etymologi')) {
        if (etymology.isEmpty) {
          final copy = without(dd, 'em,sup,style');
          final t = tidy(squash(copy.text));
          if (t.isNotEmpty) etymology = shorten(t, 220);
        }
      } else if (cls.contains('template-synonymer') ||
          cls.contains('template-antonymer')) {
        final into = cls.contains('template-synonymer') ? syn : ant;
        for (final a in dd.querySelectorAll('a')) {
          // links inside italics are notes ("(ålderdomligt)"), not words
          if (a.parent?.localName == 'i') continue;
          addNym(into, a.text);
        }
      }
    }
  }

  for (final node in top.children) {
    final h = node.querySelector('h2,h3,h4,h5,h6');
    if (node.classes.contains('mw-heading') && h != null) {
      final title = squash(h.text).toLowerCase();
      if (h.localName == 'h2') {
        final isSv = h.id == 'Svenska';
        if (inSwedish && !isSv) break;
        inSwedish = isSv;
        found = found || isSv;
        mode = '';
      } else if (!inSwedish) {
        continue;
      } else if (h.localName == 'h3') {
        if (_svPos.contains(title)) {
          current = _Block(title);
          if (blocks.length < maxBlocks) blocks.add(current);
          mode = 'pos';
        } else {
          mode = '';
        }
      } else {
        mode = title == 'etymologi' ? 'ety' : '';
      }
      continue;
    }
    if (!inSwedish) continue;

    if (mode == 'ety') {
      if (etymology.isEmpty && node.localName == 'p') {
        final t = tidy(squash(without(node, 'sup,style').text));
        if (t.isNotEmpty) etymology = shorten(t, 220);
      }
      continue;
    }
    if (mode != 'pos' || current == null) continue;
    final c = current;

    if (node.localName == 'table' && node.classes.contains('grammar')) {
      _grammar(node, c);
    } else if (node.localName == 'ul' &&
        squash(node.text).toLowerCase().startsWith('uttal')) {
      for (final e in node.querySelectorAll('span.ipa')) {
        final t = squash(e.text);
        if (t.isNotEmpty && ipa.length < 3 && !ipa.contains('[$t]')) {
          ipa.add('[$t]');
        }
      }
      if (ipa.isEmpty) {
        // a recording's button shows the transcription as its label
        for (final e in node.querySelectorAll('.oo-ui-labelElement-label')) {
          final t = squash(e.text);
          if (t.isNotEmpty && ipa.length < 3 && !ipa.contains('[$t]')) {
            ipa.add('[$t]');
          }
        }
      }
      if (audio == null) {
        for (final a in node.querySelectorAll('a')) {
          final href = a.attributes['href'] ?? '';
          if (href.contains('upload.wikimedia.org') && href.endsWith('.mp3')) {
            audio = absUrl(href);
            break;
          }
          audio ??= commonsMp3(href);
        }
      }
    } else if (node.localName == 'ol') {
      if (c.senses.isEmpty) _senses(node, c.senses, maxDefs, maxExamples);
      relations(node);
    } else if (node.localName == 'dl') {
      relations(node);
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

class _Block {
  _Block(this.pos);
  final String pos;
  String gender = '', forms = '';
  final senses = <Sense>[];
}

void _senses(Element ol, List<Sense> into, int maxDefs, int maxExamples) {
  for (final li in ol.children.where((x) => x.localName == 'li')) {
    if (into.length >= maxDefs) return;
    final examples = <Example>[];
    for (final dl in li.children.where((x) => x.localName == 'dl')) {
      for (final dd in dl.children.where((x) => x.localName == 'dd')) {
        // quotes of old texts nest another list: they are left out
        if (dd.classes.contains('semantic-relation') ||
            dd.querySelector('dl') != null) {
          continue;
        }
        final t = squash(without(dd, 'sup,style').text);
        if (t.isNotEmpty && examples.length < maxExamples) {
          examples.add(Example(t));
        }
      }
    }
    final copy = without(li, 'ol,ul,dl,sup,style');
    var t = squash(copy.text);
    final labels = <String>[];
    // "(kunna) lokalisera", "(musik) något av": the labels lead in parentheses
    while (true) {
      final m = RegExp(r'^\(([^)]*)\)\s*').firstMatch(t);
      if (m == null) break;
      if (m.group(1)!.isNotEmpty) labels.add(m.group(1)!.toLowerCase());
      t = t.substring(m.end);
    }
    if (t.isNotEmpty) {
      into.add(Sense(t, labels: labels, examples: examples));
    }
    for (final sub in li.children.where((x) => x.localName == 'ol')) {
      _senses(sub, into, maxDefs, maxExamples);
    }
  }
}

/// Gender and one short line of forms from the inflection table.
void _grammar(Element table, _Block b) {
  if (b.forms.isNotEmpty) return;
  final rows = table.querySelectorAll('tr');
  String th(Element r) => squash(r.querySelector('th')?.text ?? '');
  String first(Element td) => squash(td.text).split(RegExp(r'\s*,\s*')).first;
  switch (b.pos) {
    case 'substantiv':
      for (final r in rows) {
        final tds = r.querySelectorAll('td');
        final t = th(r);
        if (t == 'utrum' || t == 'neutrum') {
          b.gender = t == 'utrum' ? 'u' : 'n';
        }
        if (t == 'Nominativ' && tds.length >= 3) {
          final p = squash(tds[2].text);
          if (p.isNotEmpty && p != '–' && p != '-') b.forms = 'plural $p';
        }
      }
    case 'verb':
      String pret = '', sup = '';
      for (final r in rows) {
        final tds = r.querySelectorAll('td');
        if (tds.isEmpty) continue;
        if (th(r) == 'Preteritum' && pret.isEmpty) pret = first(tds.first);
        if (th(r) == 'Supinum' && sup.isEmpty) sup = first(tds.first);
      }
      b.forms = [
        if (pret.isNotEmpty) 'preteritum $pret',
        if (sup.isNotEmpty) 'supinum $sup',
      ].join(', ');
    case 'adjektiv':
      String neut = '', comp = '';
      for (final r in rows) {
        final ths = [for (final x in r.querySelectorAll('th')) squash(x.text)];
        final tds = r.querySelectorAll('td');
        if (ths.contains('Utrum') && tds.length >= 2 && comp.isEmpty) {
          comp = squash(tds[1].text);
        }
        if (ths.contains('Neutrum') && tds.isNotEmpty && neut.isEmpty) {
          neut = squash(tds.first.text);
        }
      }
      b.forms = [
        if (neut.isNotEmpty) 'neutrum $neut',
        if (comp.isNotEmpty) 'komparativ $comp',
      ].join(', ');
  }
}
