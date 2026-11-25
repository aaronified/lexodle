import 'package:flutter/material.dart';

import 'app_log.dart';
import 'collection.dart';
import 'save_word_button.dart';
import 'ui.dart';
import 'ui_kit.dart';
import 'word_info.dart';
import 'words.dart';

/// A collected word, with its entry fetched as it is looked at. The bookmark
/// in the header keeps a copy of the entry in the personal dictionary.
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
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<Language?>(
          future: _language,
          builder: (context, snap) {
            final done = snap.connectionState == ConnectionState.done;
            final language = done ? snap.data : null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeader(
                  title: const SizedBox.shrink(),
                  back: true,
                  settings: false,
                  actions: [
                    if (language != null)
                      SaveWordButton(word: widget.ref.word, language: language),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: _body(context, done, language),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _body(BuildContext context, bool done, Language? language) {
    if (!done) return const SizedBox.shrink();
    if (language == null) {
      return const Center(child: Caption('this language could not be loaded'));
    }
    final c = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Text(
          widget.ref.word,
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            height: 1.1,
            color: c.primary,
          ),
        ),
        const SizedBox(height: 10),
        const Caption(
          'collected · the entry is looked up as you read it. tap the bookmark to keep a copy that opens without a connection.',
        ),
        const SizedBox(height: 12),
        WordInfoView(word: widget.ref.word, language: language),
      ],
    );
  }
}
