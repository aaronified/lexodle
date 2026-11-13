import 'package:html/parser.dart' as html;

import '../wiktionary.dart';
import 'south_util.dart';

const _itPos = [
  'sostantivo',
  'verbo',
  'voce verbale',
  'aggettivo',
  'avverbio',
  'pronome',
  'preposizione',
  'congiunzione',
  'interiezione',
  'articolo',
  'numerale',
  'locuzione',
  'prefisso',
  'suffisso',
  'lettera',
  'simbolo',
  'abbreviazione',
  'participio',
  'particella',
  'forma',
  'sigla',
  'nome proprio',
];

/// Parses an it.wiktionary page: the Italian section (h2 "Italiano"), with
/// its pronunciation, parts of speech (h3), senses (`ol`), etymology,
/// synonyms and antonyms (Sinonimi and Contrari sections). Null when the
/// page has no Italian section. The recording, when there is one, is the `audio` element of the pronunciation.
WordInfo? parseItalian(
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
  var inIt = false, found = false;
  var mode = '';
  PosBlock? current;
  var headed = false;

  for (final node in top.children) {
    final h = node.querySelector('h2,h3,h4,h5,h6');
    if (node.classes.contains('mw-heading') && h != null) {
      if (h.localName == 'h2') {
        final isIt = h.id == 'Italiano';
        if (inIt && !isIt) break;
        inIt = isIt;
        found = found || isIt;
        mode = '';
        continue;
      }
      if (!inIt) continue;
      final text = squash(h.text).toLowerCase();
      if (h.id.startsWith('Etimologia')) {
        mode = 'ety';
      } else if (h.id == 'Sinonimi') {
        mode = 'syn';
      } else if (h.id == 'Contrari') {
        mode = 'ant';
      } else if (h.id == 'Pronuncia') {
        mode = 'pron';
      } else if (_itPos.any(text.startsWith)) {
        current = PosBlock(text.replaceFirst(RegExp(r'\s+\d+$'), ''));
        headed = false;
        blocks.add(current);
        mode = 'pos';
      } else if (mode == 'pos' && h.localName == 'h4') {
        // Transitivo, Ausiliare...: still the same part of speech
      } else {
        mode = '';
      }
      continue;
    }
    if (!inIt) continue;

    if (mode == 'pron') {
      for (final e in node.querySelectorAll('span.IPA')) {
        final t = squash(e.text);
        if (t.isNotEmpty && !ipa.contains(t) && ipa.length < 3) ipa.add(t);
      }
      if (audio == null) {
        final sources = node.querySelectorAll('audio source');
        final mp3 = sources.where((x) => x.attributes['type'] == 'audio/mpeg');
        final src = (mp3.isNotEmpty ? mp3 : sources)
            .map((x) => x.attributes['src'])
            .whereType<String>()
            .firstOrNull;
        if (src != null) audio = absoluteUrl(src);
      }
    } else if (mode == 'ety' && etymology.isEmpty && node.localName == 'p') {
      final t = squash(plainCopy(node).text);
      if (t.isNotEmpty) etymology = shorten(t, 220);
    } else if ((mode == 'syn' || mode == 'ant') &&
        (node.localName == 'ol' || node.localName == 'ul')) {
      for (final li in node.children.where((x) => x.localName == 'li')) {
        addNyms(mode == 'syn' ? syn : ant, squash(plainCopy(li).text));
      }
    } else if (mode == 'pos' && current != null) {
      final c = current;
      if (node.localName == 'p' && !headed) {
        // "metà f inv": the gender and the rest of the headword line
        headed = true;
        final copy = plainCopy(node, 'b,small');
        final line = squash(copy.text);
        final m = RegExp(r'^(m|f|n)\b\s*(.*)$').firstMatch(line);
        final both = RegExp(r'^m e f\b\s*(.*)$').firstMatch(line);
        final PosBlock filled;
        if (both != null) {
          filled = PosBlock(c.pos, gender: 'm/f', forms: both.group(1)!);
        } else if (m != null) {
          filled = PosBlock(c.pos, gender: m.group(1)!, forms: m.group(2)!);
        } else {
          filled = PosBlock(c.pos, forms: line);
        }
        final i = blocks.indexOf(c);
        if (i >= 0) blocks[i] = filled;
        current = filled;
      } else if (node.localName == 'ol' && c.senses.isEmpty) {
        for (final li in node.children.where((x) => x.localName == 'li')) {
          if (c.senses.length >= maxDefs) break;
          final examples = <Example>[];
          for (final ex in li.querySelectorAll('ul > li')) {
            final t = squash(plainCopy(ex, 'small').text);
            if (t.isNotEmpty && examples.length < maxExamples) {
              examples.add(Example(t));
            }
          }
          // the labels lead the sense: "(religione)" in small italics
          final copy = plainCopy(li, 'ul,ol,dl,div');
          final labels = <String>[];
          for (final s in copy.querySelectorAll('small')) {
            final t = squash(s.text).replaceAll(RegExp(r'^\(|\)$'), '');
            if (t.isNotEmpty) labels.add(t.toLowerCase());
            s.remove();
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
