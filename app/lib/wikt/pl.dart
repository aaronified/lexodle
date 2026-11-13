import 'package:html/dom.dart' show Element, Text;
import 'package:html/parser.dart' as html;

import '../wiktionary.dart' show Example, PosBlock, Sense, WordInfo;
import 'common.dart';

const _plGender = {
  'męski': 'm',
  'męskoosobowy': 'm',
  'męskozwierzęcy': 'm',
  'męskorzeczowy': 'm',
  'żeński': 'f',
  'nijaki': 'n',
};

final _plNumber = RegExp(r'^\(\s*([\d.,\s\-–]+?)\s*\)\s*');

/// The sense numbers a "(1.1)", "(1.1-3)" or "(1.1-2, 2.1)" label stands for.
Set<String> plSenseKeys(String label) {
  final keys = <String>{};
  for (final part in label.split(',')) {
    final m = RegExp(r'^\s*(\d+)\.(\d+)(?:\s*[-–]\s*(\d+))?\s*$').firstMatch(part);
    if (m == null) continue;
    final a = int.parse(m.group(2)!);
    final b = int.tryParse(m.group(3) ?? '') ?? a;
    for (var i = a; i <= b && i - a < 30; i++) {
      keys.add('${m.group(1)}.$i');
    }
  }
  return keys;
}

class _PlBlock {
  _PlBlock(this.number, this.pos, this.gender, this.forms);
  final int number;
  final String pos, gender, forms;
  final senses = <Sense>[];
  final keys = <String>[];
}

