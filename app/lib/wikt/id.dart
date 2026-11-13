import 'package:html/dom.dart' show Element;
import 'package:html/parser.dart' as html;

import '../wiktionary.dart' show Example, PosBlock, Sense, WordInfo;
import 'east_util.dart';

String _idHeading(Element e) => squash(e.text).toLowerCase();

/// Parses an id.wiktionary page: the section of the Indonesian language
/// (heading "Bahasa Indonesia"), with its recording, parts of speech, senses,
/// examples, etymology, synonyms and antonyms. Null when the page has no
/// Indonesian section. The edition gives no IPA, only a hyphenation.
WordInfo? parseIndonesian(
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
  final blocks = <_IdBlock>[];
  final syn = <String>[], ant = <String>[];
  var etymology = '';
  var inId = false, found = false;
  var mode = '';
  _IdBlock? current;

  void addNyms(List<String> into, Element list) {
    for (final a in list.querySelectorAll('a')) {
      final href = a.attributes['href'] ?? '';
      if (href.startsWith('#') || href.contains('redlink=1')) continue;
      final t = squash(a.text);
      if (t.isNotEmpty && !into.contains(t)) into.add(t);
    }
  }

  for (final node in top.children) {
    final h = node.classes.contains('mw-heading')
        ? node.querySelector('h2')
        : null;
    if (h != null) {
      final isId = _idHeading(h) == 'bahasa indonesia';
      if (inId && !isId) break;
      inId = isId;
      found = found || isId;
      mode = '';
      continue;
    }
    if (!inId) continue;

    // the section headers are plain divs: "Nomina", "Etimologi", "Sinonim"
    if (node.classes.contains('section-header')) {
      final name = _idHeading(node);
      if (node.classes.contains('section-header-def')) {
        if (name == 'terjemahan') {
          mode = '';
        } else {
          current = _IdBlock(name);
          blocks.add(current);
          mode = 'pos';
        }
      } else if (name == 'etimologi') {
        mode = 'ety';
      } else if (name == 'sinonim') {
        mode = 'syn';
      } else if (name == 'antonim') {
        mode = 'ant';
      } else {
        mode = '';
      }
      continue;
    }

    // the recording and the pronunciation sit before the first header
    for (final e in node.querySelectorAll('span.IPA')) {
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

    if (mode == 'ety' && etymology.isEmpty && node.localName == 'p') {
      final t = squash(without(node, 'sup,style').text);
      if (t.isNotEmpty) etymology = shorten(t, 220);
    } else if (mode == 'pos' && current != null && node.localName == 'ol') {
      if (current.senses.isNotEmpty) continue;
      for (final li in node.children.where((x) => x.localName == 'li')) {
        if (current.senses.length >= maxDefs) break;
        final examples = <Example>[];
        // the sense's own examples: "<br><i>..</i>" or a nested line
        for (final i in li.children.where((x) => x.localName == 'i')) {
          final t = squash(without(i, 'sup,style').text);
          if (i.querySelector('.usage-label-sense') == null && t.isNotEmpty) {
            examples.add(Example(t));
          }
        }
        for (final dd in li.querySelectorAll('dl > dd > i')) {
          final t = squash(without(dd, 'sup,style').text);
          if (t.isNotEmpty) examples.add(Example(t));
        }
        // a quotation from a book is the last resort
        if (examples.isEmpty) {
          for (final q in li.querySelectorAll('.e-quotation')) {
            final t = squash(without(q, 'sup,style').text);
            if (t.isNotEmpty) examples.add(Example(t));
          }
        }
        final copy = without(li, 'ul,ol,dl,div,style,sup,br');
        // the examples written after a <br> are not part of the sense
        for (final i in copy.children.where((x) => x.localName == 'i')) {
          if (i.querySelector('.usage-label-sense') == null) i.remove();
        }
        final labels = <String>[
          for (final l in copy.querySelectorAll(
            '.usage-label-sense .ib-content',
          ))
            if (squash(l.text).isNotEmpty) squash(l.text).toLowerCase(),
        ];
        for (final x in copy.querySelectorAll(
          '.usage-label-sense,a[href*="Kategori:"]',
        )) {
          x.remove();
        }
        final t = squash(copy.text).replaceFirst(RegExp(r'\s*:$'), '');
        if (t.isNotEmpty) {
          current.senses.add(
            Sense(
              t,
              labels: labels,
              examples: examples.take(maxExamples).toList(),
            ),
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
        PosBlock(b.pos)..senses.addAll(b.senses),
    ],
    synonyms: syn.take(maxNyms).toList(),
    antonyms: ant.take(maxNyms).toList(),
    etymology: etymology,
  );
}

/// A part of speech of an Indonesian entry while it is being read.
class _IdBlock {
  _IdBlock(this.pos);
  final String pos;
  final senses = <Sense>[];
}
