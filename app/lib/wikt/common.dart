import 'package:html/dom.dart' show Element;

/// Small helpers shared by the parsers of the other Wiktionary editions.

String squash(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

String shorten(String s, int max) {
  if (s.length <= max) return s;
  final cut = s.substring(0, max);
  final end = cut.lastIndexOf(RegExp(r'[.;,] '));
  return '${(end > max ~/ 2 ? cut.substring(0, end) : cut.trimRight())}…';
}

/// A copy of [e] without footnote marks, styles and images, for plain text.
Element plainCopy(Element e, [String extra = '']) {
  final c = e.clone(true);
  for (final x in c.querySelectorAll(
    'sup,style,img,script${extra.isEmpty ? '' : ',$extra'}',
  )) {
    x.remove();
  }
  return c;
}

/// Adds the words of a synonym or antonym line ("mezzo, mezza parte") to
/// [into]: split on commas and semicolons, notes in brackets dropped.
void addNyms(List<String> into, String line) {
  for (var t in line.split(RegExp(r'[,;]'))) {
    t = squash(t.replaceAll(RegExp(r'\([^)]*\)'), ''));
    t = t.replaceAll(RegExp(r'[.…]+$'), '').trim();
    if (t.isEmpty || t.startsWith('véase') || into.contains(t)) continue;
    into.add(t);
  }
}

/// A protocol-relative upload link made absolute.
String absoluteUrl(String src) => src.startsWith('//') ? 'https:$src' : src;
