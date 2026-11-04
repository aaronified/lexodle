import 'dart:typed_data';

import 'precomputed.dart';

/// The web keeps nothing on a disk: it reads the published files as it needs
/// them.
class PrecomputedLocal {
  const PrecomputedLocal._();

  static bool get supported => false;
  static Uint8List? readOpening(String name) => null;
  static String? readTree(String name) => null;
  static Map<String, String> downloaded() => {};
  static int size() => 0;
  static Future<bool> download(
    PrecomputedManifest manifest,
    Iterable<String> lists, {
    void Function(double done)? onProgress,
  }) async => false;
  static void remove() {}
}
