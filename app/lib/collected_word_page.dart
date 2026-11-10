import 'package:flutter/material.dart';

import 'collection.dart';

/// A collected word, with its entry fetched as it is looked at (a stub for now).
class CollectedWordPage extends StatelessWidget {
  const CollectedWordPage({super.key, required this.ref});
  final CollectedRef ref;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('my words')),
    body: const SizedBox.shrink(),
  );
}
