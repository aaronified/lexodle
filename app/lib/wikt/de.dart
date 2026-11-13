import 'package:html/dom.dart' show Element;
import 'package:html/parser.dart' as html;

import '../wiktionary.dart';
import 'north_util.dart';

/// Parses a de.wiktionary page: the section of the German language (heading
/// `h2` "word (Deutsch)"), with its pronunciation, parts of speech (one `h3`
/// each, gender in the heading), numbered senses, examples, origin, synonyms
/// and antonyms. Null when the page has no German section.
///
/// The section is flat: after each part-of-speech heading come bold `<p>`
/// titles ("Bedeutungen:", "Beispiele:") each followed by a `<dl>` whose
/// `<dd>` lines start with their sense number, "[1]".
WordInfo? parseGerman(
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
  final syn = <String>[], ant = <String>[], related = <String>[];
  var etymology = '';
  var inGerman = false, found = false;
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
      if (h.localName == 'h2') {
        final isDe =
            h.querySelector('span#Deutsch') != null ||
            h.id.endsWith('_(Deutsch)');
        if (inGerman && !isDe) break;
        inGerman = isDe;
        found = found || isDe;
        mode = '';
      } else if (inGerman && h.localName == 'h3') {
        // "Substantiv, f": the part of speech, then the gender in <em>
        final a = h.querySelector('a');
        final pos = squash(
          a != null ? a.text : h.text.split(',').first,
        ).toLowerCase();
        final gender = squash(
          [for (final g in h.querySelectorAll('em')) g.text].join(' '),
        );
        current = _Block(pos, gender);
        if (blocks.length < maxBlocks) blocks.add(current);
        mode = '';
      } else if (inGerman) {
        mode = ''; // "Übersetzungen"
      }
      continue;
    }
    if (!inGerman || current == null) continue;
    final c = current;

    if (node.localName == 'p') {
      mode = switch (squash(node.text)) {
        'Aussprache:' => 'pron',
        'Bedeutungen:' => 'sense',
        'Beispiele:' => 'ex',
        'Herkunft:' => 'ety',
        'Synonyme:' => 'syn',
        'Gegenwörter:' => 'ant',
        'Sinnverwandte Wörter:' => 'rel',
        _ => '',
      };
      continue;
    }
    if (node.localName == 'table' &&
        node.classes.contains('inflection-table') &&
        c.forms.isEmpty) {
      c.forms = _forms(node);
      continue;
    }
    if (node.localName != 'dl') continue;
    final lines = node.children.where((x) => x.localName == 'dd').toList();

    switch (mode) {
      case 'pron':
        for (final dd in lines) {
          if (!squash(dd.text).startsWith('IPA')) continue;
          for (final e in dd.querySelectorAll('span.ipa')) {
            final t = squash(e.text);
            if (t.isNotEmpty && ipa.length < 3 && !ipa.contains('[$t]')) {
              ipa.add('[$t]');
            }
          }
        }
        if (audio == null) {
          for (final a in node.querySelectorAll('a.internal')) {
            final src = commonsMp3(a.attributes['href']);
            if (src != null) {
              audio = src;
              break;
            }
          }
        }
      case 'sense':
        for (final dd in lines) {
          if (c.senses.length >= maxDefs) break;
          final copy = without(dd, 'sup,style,ul,ol,dl,div');
          final labels = <String>[];
          // "[3] umgangssprachlich: Verwaltung": an italic lead ending in ":"
          final lead = copy.children.firstOrNull;
          if (lead != null && lead.localName == 'i') {
            final l = squash(lead.text).replaceFirst(RegExp(r'\s*:$'), '');
            final before = leadingText(copy);
            if (squash(lead.text).endsWith(':') &&
                RegExp(r'^\s*\[[^\]]*\]\s*$').hasMatch(before) &&
                l.isNotEmpty &&
                l.length <= 30) {
              labels.add(l.toLowerCase());
              lead.remove();
            }
          }
          final (nums, text) = _numbered(squash(copy.text));
          if (text.isEmpty) continue;
          c.senses.add(
            _Sense(nums.isEmpty ? '' : nums.first, text, labels: labels),
          );
        }
      case 'ex':
        for (final dd in lines) {
          final (nums, raw) = _numbered(squash(without(dd, 'sup,style').text));
          // "[2023:]" and "[Kenia:]" date or place the quote
          final text = raw.replaceFirst(RegExp(r'^\[[^\]]*:\]\s*'), '');
          if (text.isEmpty) continue;
          for (final s in c.senses) {
            if (nums.contains(s.number) || nums.contains('*')) {
              if (s.examples.length < maxExamples) s.examples.add(Example(text));
            }
          }
        }
      case 'ety':
        if (etymology.isEmpty && lines.isNotEmpty) {
          // the "→ gmh" language marks are <sup>
          final t = squash(
            without(lines.first, 'sup,style').text,
          ).replaceAll(RegExp(r'\s+([,;.])'), r'$1');
          if (t.isNotEmpty) etymology = shorten(t, 220);
        }
      case 'syn' || 'ant' || 'rel':
        final into = mode == 'syn' ? syn : (mode == 'ant' ? ant : related);
        for (final dd in lines) {
          for (final a in dd.querySelectorAll('a')) {
            // links inside italics are hints ("umgangssprachlich"), not words
            if (_inItalic(a, dd)) continue;
            addNym(into, a.text);
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
          PosBlock(b.pos, gender: b.gender, forms: b.forms)
            ..senses.addAll([
              for (final s in b.senses)
                Sense(s.text, labels: s.labels, examples: s.examples),
            ]),
    ],
    // "Sinnverwandte Wörter" stands in when the page has no "Synonyme"
    synonyms: (syn.isNotEmpty ? syn : related).take(maxNyms).toList(),
    antonyms: ant.take(maxNyms).toList(),
    etymology: etymology,
  );
}

