import 'package:flutter/material.dart';

import 'app_log.dart';
import 'ui.dart';
import 'words.dart';
import 'wiktionary.dart';

/// The words an inflected form is a form of, read from its senses ("plural of
/// deke", "third-person singular simple present indicative of deke", "simple
/// past of run"): the word at the end, once per word, in the order of the
/// senses. English wording only; a sense that is not a form of a word, or the
/// form of the word itself, gives none.
List<String> rootsOf(WordInfo info, String word) {
  final out = <String>[];
  final seen = <String>{word.toLowerCase()};
  for (final b in info.blocks) {
    for (final s in b.senses) {
      final m = _formOf.firstMatch(s.text.trim());
      if (m == null) continue;
      final root = m[1]!.replaceAll(RegExp(r'^[("“]+|[)"”.,;:]+$'), '');
      if (root.isEmpty || !seen.add(root.toLowerCase())) continue;
      out.add(root);
    }
  }
  return out;
}

final _formOf = RegExp(
  r'^(?:the )?(?:plural|third-person|first-person|second-person|simple past|'
  r'past|present participle|past participle|comparative|superlative|gerund|'
  r'alternative|obsolete|archaic|dated|nonstandard|informal|misspelling|'
  r'diminutive|augmentative)\b.*?\s+of\s+(\S+?)\.?$',
  caseSensitive: false,
);

/// The meaning of the root word of an inflected answer: for each root, its
/// parts of speech with their first senses. A root without an entry, or one
/// that cannot be fetched, is left out and the failure is logged.
class RootMeaning extends StatelessWidget {
  const RootMeaning({super.key, required this.roots, required this.language});
  final List<String> roots;
  final Language language;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final r in roots.take(2)) _Root(root: r, language: language),
    ],
  );
}

class _Root extends StatefulWidget {
  const _Root({required this.root, required this.language});
  final String root;
  final Language language;

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  late final Future<WordInfo?> _future = _look();

  Future<WordInfo?> _look() async {
    try {
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
    final dim = c.onSurface.withValues(alpha: dimAlpha);
    return FutureBuilder<WordInfo?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'looking up ${widget.root}…',
              style: TextStyle(fontSize: 12, color: dim),
            ),
          );
        }
        final info = snap.data;
        if (info == null || info.blocks.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Column(
            key: ValueKey('root-${widget.root}'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'the root  ',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 2,
                        color: dim,
                      ),
                    ),
                    TextSpan(
                      text: widget.root,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: c.primary,
                      ),
                    ),
                  ],
                ),
              ),
              for (final b in info.blocks.take(3)) ...[
                const SizedBox(height: 8),
                Text(
                  b.pos,
                  style: TextStyle(
                    fontSize: 12,
                    color: c.primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                for (var i = 0; i < b.senses.length && i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${i + 1}  ',
                            style: TextStyle(
                              color: c.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (b.senses[i].labels.isNotEmpty)
                            TextSpan(
                              text: '${b.senses[i].labels.join(', ')}  ',
                              style: TextStyle(
                                color: yellowOf(c),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          TextSpan(text: b.senses[i].text),
                        ],
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}
