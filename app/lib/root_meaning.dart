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
    required this.language,
    this.lookup,
  });
  final String root;
  final String pos;
  final Language language;

  /// Replaces the Wiktionary lookup, for a test.
  final Future<WordInfo?> Function(String root)? lookup;

  @override
  State<RootSenses> createState() => _RootSensesState();
}

class _RootSensesState extends State<RootSenses> {
  late final Future<WordInfo?> _future = _look();

  Future<WordInfo?> _look() async {
    try {
      final custom = widget.lookup;
      if (custom != null) return await custom(widget.root);
      return await Wiktionary.shared.lookup(
        widget.root,
        widget.language.code,
        widget.language.wikt,
      );
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
