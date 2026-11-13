import 'package:html/dom.dart' show Element;
import 'package:html/parser.dart' as html;

import '../wiktionary.dart' show Example, PosBlock, Sense, WordInfo;
import 'east_util.dart';

/// Third-level headings of a Hungarian entry that are not a part of speech.
const _huNotPos = {
  'kiejtés',
  'etimológia',
  'fordítások',
  'szinonimák',
  'antonimák',
  'további információk',
  'származékok',
  'szókapcsolatok',
  'szólások, közmondások',
  'ragozás',
  'jegyzetek',
  'forrás',
  'források',
  'külső hivatkozások',
};

String _huHeading(Element h) => squash(h.text).toLowerCase();

/// Parses a hu.wiktionary page: the section of the Hungarian language (heading
/// "Magyar"), with its pronunciation, parts of speech, senses, examples,
/// etymology, synonyms and antonyms. Null when the page has no Hungarian
/// section.
WordInfo? parseHungarian(
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
  final blocks = <_HuBlock>[];
  final syn = <String>[], ant = <String>[];
  var etymology = '';
  var inHu = false, found = false;
  var mode = '';
  _HuBlock? current;

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
      final name = _huHeading(h);
      if (h.localName == 'h2') {
        final isHu = name == 'magyar';
        if (inHu && !isHu) break;
        inHu = isHu;
        found = found || isHu;
        mode = '';
        continue;
      }
      if (!inHu) continue;
      if (name == 'kiejtés') {
        mode = 'pron';
      } else if (name == 'etimológia') {
        mode = 'ety';
      } else if (name == 'szinonimák') {
        mode = 'syn';
      } else if (name == 'antonimák') {
        mode = 'ant';
      } else if (h.localName == 'h3' && !_huNotPos.contains(name)) {
        current = _HuBlock(name);
        blocks.add(current);
        mode = 'pos';
      } else {
        mode = '';
      }
      continue;
    }
    if (!inHu) continue;

    if (mode == 'pron') {
      for (final e in node.querySelectorAll('span.IPA')) {
        // the template writes "[ ˈɛmbɛr]"
        final t = squash(e.text).replaceFirst('[ ', '[');
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
    } else if (mode == 'ety' && etymology.isEmpty) {
      if (node.localName == 'p' || node.localName == 'ul') {
        final t = squash(
          without(
            node.localName == 'ul' ? node.querySelector('li') ?? node : node,
            'sup,style',
          ).text,
        );
        if (t.isNotEmpty) etymology = shorten(t, 220);
      }
    } else if (mode == 'pos' && current != null) {
      if (node.localName == 'p' && node.querySelector('.headword') != null) {
        // "kicsi (középfok kisebb, felsőfok legkisebb)": what follows the
        // headword
        final copy = without(node, '.headword,sup,style');
        current.forms = squash(copy.text).replaceAll(RegExp(r'^\(|\)$'), '');
      } else if (node.localName == 'ol') {
        for (final li in node.children.where((x) => x.localName == 'li')) {
          final copy = without(li, 'ul,ol,dl,div,style,sup');
          final t = squash(copy.text);
          // the nested examples and quotations of the sense (or, when the
          // line has no text of its own, of the sense before)
          final examples = <Example>[];
          for (final dd in li.querySelectorAll('dd')) {
            if (dd.querySelector('span.nyms') != null) continue;
            final x = squash(without(dd, 'sup,style').text);
            if (x.isNotEmpty) examples.add(Example(x));
          }
          for (final span in li.querySelectorAll('span.nyms')) {
            final cls = span.classes;
            if (cls.contains('antonima')) addNyms(ant, span);
            if (cls.contains('synonima')) addNyms(syn, span);
          }
          if (t.isEmpty) {
            if (current.senses.isNotEmpty && examples.isNotEmpty) {
              current.senses.last.examples.addAll(examples);
            }
            continue;
          }
          if (current.senses.length >= maxDefs) continue;
          current.senses.add(
            Sense(t, examples: examples.take(maxExamples).toList()),
          );
        }
      }
    } else if ((mode == 'syn' || mode == 'ant') && node.localName == 'ul') {
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

/// A part of speech of a Hungarian entry while it is being read.
class _HuBlock {
  _HuBlock(this.pos);
  final String pos;
  String forms = '';
  final senses = <Sense>[];
}
