import 'package:html/dom.dart' show Element, Node, Text;

/// Small helpers shared by the parsers of the Nordic and Dutch editions
/// (de, nl, sv, da, nb). Pure string and DOM work, nothing that can fail.

String squash(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

String shorten(String s, int max) {
  if (s.length <= max) return s;
  final cut = s.substring(0, max);
  final end = cut.lastIndexOf(RegExp(r'[.;,] '));
  return '${(end > max ~/ 2 ? cut.substring(0, end) : cut.trimRight())}…';
}

/// A copy of [node] without the given selectors (footnote marks, styles...).
Element without(Element node, String selectors) {
  final copy = node.clone(true);
  for (final x in copy.querySelectorAll(selectors)) {
    x.remove();
  }
  return copy;
}

/// The leading text of [node] up to its first element.
String leadingText(Node node) {
  final b = StringBuffer();
  for (final n in node.nodes) {
    if (n is! Text) break;
    b.write(n.text);
  }
  return b.toString();
}

/// A protocol-relative link made absolute.
String absUrl(String src) => src.startsWith('//') ? 'https:$src' : src;

/// The commons recording as an mp3: Wikimedia serves every .ogg as
/// `transcoded/<a>/<ab>/<name>.ogg/<name>.ogg.mp3`, which every player reads.
String? commonsMp3(String? href) {
  if (href == null) return null;
  final m = RegExp(
    r'^(?:https:)?//upload\.wikimedia\.org/wikipedia/commons/(\w/\w\w)/([^/?]+\.(?:ogg|oga|wav|flac))(?:\?.*)?$',
    caseSensitive: false,
  ).firstMatch(href);
  if (m == null) return null;
  final name = m.group(2)!;
  return 'https://upload.wikimedia.org/wikipedia/commons/transcoded/'
      '${m.group(1)}/$name/$name.mp3';
}
