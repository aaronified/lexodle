import 'package:flutter/material.dart';

import 'saved_words.dart';

/// One saved word with its entry and note (a stub for now).
class WordPage extends StatelessWidget {
  const WordPage({super.key, required this.entry});
  final SavedWord entry;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('my words')),
    body: const SizedBox.shrink(),
  );
}
