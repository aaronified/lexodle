import 'package:flutter/material.dart';

import 'app_log.dart';
import 'main.dart';
import 'ui.dart';
import 'wiktionary.dart';
import 'words.dart';

/// The bookmark on an end screen: saves the answer word to the personal
/// dictionary with its Wiktionary entry, or removes it again.
class SaveWordButton extends StatefulWidget {
  const SaveWordButton({super.key, required this.word, required this.language});
  final String word;
  final Language language;

  @override
  State<SaveWordButton> createState() => _SaveWordButtonState();
}

class _SaveWordButtonState extends State<SaveWordButton> {
  bool _pending = false;

  void _snack(String text) {
    try {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(text)));
    } catch (e) {
      appLog.w('saveword', 'could not show a message: ${e.runtimeType}');
    }
  }

  Future<void> _tap() async {
    if (_pending) return;
    final code = widget.language.code;
    final word = widget.word;
    try {
      if (appState.isWordSaved(code, word)) {
        appState.unsaveWord(code, word);
        _snack('removed from my words');
        return;
      }
    } catch (e) {
      appLog.w('saveword', 'could not remove a saved word: ${e.runtimeType}');
      return;
    }
    setState(() => _pending = true);
    try {
      WordInfo? info;
      try {
        info = await Wiktionary.shared
            .lookup(word, code, widget.language.wikt)
            .timeout(const Duration(seconds: 12));
      } catch (e) {
        appLog.w(
          'saveword',
          'lookup failed, saving without its entry: ${e.runtimeType}',
        );
        info = null;
      }
      if (info != null && info.isEmpty) info = null;
      appState.saveWord(code, word, info);
      if (!mounted) return;
      _snack('saved to my words');
    } catch (e) {
      appLog.w('saveword', 'could not save a word: ${e.runtimeType}');
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final saved = appState.isWordSaved(widget.language.code, widget.word);
        return IconButton(
          key: const ValueKey('save-word'),
          tooltip: saved ? 'remove from my words' : 'save to my words',
          icon: TablerIcon(
            saved ? 'bookmark-filled' : 'bookmark',
            size: 24,
            color: Theme.of(context).colorScheme.primary,
          ),
          onPressed: _tap,
        );
      },
    );
  }
}
