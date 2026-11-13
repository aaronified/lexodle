import 'package:html/dom.dart' show Element, Node, Text;

/// Small helpers shared by the parsers of the Wiktionary editions in this
/// folder. Pure string and DOM work, nothing that can fail.

String squash(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

String shorten(String s, int max) {
  if (s.length <= max) return s;
  final cut = s.substring(0, max);
  final end = cut.lastIndexOf(RegExp(r'[.;,] '));
  return '${(end > max ~/ 2 ? cut.substring(0, end) : cut.trimRight())}…';
}

/// A protocol-relative audio link made absolute.
String absUrl(String src) => src.startsWith('//') ? 'https:$src' : src;

/// A copy of [node] without the given selectors (footnote marks, styles...).
Element without(Element node, String selectors) {
  final copy = node.clone(true);
  for (final x in copy.querySelectorAll(selectors)) {
    x.remove();
  }
  return copy;
}

/// The leading text of [node] up to its first element, trimmed; used to read
/// a "(1.1)" sense number at the start of a line.
String leadingText(Node node) {
  final b = StringBuffer();
  for (final n in node.nodes) {
    if (n is! Text) break;
    b.write(n.text);
  }
  return b.toString();
}
