import 'package:html/dom.dart' show Element;
import 'package:html/parser.dart' as html;

import '../wiktionary.dart' show Example, PosBlock, Sense, WordInfo;
import 'east_util.dart';

/// Third-level headings of a Turkish entry that are not a part of speech.
const _trNotPos = {
  'söyleniş',
  'köken',
  'kaynakça',
  'farklı yazılışlar',
  'ek okumalar',
  'ayrıca bakınız',
  'notlar',
};

String _trHeading(Element h) =>
    squash(h.text).replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();

/// Parses a tr.wiktionary page: the section of the Turkish language (heading
/// "Türkçe"), with its pronunciation, parts of speech, senses, examples,
/// etymology and antonyms. Null when the page has no Turkish section.
WordInfo? parseTurkish(
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
  final blocks = <_TrBlock>[];
  final syn = <String>[], ant = <String>[];
  var etymology = '';
  var inTr = false, found = false;
  var mode = '';
  _TrBlock? current;

  void addNyms(List<String> into, Element list) {
    for (final a in list.querySelectorAll('a')) {
      final href = a.attributes['href'] ?? '';
      if (href.startsWith('#') || href.contains('redlink=1')) continue;
      final t = squash(a.text);
      if (t.isNotEmpty && !into.contains(t)) into.add(t);
    }
  }

  for (final node in top.children) {
    final h = node.querySelector('h2,h3,h4,h5');
    if (node.classes.contains('mw-heading') && h != null) {
      final name = _trHeading(h);
      if (h.localName == 'h2') {
        final isTr = name == 'türkçe';
        if (inTr && !isTr) break;
        inTr = isTr;
        found = found || isTr;
        mode = '';
        continue;
      }
      if (!inTr) continue;
      if (name == 'söyleniş') {
        mode = 'pron';
      } else if (name == 'köken') {
        mode = 'ety';
      } else if (name == 'eş anlamlılar' || name == 'eş anlamlı') {
        mode = 'syn';
      } else if (name == 'zıt anlamlılar' || name == 'karşıt anlamlılar') {
        mode = 'ant';
      } else if (h.localName == 'h3' && !_trNotPos.contains(name)) {
        current = _TrBlock(name);
        blocks.add(current);
        mode = 'pos';
      } else {
        mode = '';
      }
      continue;
    }
    if (!inTr) continue;

    if (mode == 'pron') {
      for (final e in node.querySelectorAll('span.IPA')) {
        final t = squash(e.text);
        if (t.isNotEmpty && !ipa.contains(t) && ipa.length < 3) ipa.add(t);
      }
      if (audio == null) {
        for (final s in node.querySelectorAll('audio source')) {
          final src = s.attributes['src'];
          if (src != null && s.attributes['type'] == 'audio/mpeg') {
            audio = absUrl(src);
            break;
          }
        }
      }
    } else if (mode == 'ety' && etymology.isEmpty && node.localName == 'p') {
      // the Arabic and Ottoman spellings are left out, their transcriptions
      // stay
      final t = squash(
        without(
          node,
          'sup,style,[lang=ar],[lang=ota],[lang=fa],.mention-gloss-double-quote',
        ).text,
      ).replaceAll('\u200e', '').replaceAll(RegExp(r'\s+'), ' ').replaceAll(RegExp(r'\s*\(\s*\)'), '').replaceAll('( ', '(').replaceAll(' )', ')');
      if (t.isNotEmpty) etymology = shorten(t, 220);
    } else if (mode == 'pos' && current != null) {
      if (node.localName == 'p' && node.querySelector('.headword') != null) {
        // "kalem (belirtme hâli kalemi, çoğulu kalemler)"
        final copy = without(node, '.headword,sup,style');
        current.forms = squash(copy.text).replaceAll(RegExp(r'^\(|\)$'), '');
      } else if (node.localName == 'ol' && current.senses.isEmpty) {
        for (final li in node.children.where((x) => x.localName == 'li')) {
          if (current.senses.length >= maxDefs) break;
          final examples = <Example>[];
          for (final ex in li.querySelectorAll('ul > li, dl > dd')) {
            final x = squash(without(ex, 'sup,style,img').text);
            // "eş anlamlısı: betik" is a note on the sense, not an example
            final nym = RegExp(
              r'^(eş|zıt|karşıt) anlamlısı:\s*(.+)$',
              caseSensitive: false,
            ).firstMatch(x);
            if (nym != null) {
              final into = nym.group(1)!.toLowerCase() == 'eş' ? syn : ant;
              for (final w in nym.group(2)!.split(RegExp(r'[,;]'))) {
                final v = squash(w);
                if (v.isNotEmpty && !into.contains(v)) into.add(v);
              }
              continue;
            }
            if (x.isNotEmpty) examples.add(Example(x));
            if (examples.length >= maxExamples) break;
          }
          final copy = without(li, 'ul,ol,dl,div,style,sup,img');
          var t = squash(copy.text);
          // "(tarım) Aşı yapmak için..." : the leading field label
          final labels = <String>[];
          final m = RegExp(r'^\(([^()]+)\)\s*').firstMatch(t);
          if (m != null && t.length > m.end) {
            labels.addAll([
              for (final l in m.group(1)!.split(','))
                if (squash(l).isNotEmpty) squash(l).toLowerCase(),
            ]);
            t = t.substring(m.end);
          }
          if (t.isNotEmpty) {
            current.senses.add(Sense(t, labels: labels, examples: examples));
          }
        }
      }
    } else if ((mode == 'syn' || mode == 'ant') &&
        (node.localName == 'ol' || node.localName == 'ul')) {
      addNyms(mode == 'syn' ? syn : ant, node);
    }
  }

  if (!found) return null;
  return WordInfo(
    url: url,
    ipa: ipa,
    audio: audio,
    blocks: [
      for (final b in blocks.where((b) => b.senses.isNotEmpty).take(maxBlocks))
        PosBlock(b.pos, forms: b.forms)..senses.addAll(b.senses),
    ],
    synonyms: syn.take(maxNyms).toList(),
    antonyms: ant.take(maxNyms).toList(),
    etymology: etymology,
  );
}

/// A part of speech of a Turkish entry while it is being read.
class _TrBlock {
  _TrBlock(this.pos);
  final String pos;
  String forms = '';
  final senses = <Sense>[];
}
