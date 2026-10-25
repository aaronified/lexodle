import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The release build once shipped with the code shrinker on, which removed a
/// method the shared_preferences plugin needs: every save and load failed
/// quietly, so no progress survived a restart (debug builds do not shrink, so
/// nothing showed in development). This keeps the shrinker off until a release
/// build has been shown to save and read again with it on.
void main() {
  test('the release build does not shrink code', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final release = RegExp(
      r'release\s*\{([^}]*)\}',
      dotAll: true,
    ).firstMatch(gradle)!.group(1)!;
    expect(release, contains('isMinifyEnabled = false'));
    expect(release, contains('isShrinkResources = false'));
    expect(release, isNot(contains('proguardFiles')));
  });
}
