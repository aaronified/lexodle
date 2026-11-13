import 'package:html/dom.dart' show Element;
import 'package:html/parser.dart' as html;

import '../wiktionary.dart' show Example, PosBlock, Sense, WordInfo;
import 'common.dart';

/// Third-level headings of a Czech entry that are not a part of speech.
const _csNotPos = {
  'výslovnost',
  'dělení',
  'etymologie',
  'varianty',
  'související',
  'slovní spojení',
  'fráze a idiomy',
  'přísloví',
  'překlady',
  'synonyma',
  'antonyma',
  'poznámky',
  'externí odkazy',
};

String _csHeading(Element h) => squash(h.text).toLowerCase();

/// Parses a cs.wiktionary page: the section of the Czech language (heading
/// "čeština"), with its pronunciation, parts of speech, senses, examples,
/// etymology, synonyms and antonyms. Null when the page has no Czech section.
WordInfo? parseCzech(
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
  final blocks = <_CsBlock>[];
  final syn = <String>[], ant = <String>[];
  var etymology = '';
  var inCs = false, found = false;
  var mode = '';
  _CsBlock? current;

  void addNyms(List<String> into, Element list) {
    final copy = without(list, 'sup,style,link,i,.priznaky');
    for (final a in copy.querySelectorAll('a')) {
      final href = a.attributes['href'] ?? '';
      if (href.startsWith('#')) continue;
      final t = squash(a.text);
      if (t.isNotEmpty && !into.contains(t)) into.add(t);
    }
  }

  for (final node in top.children) {
    final h = node.querySelector('h2,h3,h4,h5');
    if (node.classes.contains('mw-heading') && h != null) {
      final name = _csHeading(h);
      if (h.localName == 'h2') {
        final isCs = name == 'čeština';
        if (inCs && !isCs) break;
        inCs = isCs;
        found = found || isCs;
        mode = '';
        continue;
      }
      if (!inCs) continue;
      if (h.localName == 'h3') {
        if (name == 'výslovnost') {
          mode = 'pron';
        } else if (name == 'etymologie') {
          mode = 'ety';
        } else if (!_csNotPos.contains(name)) {
          current = _CsBlock(name);
          blocks.add(current);
          mode = 'head';
        } else {
          mode = '';
        }
      } else {
        mode = switch (name) {
          'význam' => 'senses',
          'synonyma' => 'syn',
          'antonyma' => 'ant',
          _ => '',
        };
      }
      continue;
    }
    if (!inCs) continue;

    if (mode == 'pron') {
      // one transcription per line: "(oblastně)" variants follow it on the
      // same line and are left out
      for (final li in node.querySelectorAll('li')) {
        final e = li.querySelector('span.IPA');
        if (e == null) continue;
        final t = squash(e.text);
        if (t.isNotEmpty && !ipa.contains(t) && ipa.length < 3) ipa.add(t);
      }
      if (audio == null) {
        for (final a in node.querySelectorAll('a.oo-ui-buttonElement-button')) {
          final href = a.attributes['href'];
          if (href != null && href.endsWith('.mp3')) {
            audio = absUrl(href);
            break;
          }
        }
      }
    } else if (mode == 'ety' && etymology.isEmpty && node.localName == 'p') {
      final t = squash(without(node, 'sup,style').text);
      if (t.isNotEmpty && !t.toLowerCase().startsWith('etymologie chybí')) {
        etymology = shorten(t, 220);
      }
    } else if (mode == 'head' && current != null && node.localName == 'ul') {
      // "rod střední", "nedokonavé přechodné i nepřechodné", "tvrdé"
      var t = squash(without(node, 'sup,style').text);
      final g = RegExp(r'^rod\s+(\S+)').firstMatch(t);
      if (g != null) {
        current.gender = switch (g.group(1)) {
          'mužský' => 'm',
          'ženský' => 'f',
          'střední' => 'n',
          _ => g.group(1)!,
        };
        t = t.substring(g.end).replaceFirst(RegExp(r'^[,\s]+'), '');
      }
      current.forms = t;
      mode = '';
    } else if (mode == 'senses' && current != null && node.localName == 'ol') {
      if (current.senses.isNotEmpty) continue;
      for (final li in node.children.where((x) => x.localName == 'li')) {
        if (current.senses.length >= maxDefs) break;
        final examples = <Example>[];
        for (final ex in li.querySelectorAll('span.usageexample')) {
          final t = squash(without(ex, 'sup,style').text);
          if (t.isNotEmpty) examples.add(Example(t));
          if (examples.length >= maxExamples) break;
        }
        final copy = without(li, 'ul,ol,dl,div,style,sup');
        final labels = <String>[];
        for (final x in copy.querySelectorAll('span.priznaky')) {
          final l = squash(x.text).replaceAll(RegExp(r'^\(|\)$'), '');
          if (l.isNotEmpty) labels.add(l.toLowerCase());
          x.remove();
        }
        final t = squash(copy.text);
        if (t.isNotEmpty) {
          current.senses.add(Sense(t, labels: labels, examples: examples));
        }
      }
    } else if ((mode == 'syn' || mode == 'ant') && node.localName == 'ol') {
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
        PosBlock(b.pos, gender: b.gender, forms: b.forms)
          ..senses.addAll(b.senses),
    ],
    synonyms: syn.take(maxNyms).toList(),
    antonyms: ant.take(maxNyms).toList(),
    etymology: etymology,
  );
}

/// A part of speech of a Czech entry while it is being read.
class _CsBlock {
  _CsBlock(this.pos);
  final String pos;
  String gender = '', forms = '';
  final senses = <Sense>[];
}

