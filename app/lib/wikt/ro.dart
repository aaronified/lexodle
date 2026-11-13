import 'package:html/parser.dart' as html;

import '../wiktionary.dart';
import 'south_util.dart';

const _roPos = [
  'substantiv',
  'verb',
  'adjectiv',
  'adverb',
  'pronume',
  'prepoziție',
  'conjuncție',
  'interjecție',
  'articol',
  'numeral',
  'locuțiune',
  'prefix',
  'sufix',
  'abreviere',
  'simbol',
  'literă',
  'participiu',
  'determinant',
  'onomatopee',
];

/// Parses a ro.wiktionary page: the Romanian section (h2 "română"), whose
/// etymology, pronunciation and parts of speech are h3 headings (repeated
/// with a suffix when a word has several entries), and whose synonyms are an
/// h4 under the part of speech. Null when the page has no Romanian section.
WordInfo? parseRomanian(
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
  var inRo = false, found = false;
  var mode = '';
  PosBlock? current;

  for (final node in top.children) {
    final h = node.querySelector('h2,h3,h4,h5,h6');
    if (node.classes.contains('mw-heading') && h != null) {
      if (h.localName == 'h2') {
        final isRo = h.id == 'română';
        if (inRo && !isRo) break;
        inRo = isRo;
        found = found || isRo;
        mode = '';
        continue;
      }
      if (!inRo) continue;
      final text = squash(h.text).toLowerCase();
      if (text.startsWith('etimologie')) {
        mode = 'ety';
      } else if (text.startsWith('pronun')) {
        mode = 'pron';
      } else if (text.startsWith('sinonime')) {
        mode = 'syn';
      } else if (text.startsWith('antonime')) {
        mode = 'ant';
      } else if (h.localName == 'h3' && _roPos.any(text.startsWith)) {
        current = PosBlock(text.replaceFirst(RegExp(r'\s+\d+$'), ''));
        blocks.add(current);
        mode = 'pos';
      } else {
        mode = '';
      }
      continue;
    }
    if (!inRo) continue;

    if (mode == 'pron') {
      for (final li in node.querySelectorAll('li')) {
        final m = RegExp(r'AFI:\s*(/[^/]+/|\[[^\]]+\])').firstMatch(li.text);
        if (m != null && !ipa.contains(m.group(1)) && ipa.length < 3) {
          ipa.add(m.group(1)!);
        }
      }
      if (audio == null) {
        final src = node.querySelector('audio source')?.attributes['src'];
        final href = node
            .querySelector('a[href\$=".mp3"], a[href\$=".ogg"]')
            ?.attributes['href'];
        final a = src ?? href;
        if (a != null) audio = absoluteUrl(a);
      }
    } else if (mode == 'ety' && etymology.isEmpty && node.localName == 'p') {
      final t = squash(plainCopy(node).text);
      if (t.isNotEmpty) etymology = shorten(t, 220);
    } else if ((mode == 'syn' || mode == 'ant') &&
        (node.localName == 'p' || node.localName == 'ul')) {
      addNyms(mode == 'syn' ? syn : ant, squash(plainCopy(node).text));
    } else if (mode == 'pos' && current != null) {
      final c = current;
      if (node.localName == 'table' &&
          node.classes.any((x) => x.endsWith('-ron')) &&
          c.senses.isEmpty) {
        // the declension table: "f." in its first cell, the plural of the
        // nominative-accusative row
        final g = RegExp(
          r'^([mfn])\.?$',
        ).firstMatch(squash(node.querySelector('i')?.text ?? ''));
        var plural = '';
        for (final tr in node.querySelectorAll('tr')) {
          final tds = tr.children.where((x) => x.localName == 'td').toList();
          if (tds.length >= 3 &&
              squash(tds.first.text).toLowerCase().startsWith('nominativ')) {
            plural = squash(tds.last.text);
            break;
          }
        }
        final filled = PosBlock(
          c.pos,
          gender: g?.group(1) ?? '',
          forms: plural.isEmpty ? '' : 'plural $plural',
        );
        final i = blocks.indexOf(c);
        if (i >= 0) blocks[i] = filled;
        current = filled;
      } else if (node.localName == 'ol' && c.senses.isEmpty) {
        for (final li in node.children.where((x) => x.localName == 'li')) {
          if (c.senses.length >= maxDefs) break;
          final examples = <Example>[];
          for (final ex in li.querySelectorAll('dl dd, ul li')) {
            final t = squash(plainCopy(ex).text);
            if (t.isNotEmpty && examples.length < maxExamples) {
              examples.add(Example(t));
            }
          }
          var t = squash(plainCopy(li, 'ul,ol,dl,div').text);
          // the labels lead the sense: "(reg.) cameră"
          final labels = <String>[];
          for (;;) {
            final m = RegExp(r'^\(([^)]{1,30})\)\s*').firstMatch(t);
            if (m == null) break;
            labels.add(m.group(1)!.toLowerCase());
            t = t.substring(m.end);
          }
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