class _Block {
  _Block(this.pos, this.gender);
  final String pos, gender;
  String forms = '';
  final senses = <_Sense>[];
}

class _Sense {
  _Sense(this.number, this.text, {this.labels = const []});
  final String number, text;
  final List<String> labels;
  final examples = <Example>[];
}

bool _inItalic(Element a, Element stop) {
  for (var p = a.parent; p != null && p != stop; p = p.parent) {
    if (p.localName == 'i') return true;
  }
  return false;
}

/// Splits a leading sense number: "[1, 2] text" gives ({"1","2"}, "text").
/// "[1–3]" expands to its range and "[*]" gives {"*"}.
(Set<String>, String) _numbered(String line) {
  final m = RegExp(r'^\[([^\]]*)\]\s*').firstMatch(line);
  if (m == null) return (<String>{}, line);
  final nums = <String>{};
  for (final part in m.group(1)!.split(RegExp(r'\s*,\s*'))) {
    final r = RegExp(r'^(\d+)\s*[–-]\s*(\d+)$').firstMatch(part);
    if (r != null) {
      for (var i = int.parse(r.group(1)!); i <= int.parse(r.group(2)!); i++) {
        nums.add('$i');
      }
    } else if (part.isNotEmpty && RegExp(r'^(\d+|\*)$').hasMatch(part)) {
      nums.add(part);
    }
  }
  // not a number in brackets ("[Kenia:] ..."): the line is kept whole
  if (nums.isEmpty) return (nums, line);
  return (nums, line.substring(m.end));
}

/// The headword's inflection table as one short line: a noun's plural, a
/// verb's preterite and past participle, an adjective's comparison.
String _forms(Element table) {
  final heads = [
    for (final x in table.querySelectorAll('th')) squash(x.text),
  ];
  String cell(Element td) => squash(td.text).replaceFirst(
    RegExp(r'^(der|die|das|am)\s+', caseSensitive: false),
    '',
  );
  final rows = table.querySelectorAll('tr');
  if (heads.contains('Plural') && heads.contains('Nominativ')) {
    for (final r in rows) {
      if (squash(r.querySelector('th')?.text ?? '') != 'Nominativ') continue;
      final tds = r.querySelectorAll('td');
      if (tds.length >= 2) {
        final p = cell(tds[1]);
        return p.isEmpty || p == '—' || p == '-' ? '' : 'plural $p';
      }
    }
    return '';
  }
  if (heads.contains('Komparativ')) {
    for (final r in rows) {
      final tds = r.querySelectorAll('td');
      if (tds.length >= 3) {
        final k = cell(tds[1]), s = squash(tds[2].text);
        return [
          if (k.isNotEmpty && k != '—') 'komparativ $k',
          if (s.isNotEmpty && s != '—') 'superlativ $s',
        ].join(', ');
      }
    }
    return '';
  }
  if (heads.contains('Präteritum')) {
    String pret = '', part = '';
    for (final r in rows) {
      final th = squash(r.querySelector('th')?.text ?? '');
      final tds = r.querySelectorAll('td');
      if (th == 'Präteritum' && tds.length >= 2 && pret.isEmpty) {
        pret = squash(tds[1].text);
      }
      if (tds.isNotEmpty && part.isEmpty && heads.contains('Partizip II')) {
        final head = r.previousElementSibling;
        if (head != null &&
            head.querySelectorAll('th').any(
              (x) => squash(x.text) == 'Partizip II',
            )) {
          part = squash(tds.first.text);
        }
      }
    }
    return [
      if (pret.isNotEmpty) 'präteritum $pret',
      if (part.isNotEmpty) 'partizip ii $part',
    ].join(', ');
  }
  return '';
}
