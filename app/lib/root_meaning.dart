import 'package:flutter/material.dart';

import 'app_log.dart';
import 'ui.dart';
import 'words.dart';
import 'wiktionary.dart';

/// The word an inflected form is a form of, read from its sense ("plural of
/// deke", "third-person singular simple present indicative of deke", "simple
/// past of run"): the word at the end. English wording only; a sense that is
/// not a form of a word, or the form of the word itself, gives null.
String? rootOfSense(String sense, String word) {
  final m = _formOf.firstMatch(sense.trim());
  if (m == null) return null;
  final root = m[1]!.replaceAll(RegExp(r'^[("“]+|[)"”.,;:]+$'), '');
  return root.isEmpty || root.toLowerCase() == word.toLowerCase() ? null : root;
}

final _formOf = RegExp(
  r'^(?:the )?(?:plural|third-person|first-person|second-person|simple past|'
  r'past|present participle|past participle|comparative|superlative|gerund|'
  r'alternative|obsolete|archaic|dated|nonstandard|informal|misspelling|'
  r'diminutive|augmentative)\b.*?\s+of\s+(\S+?)\.?$',
  caseSensitive: false,
);

/// The root words the senses of [info] name ("plural of gove" names gove), in
/// order, without repeats.
List<String> rootsOf(WordInfo info, String word) {
  final out = <String>[];
  for (final b in info.blocks) {
    for (final s in b.senses) {
      final r = rootOfSense(s.text, word);
      if (r != null && !out.contains(r)) out.add(r);
    }
  }
  return out;
}

/// Whether [info] names root words it does not hold the entries of yet.
bool missingRoots(WordInfo info, String word) =>
    rootsOf(info, word).any((r) => !info.roots.containsKey(r));

/// [info] with the entries of its root words looked up and kept with it (at
/// most three, each in the word's own language), so a saved word shows what the
/// root means without a connection. A root that cannot be had is left out and
/// logged (only its type); [info] is returned as it was when there is nothing
/// to add. [lookup] replaces the Wiktionary lookup, for a test.
Future<WordInfo> withRoots(
  WordInfo info,
  String word,
  Language language, {
  Future<WordInfo?> Function(String root)? lookup,
}) async {
  final found = <String, WordInfo>{...info.roots};
  try {
    for (final root in rootsOf(info, word).take(3)) {
      if (found.containsKey(root)) continue;
      try {
        final r = lookup != null
            ? await lookup(root)
            : await Wiktionary.shared
                  .lookup(root, language.code, language.wikt)
                  .timeout(const Duration(seconds: 12));
        if (r != null && !r.isEmpty) found[root] = r;
      } catch (e) {
        appLog.w('word', 'could not look up a root word: ${e.runtimeType}');
      }
    }
  } catch (e) {
    appLog.w('word', 'roots failed: ${e.runtimeType}');
  }
  return found.length == info.roots.length ? info : info.withRoots(found);
}

/// What the root of an inflected form means, set under the sense that names it
/// ("plural of deke"): the root's senses of the same part of speech as the form
/// (a plural noun's root as a noun), or its first part of speech when it has
/// none of that kind. Nothing while it loads or when there is no entry; a
/// failure is logged. It is drawn dim, under the sense, with no edge.
class RootSenses extends StatefulWidget {
  const RootSenses({
    super.key,
    required this.root,
    required this.pos,
    this.language,
    this.lookup,
    this.known,
  });
  final String root;
  final String pos;

  /// The language to look the root up in; not needed with [known].
  final Language? language;

  /// Replaces the Wiktionary lookup, for a test.
  final Future<WordInfo?> Function(String root)? lookup;

  /// The root's entry already in hand (kept with a saved word): shown at once,
  /// with no lookup.
  final WordInfo? known;

  @override
  State<RootSenses> createState() => _RootSensesState();
}

class _RootSensesState extends State<RootSenses> {
  late final Future<WordInfo?> _future = _look();

  Future<WordInfo?> _look() async {
    try {
      if (widget.known != null) return widget.known;
      final custom = widget.lookup;
      if (custom != null) return await custom(widget.root);
      final lang = widget.language;
      if (lang == null) return null;
      return await Wiktionary.shared.lookup(widget.root, lang.code, lang.wikt);
    } catch (e) {
      appLog.w('word', 'could not look up the root word: ${e.runtimeType}');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final dim = c.onSurfaceVariant;
    return FutureBuilder<WordInfo?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'looking up ${widget.root}…',
              style: TextStyle(fontSize: 13, color: dim),
            ),
          );
        }
        final info = snap.data;
        if (info == null || info.blocks.isEmpty) return const SizedBox.shrink();
        final same = info.blocks.where((b) => b.pos == widget.pos).toList();
        final blocks = same.isEmpty ? [info.blocks.first] : same;
        final senses = [for (final b in blocks) ...b.senses].take(3).toList();
        if (senses.isEmpty) return const SizedBox.shrink();
        return Padding(
          key: ValueKey('root-${widget.root}'),
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.root,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: dim,
                ),
              ),
              for (var i = 0; i < senses.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${i + 1}  ',
                          style: TextStyle(
                            color: dim,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (senses[i].labels.isNotEmpty)
                          TextSpan(
                            text: '${senses[i].labels.join(', ')}  ',
                            style: TextStyle(
                              color: yellowOf(c),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        TextSpan(text: senses[i].text),
                      ],
                    ),
                    style: TextStyle(fontSize: 13, color: dim),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