/// Parses a pl.wiktionary page: the section of the Polish language (heading
/// "słowo (język polski)"), with its pronunciation, parts of speech, senses,
/// examples, etymology, synonyms and antonyms. Null when the page has no
/// Polish section.
WordInfo? parsePolish(
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
  final blocks = <_PlBlock>[];
  final examples = <String, List<Example>>{};
  final syn = <String>[], ant = <String>[];
  var etymology = '';
  var inPl = false, found = false;
  var mode = '';

  void addNym(List<String> into, Element dd) {
    final copy = without(dd, 'sup,style,link,i,.short-container');
    for (final a in copy.querySelectorAll('a')) {
      final href = a.attributes['href'] ?? '';
      if (!href.startsWith('/wiki/') && !href.contains('redlink=1')) continue;
      if (href.contains('Kategoria:') || href.contains('Aneks:')) continue;
      final t = squash(a.text);
      if (t.isNotEmpty && !into.contains(t)) into.add(t);
    }
  }

  for (final node in top.children) {
    final h = node.querySelector('h2');
    if (node.classes.contains('mw-heading') && h != null) {
      final isPl = h.querySelector('span.lang-code-pl') != null;
      if (inPl && !isPl) break;
      inPl = isPl;
      found = found || isPl;
      mode = '';
      continue;
    }
    if (!inPl) continue;

    if (node.localName == 'p' && mode == 'znaczenia') {
      // "rzeczownik, rodzaj żeński" / "czasownik przechodni niedokonany (dk. x)"
      final line = squash(without(node, 'sup,style').text);
      final comma = line.indexOf(',');
      var pos = line, rest = '';
      if (comma > 0) {
        pos = line.substring(0, comma);
        rest = line.substring(comma + 1).trim();
      } else {
        final sp = line.indexOf(' ');
        if (sp > 0) {
          pos = line.substring(0, sp);
          rest = line.substring(sp + 1).trim();
        }
      }
      var gender = '';
      final g = RegExp(r'^rodzaj\s+(\S+)').firstMatch(rest);
      if (g != null) {
        gender = _plGender[g.group(1)] ?? g.group(1)!;
        rest = rest.substring(g.end).replaceFirst(RegExp(r'^[,\s]+'), '');
      }
      blocks.add(_PlBlock(blocks.length + 1, pos, gender, rest));
      continue;
    }
    if (node.localName != 'dl') continue;

    final field = node.querySelector('dt span.field')?.attributes['data-field'];
    if (field != null) {
      mode = field;
    } else if (mode != 'znaczenia') {
      continue;
    }
    final dds = [
      for (final d in node.children)
        if (d.localName == 'dd') d,
    ];

    if (mode == 'wymowa' && field != null) {
      for (final e in node.querySelectorAll('span.ipa')) {
        // the line reads "IPA: [..], AS: [..]": only the first is the IPA
        Element? label;
        for (var p = e.previousElementSibling; p != null; p = p.previousElementSibling) {
          if (p.localName == 'a') {
            label = p;
            break;
          }
        }
        if (label == null || squash(label.text) != 'IPA') continue;
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
    } else if (mode == 'znaczenia' && field == null && blocks.isNotEmpty) {
      final b = blocks.last;
      for (final dd in dds) {
        final copy = without(dd, 'sup,style,link,ul,ol,dl,div');
        final first = copy.nodes.firstOrNull;
        if (first is! Text) continue;
        final m = _plNumber.firstMatch(first.text);
        if (m == null) continue;
        final keys = plSenseKeys(m.group(1)!);
        first.text = first.text.substring(m.end);
        // the labels lead the sense: "pot.", "przen.", "kulin."
        final labels = <String>[];
        for (final n in copy.nodes.toList()) {
          if (n is Text) {
            if (n.text.trim().isEmpty) continue;
            break;
          }
          if (n is! Element || !n.classes.contains('short-container')) break;
          final w = n.querySelector('.short-wrapper');
          final l = squash(w?.attributes['data-expanded'] ?? n.text);
          if (l.isNotEmpty) labels.add(l.toLowerCase());
          n.remove();
        }
        final t = squash(copy.text);
        if (t.isEmpty || b.senses.length >= maxDefs + 6) continue;
        b.senses.add(Sense(t, labels: labels));
        b.keys.add(keys.isEmpty ? '' : keys.first);
      }
    } else if (mode == 'przyklady') {
      for (final dd in dds) {
        final copy = without(dd, 'sup,style,link');
        final m = _plNumber.firstMatch(squash(copy.text));
        if (m == null) continue;
        var text = squash(copy.text).substring(m.end);
        var tr = '';
        final arrow = text.indexOf('→');
        if (arrow > 0) {
          tr = text.substring(arrow + 1).trim();
          text = text.substring(0, arrow).trim();
        }
        if (text.isEmpty) continue;
        for (final k in plSenseKeys(m.group(1)!)) {
          (examples[k] ??= []).add(Example(text, tr));
        }
      }
    } else if (mode == 'synonimy' || mode == 'antonimy') {
      for (final dd in dds) {
        addNym(mode == 'synonimy' ? syn : ant, dd);
      }
    } else if (mode == 'etymologia' && etymology.isEmpty) {
      for (final dd in dds) {
        final copy = without(dd, 'sup,style,link');
        var t = squash(copy.text);
        t = t.replaceFirst(_plNumber, '').replaceAll(RegExp(r'\s*\[\s*\d+\s*\]'), '');
        t = t.replaceAll(' ,', ',').replaceAll(' .', '.').replaceAll('( ', '(').replaceAll(' )', ')');
        if (t.isNotEmpty) {
          etymology = shorten(t, 220);
          break;
        }
      }
    }
  }

  if (!found) return null;
  final out = <PosBlock>[];
  for (final b in blocks) {
    if (b.senses.isEmpty || out.length >= maxBlocks) continue;
    final p = PosBlock(b.pos, gender: b.gender, forms: b.forms);
    for (var i = 0; i < b.senses.length && p.senses.length < maxDefs; i++) {
      final s = b.senses[i];
      final ex = examples[b.keys[i]] ?? const <Example>[];
      p.senses.add(
        Sense(s.text, labels: s.labels, examples: ex.take(maxExamples).toList()),
      );
    }
    out.add(p);
  }
  return WordInfo(
    url: url,
    ipa: ipa,
    audio: audio,
    blocks: out,
    synonyms: syn.take(maxNyms).toList(),
    antonyms: ant.take(maxNyms).toList(),
    etymology: etymology,
  );
}
