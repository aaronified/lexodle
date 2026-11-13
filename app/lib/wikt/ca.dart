import 'package:html/parser.dart' as html;

import '../wiktionary.dart';
import 'south_util.dart';

const _caPos = [
  'nom',
  'verb',
  'adjectiu',
  'adverbi',
  'pronom',
  'preposició',
  'conjunció',
  'interjecció',
  'article',
  'numeral',
  'locució',
  'prefix',
  'sufix',
  'contracció',
  'abreviatura',
  'símbol',
  'lletra',
  'participi',
  'determinant',
  'sigla',
  'onomatopeia',
];

/// Parses a ca.wiktionary page: the section of Catalan (h2 "Català", not
/// "Català antic"). The pronunciation and the etymology are two list items
/// ("Pronúncia", "Etimologia") under the language heading, the parts of speech
/// are h3 headings, the synonyms an h4 list with one item per sense. Null when
/// the page has no Catalan section.
WordInfo? parseCatalan(
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
  var inCa = false, found = false;
  var mode = '';
  PosBlock? current;
  var headed = false;

  String unquote(String s) =>
      s.replaceAll(RegExp('^["“«]\\s*|\\s*["”»]\$'), '');

  for (final node in top.children) {
    final h = node.querySelector('h2,h3,h4,h5,h6');
    if (node.classes.contains('mw-heading') && h != null) {
      if (h.localName == 'h2') {
        final isCa = h.id == 'Català';
        if (inCa && !isCa) break;
        inCa = isCa;
        found = found || isCa;
        mode = '';
        continue;
      }
      if (!inCa) continue;
      final text = squash(h.text).toLowerCase();
      if (text.startsWith('etimologia')) {
        mode = 'ety';
      } else if (text.startsWith('sinònim')) {
        mode = 'syn';
      } else if (text.startsWith('antònim')) {
        mode = 'ant';
      } else if (_caPos.any(text.startsWith)) {
        current = PosBlock(text.replaceFirst(RegExp(r'\s+\d+$'), ''));
        headed = false;
        blocks.add(current);
        mode = 'pos';
      } else {
        mode = '';
      }
      continue;
    }
    if (!inCa) continue;

    // "Pronúncia: oriental /kəˈmi/, occidental /kaˈmi/" and "Etimologia: ..."
    // sit in a list right under the language heading
    for (final li in node.querySelectorAll('li')) {
      final key = squash(li.querySelector('span')?.text ?? '').toLowerCase();
      if (key == 'pronúncia') {
        for (final e in li.querySelectorAll('span.IPA')) {
          final t = squash(e.text);
          if (t.isNotEmpty && !ipa.contains(t) && ipa.length < 3) ipa.add(t);
        }
        if (audio == null) {
          final href = li
              .querySelector('a[href\$=".mp3"], a[href\$=".ogg"]')
              ?.attributes['href'];
          if (href != null) audio = absoluteUrl(href);
        }
      } else if (key == 'etimologia' && etymology.isEmpty) {
        final c = plainCopy(li, 'span:first-child');
        final t = squash(c.text).replaceFirst(RegExp(r'^:\s*'), '');
        if (t.isNotEmpty) etymology = shorten(t, 220);
      }
    }

    if (mode == 'ety' && etymology.isEmpty && node.localName == 'p') {
      final t = squash(plainCopy(node).text);
      if (t.isNotEmpty) etymology = shorten(t, 220);
    } else if ((mode == 'syn' || mode == 'ant') && node.localName == 'ul') {
      for (final li in node.children.where((x) => x.localName == 'li')) {
        addNyms(mode == 'syn' ? syn : ant, squash(plainCopy(li).text));
      }
    } else if (mode == 'pos' && current != null) {
      final c = current;
      if (node.localName == 'p' && !headed) {
        headed = true;
        // span.gender also carries "trans.", "pron." on a verb and "inv." on an
        // adjective: only m, f and n are a gender
        final gender = [
          for (final g in node.querySelectorAll('span.gender abbr'))
            squash(g.text).replaceAll('.', '').toLowerCase(),
        ].where((g) => g == 'm' || g == 'f' || g == 'n').join('/');
        final copy = plainCopy(node, '.headword,.gender');
        var forms = squash(copy.text.replaceAll(RegExp('[\u200e\u200f]'), ''));
        forms = forms.replaceAll(RegExp(r'^\(|\)$'), '').trim();
        final filled = PosBlock(
          c.pos,
          gender: gender,
          forms: shorten(forms, 90),
        );
        final i = blocks.indexOf(c);
        if (i >= 0) blocks[i] = filled;
        current = filled;
      } else if (node.localName == 'ol' && c.senses.isEmpty) {
        for (final li in node.children.where((x) => x.localName == 'li')) {
          if (c.senses.length >= maxDefs) break;
          final examples = <Example>[];
          for (final ex in li.querySelectorAll('dl dd, ul li')) {
            final t = shorten(unquote(squash(plainCopy(ex).text)), 200);
            if (t.isNotEmpty && examples.length < maxExamples) {
              examples.add(Example(t));
            }
          }
          final copy = plainCopy(li, 'ul,ol,dl,div');
          final labels = <String>[
            for (final l in copy.querySelectorAll('span.ib-content'))
              if (squash(l.text).isNotEmpty) squash(l.text).toLowerCase(),
          ];
          for (final x in copy.querySelectorAll(
            'span.ib-content,span.ib-brac,span.ib-comma',
          )) {
            x.remove();
          }
          final t = squash(copy.text);
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
