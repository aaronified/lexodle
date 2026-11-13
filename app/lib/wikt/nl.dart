import 'package:html/dom.dart' show Element, Text;
import 'package:html/parser.dart' as html;

import '../wiktionary.dart';
import 'north_util.dart';

final _nlPos = RegExp(
  r'(woord|werpsel|zetsel|voegsel|deeltje|uitdrukking|afkorting|eigennaam|letter|symbool)$',
);

/// Parses an nl.wiktionary (WikiWoordenboek) page: the section of Dutch (`h2`
/// "Nederlands"), with its pronunciation, parts of speech (`h4`), senses
/// (nested `ol`), examples, origin, synonyms and antonyms. Null when the page
/// has no Dutch section.
///
/// The pronunciation, origin, synonyms and antonyms are `h5` sections under the
/// language; the inflection table comes before the part-of-speech heading.
WordInfo? parseDutch(
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
  var inDutch = false, found = false;
  var mode = '';
  _Block? current;
  var pending = <Element>[];

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
        final isNl = h.id == 'Nederlands';
        if (inDutch && !isNl) break;
        inDutch = isNl;
        found = found || isNl;
        mode = '';
      } else if (!inDutch) {
        continue;
      } else if (h.localName == 'h4') {
        if (_nlPos.hasMatch(title)) {
          current = _Block(title, pending);
          pending = [];
          if (blocks.length < maxBlocks) blocks.add(current);
          mode = 'pos';
        } else {
          mode = '';
        }
      } else {
        mode = switch (title) {
          'uitspraak' => 'pron',
          'woordherkomst en -opbouw' => 'ety',
          'synoniemen' => 'syn',
          'antoniemen' => 'ant',
          _ => '',
        };
      }
      continue;
    }
    if (!inDutch) continue;

    if (node.localName == 'table' && node.classes.contains('infobox')) {
      // a form-of entry has its table after the heading, the others before it
      (mode == 'pos' && current != null ? current.tables : pending).add(node);
      continue;
    }

    switch (mode) {
      case 'pron' when node.localName == 'ul':
        for (final li in node.children.where((x) => x.localName == 'li')) {
          if (audio == null) {
            for (final a in li.querySelectorAll('a.internal')) {
              audio = commonsMp3(a.attributes['href']);
              if (audio != null) break;
            }
          }
          final t = squash(li.text.replaceAll(' ', ''));
          if (!t.startsWith('IPA')) continue;
          for (final m in RegExp(r'/[^/\s][^/]*/').allMatches(t)) {
            final s = m.group(0)!.trim();
            if (!ipa.contains(s) && ipa.length < 3) ipa.add(s);
          }
        }
      case 'ety' when node.localName == 'ul' && etymology.isEmpty:
        final t = squash(
          [
            for (final li in node.children.where((x) => x.localName == 'li'))
              without(li, 'sup,style').text,
          ].join(' '),
        ).replaceAll(RegExp(r'\s+([,;.])'), r'$1');
        if (t.isNotEmpty) etymology = shorten(t, 220);
      case 'pos' when current != null:
        final c = current;
        if (node.localName == 'p' &&
            c.gender.isEmpty &&
            node.querySelector('a[href*="Genus"]') != null) {
          // "het water o": the article, the word and the genus (m, v, o, m/v)
          final g = squash(
            node.querySelectorAll('a[href*="Genus"]').map((x) => x.text).join(' '),
          );
          c.gender = switch (g) {
            'o' => 'n',
            'v' => 'f',
            _ => g.replaceAll('v', 'f').replaceAll('o', 'n'),
          };
        } else if (node.localName == 'ol' && c.senses.isEmpty) {
          _senses(node, c.senses, maxDefs, maxExamples);
        }
      case 'syn' || 'ant' when node.localName == 'ul':
        for (final li in node.children.where((x) => x.localName == 'li')) {
          // "[1] (informeel) eendenbier, gemeentepils": the sense numbers and
          // the labels are not words
          var t = squash(without(li, 'sup,style').text);
          t = t.replaceFirst(RegExp(r'^\[[^\]]*\]\s*'), '');
          t = t.replaceFirst(RegExp(r'^(\([^)]*\)\s*)+'), '');
          for (final w in t.split(RegExp(r'[,;]'))) {
            addNym(mode == 'syn' ? syn : ant, w.replaceAll(RegExp(r'\s*\(\d+\)$'), ''));
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
        if (b.senses.isNotEmpty)
          PosBlock(b.pos, gender: b.gender, forms: _forms(b.tables))
            ..senses.addAll(b.senses),
    ],
    synonyms: syn.take(maxNyms).toList(),
    antonyms: ant.take(maxNyms).toList(),
    etymology: etymology,
  );
}

