import 'package:flutter/material.dart';

import 'app_log.dart';
import 'collection.dart';
import 'save_word_button.dart';
import 'ui.dart';
import 'word_info.dart';
import 'words.dart';

/// A collected word, with its entry fetched as it is looked at. The bookmark
/// keeps a copy of the entry in the personal dictionary.
class CollectedWordPage extends StatefulWidget {
  const CollectedWordPage({super.key, required this.ref});
  final CollectedRef ref;

  @override
  State<CollectedWordPage> createState() => _CollectedWordPageState();
}

class _CollectedWordPageState extends State<CollectedWordPage> {
  late final Future<Language?> _language = _resolveLanguage();

  /// The language of the word, or null (logged) when it cannot be found.
  Future<Language?> _resolveLanguage() async {
    try {
      final langs = await WordBank.languages();
      for (final l in langs) {
        if (l.code == widget.ref.lang) return l;
      }
      appLog.w('collected', 'no language for a collected word');
      return null;
    } catch (e) {
      appLog.w('collected', 'languages could not be loaded: ${e.runtimeType}');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            languageBadge(widget.ref.lang, size: 16),
            const SizedBox(width: 8),
            const Text('my words'),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: FutureBuilder<Language?>(
            future: _language,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const SizedBox.shrink();
              }
              final language = snap.data;
              if (language == null) {
                return const Center(
                  child: Caption('this language could not be loaded'),
                );
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(19, 4, 19, 32),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.ref.word,
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: c.primary,
                          ),
                        ),
                      ),
                      SaveWordButton(word: widget.ref.word, language: language),
                    ],
                  ),
                  const Caption(
                    'collected · the entry is looked up as you read it. tap the bookmark to keep a copy that opens without a connection.',
                  ),
                  const SizedBox(height: 12),
                  WordInfoView(word: widget.ref.word, language: language),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
