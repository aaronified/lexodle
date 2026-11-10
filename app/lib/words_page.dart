import 'package:flutter/material.dart';

/// "my words": the personal dictionary (a stub for now).
class WordsPage extends StatelessWidget {
  const WordsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('my words')),
    body: const SizedBox.shrink(),
  );
}