class _Block {
  _Block(this.pos, List<Element> before) : tables = [...before];
  final String pos;
  String gender = '';
  final List<Element> tables;
  final senses = <Sense>[];
}

/// Flattens a sense list: a sense, then its sub-senses, in page order.
void _senses(Element ol, List<Sense> into, int maxDefs, int maxExamples) {
  for (final li in ol.children.where((x) => x.localName == 'li')) {
    if (into.length >= maxDefs) return;
    final examples = <Example>[];
    for (final dl in li.children.where((x) => x.localName == 'dl')) {
      for (final dd in dl.children.where((x) => x.localName == 'dd')) {
        final lines = dd.querySelectorAll('li');
        for (final e in lines.isEmpty ? [dd] : lines) {
          final t = squash(
            without(e, 'sup,style').text.replaceAll(RegExp(r'^[\s ▸]+'), ''),
          );
          if (t.isNotEmpty && examples.length < maxExamples) {
            examples.add(Example(t));
          }
        }
      }
    }
    final copy = without(li, 'ol,ul,dl,sup,style');
    final labels = <String>[];
    // the labels lead the sense as styled spans ("overgankelijk") or in
    // parentheses ("(scheikunde)")
    for (final n in copy.nodes.toList()) {
      if (n is Text && n.text.trim().isEmpty) continue;
      if (n is Element &&
          n.localName == 'span' &&
          (n.attributes['style'] ?? '').contains('italic')) {
        final l = squash(n.text).replaceAll(RegExp(r'^\(|\)$'), '');
        if (l.isNotEmpty) labels.add(l.toLowerCase());
        n.remove();
        continue;
      }
      break;
    }
    var t = squash(copy.text);
    while (true) {
      final m = RegExp(r'^\(([^)]*)\)\s*').firstMatch(t);
      if (m == null) break;
      if (m.group(1)!.isNotEmpty) labels.add(m.group(1)!.toLowerCase());
      t = t.substring(m.end);
    }
    if (t.isNotEmpty) {
      into.add(Sense(t, labels: labels, examples: examples));
    }
    final sub = li.children.where((x) => x.localName == 'ol').firstOrNull;
    if (sub != null) _senses(sub, into, maxDefs, maxExamples);
  }
}

/// The lines of a table cell, split at its line breaks.
List<String> _lines(Element td) {
  final out = <String>[];
  var cur = StringBuffer();
  void flush() {
    final t = squash(cur.toString());
    if (t.isNotEmpty && t != '-') out.add(t);
    cur = StringBuffer();
  }

  for (final n in td.nodes) {
    if (n is Element && n.localName == 'br') {
      flush();
    } else {
      cur.write(n is Element ? n.text : n.text ?? '');
    }
  }
  flush();
  return out;
}

/// One short line from the first inflection table that has something to say:
/// a noun's plural, a verb's preterite and participle, an adjective's
/// comparison.
String _forms(List<Element> tables) {
  for (final t in tables) {
    final heads = [for (final x in t.querySelectorAll('th')) squash(x.text)];
    final rows = t.querySelectorAll('tr');
    String out = '';
    if (heads.contains('meervoud')) {
      for (final r in rows) {
        final tds = r.querySelectorAll('td');
        if (tds.length >= 3 && squash(tds.first.text) == 'naamwoord') {
          final p = _lines(tds[2]);
          if (p.isNotEmpty) out = 'meervoud ${p.join(', ')}';
        }
      }
    } else if (heads.any((x) => x.startsWith('verleden'))) {
      for (final r in rows) {
        final tds = r.querySelectorAll('td');
        if (tds.length == 3 && tds.first.attributes['width'] != null) {
          final a = _lines(tds[1]), b = _lines(tds[2]);
          out = [
            if (a.isNotEmpty) 'verleden tijd ${a.first}',
            if (b.isNotEmpty) 'voltooid deelwoord ${b.first}',
          ].join(', ');
        }
      }
    } else if (heads.contains('vergrotend')) {
      for (final r in rows) {
        final tds = r.querySelectorAll('td');
        if (tds.length >= 4 && squash(tds.first.text) == 'onverbogen') {
          final a = _lines(tds[2]), b = _lines(tds[3]);
          out = [
            if (a.isNotEmpty) 'vergrotend ${a.first}',
            if (b.isNotEmpty) 'overtreffend ${b.first}',
          ].join(', ');
        }
      }
    }
    if (out.isNotEmpty) return out;
  }
  return '';
}
