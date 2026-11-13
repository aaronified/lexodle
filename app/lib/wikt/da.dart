import 'package:html/dom.dart' show Element;
import 'package:html/parser.dart' as html;

import '../wiktionary.dart';
import 'north_util.dart';

const _daPos = {
  'substantiv',
  'verbum',
  'adjektiv',
  'adverbium',
  'adverb',
  'pronomen',
  'præposition',
  'konjunktion',
  'interjektion',
  'talord',
  'artikel',
  'participium',
  'præfiks',
  'suffiks',
  'egennavn',
  'forkortelse',
  'udtryk',
  'ordsprog',
};

/// Parses a da.wiktionary page: the section of Danish (`h2` "Dansk"), with its
/// etymology and pronunciation (`h3`), parts of speech (`h3`), senses (`ol`),
/// inflection (`h4` "Bøjning"), synonyms and antonyms (`h4`). Null when the
/// page has no Danish section.
///
/// The edition is sparse: many entries have a single sense, no examples and no
/// pronunciation.
WordInfo? parseDanish(
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
  var inDanish = false, found = false;
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
        final isDa = h.id == 'Dansk';
        if (inDanish && !isDa) break;
        inDanish = isDa;
        found = found || isDa;
        mode = '';
      } else if (!inDanish) {
        continue;
      } else if (h.localName == 'h3') {
        if (_daPos.contains(title)) {
          current = _Block(title);
          if (blocks.length < maxBlocks) blocks.add(current);
          mode = 'pos';
        } else {
          mode = switch (title) {
            'etymologi' => 'ety',
            'udtale' => 'pron',
            _ => '',
          };
        }
      } else {
        // the h4 sections of a part of speech
        mode = switch (title) {
          'synonymer' => 'syn',
          'antonymer' => 'ant',
          'bøjning' => 'infl',
          _ => '',
        };
      }
      continue;
    }
    if (!inDanish) continue;

    switch (mode) {
      case 'ety' when node.localName == 'p' && etymology.isEmpty:
        final t = tidy(squash(without(node, 'sup,style').text));
        if (t.isNotEmpty) etymology = shorten(t, 220);
      case 'pron':
        for (final e in node.querySelectorAll('span.IPA')) {
          // the outer span wraps the ones that hold the transcriptions
          if (e.querySelector('span.IPA') != null) continue;
          for (final m in RegExp(
            r'/[^/\s][^/]*/|\[[^\]]+\]',
          ).allMatches(squash(e.text))) {
            final s = m.group(0)!;
            if (!ipa.contains(s) && ipa.length < 3) ipa.add(s);
          }
        }
        if (audio == null) {
          for (final a in node.querySelectorAll('a')) {
            audio = commonsMp3(a.attributes['href']);
            if (audio != null) break;
          }
        }
      case 'pos' when current != null:
        final c = current;
        if (node.localName == 'p' && c.gender.isEmpty && c.forms.isEmpty) {
          _headline(node, c);
        } else if (node.localName == 'ol' && c.senses.isEmpty) {
          _senses(node, c.senses, maxDefs, maxExamples);
        }
      case 'infl' when current != null:
        final t = node.localName == 'table'
            ? node
            : node.querySelector('table.inflection-table');
        if (t != null && current.forms.isEmpty) _table(t, current);
      case 'syn' || 'ant' when node.localName == 'ul':
        for (final li in node.children.where((x) => x.localName == 'li')) {
          final links = li.querySelectorAll('a');
          for (final a in links) {
            addNym(mode == 'syn' ? syn : ant, a.text);
          }
          if (links.isEmpty) addNym(mode == 'syn' ? syn : ant, li.text);
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
        // an entry with no definition yet (common here) still gives its forms
        if (b.senses.isNotEmpty || b.forms.isNotEmpty)
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

/// The headword line: "aften <i>fælleskøn</i>" gives the gender,
/// "lille (<i>intetkøn</i>: lille, <i>komparativ</i>: mindre)" the forms.
void _headline(Element p, _Block b) {
  final copy = without(p, 'sup,style');
  for (final x in copy.querySelectorAll('b')) {
    // the headword itself, but not the forms in bold inside the brackets
    if (x.parent == copy) {
      x.remove();
      break;
    }
  }
  final t = squash(copy.text);
  if (t.isEmpty) return;
  final paren = RegExp(r'^\((.*)\)$').firstMatch(t);
  if (paren != null) {
    b.forms = shorten(paren.group(1)!.replaceAll(': ', ' '), 140);
    return;
  }
  b.gender = switch (t) {
    'fælleskøn' => 'c',
    'intetkøn' => 'n',
    _ => t.length <= 20 ? t : '',
  };
}

void _senses(Element ol, List<Sense> into, int maxDefs, int maxExamples) {
  for (final li in ol.children.where((x) => x.localName == 'li')) {
    if (into.length >= maxDefs) return;
    final examples = <Example>[];
    for (final list in li.children.where(
      (x) => x.localName == 'dl' || x.localName == 'ul',
    )) {
      for (final e in list.children) {
        final t = squash(without(e, 'sup,style').text);
        if (t.isNotEmpty && examples.length < maxExamples) {
          examples.add(Example(t));
        }
      }
    }
    final copy = without(li, 'ol,ul,dl,sup,style');
    var t = squash(copy.text);
    final labels = <String>[];
    // "(astronomisk) Tidsrummet ...": the labels lead in parentheses
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

/// A noun's plural from the inflection table: the indefinite plural of the
/// nominative row.
void _table(Element table, _Block b) {
  for (final r in table.querySelectorAll('tr')) {
    final tds = r.querySelectorAll('td');
    final th = squash(r.querySelector('th')?.text ?? '');
    if (th.startsWith('nominativ') && tds.length >= 3) {
      final forms = [
        for (final s in tds[2].querySelectorAll('span.form-of')) squash(s.text),
      ];
      final plain = forms.isEmpty ? [squash(tds[2].text)] : forms;
      final t = plain.where((x) => x.isNotEmpty).join(', ');
      if (t.isNotEmpty) b.forms = 'flertal $t';
      return;
    }
  }
}
