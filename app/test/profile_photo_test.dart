import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/profile.dart';
import 'package:lexodle/profile_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

// A 1x1 png.
const _png = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0,
  0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00,
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

Future<void> _open(
  WidgetTester tester,
  ProfilePhotoPicker pick, {
  bool supported = true,
  Future<Directory> Function()? docs,
}) async {
  await tester.binding.setSurfaceSize(const Size(420, 1700));
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showProfileSheet(
            context,
            pick: pick,
            photoSupported: supported,
            docsDir: docs ?? () async => Directory.systemTemp,
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'seenHowTo': true});
    await appState.load();
    appState.setProfile(Profile());
  });

  test('the photo path round trips', () {
    final p = Profile.fromJson(Profile(photo: '/a/b.jpg').toJson());
    expect(p.photo, '/a/b.jpg');
    expect(Profile.fromJson(Profile().toJson()).photo, isNull);
  });

  testWidgets('picking stores the photo, removing returns to the icon', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('profile_photo');
    final file = File('${dir.path}/profile.jpg')..writeAsBytesSync(_png);
    addTearDown(() => dir.deleteSync(recursive: true));
    final docs = Directory('${dir.path}/docs')..createSync();
    await _open(tester, () async => file.path, docs: () async => docs);
    expect(find.byKey(const ValueKey('profile-photo-remove')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('profile-photo-choose')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    final kept = '${docs.path}/profile.jpg';
    expect(appState.profile.photo, kept);
    file.deleteSync();
    expect(File(kept).existsSync(), isTrue);
    expect(find.byKey(const ValueKey('profile-photo-remove')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profile-photo-remove')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(appState.profile.photo, isNull);
    expect(File(kept).existsSync(), isFalse);
    expect(find.byKey(const ValueKey('profile-photo')), findsNothing);
  });

  testWidgets('a missing file falls back to the icon', (tester) async {
    appState.setProfile(Profile(photo: '/nope/profile.jpg'));
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ProfileAvatar(appState.profile))),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failing or cancelled picker changes nothing', (tester) async {
    await _open(tester, () async => throw StateError('x'));
    await tester.tap(find.byKey(const ValueKey('profile-photo-choose')));
    await tester.pumpAndSettle();
    expect(appState.profile.photo, isNull);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    await _open(tester, () async => null);
    await tester.tap(find.byKey(const ValueKey('profile-photo-choose')));
    await tester.pumpAndSettle();
    expect(appState.profile.photo, isNull);
  });

  testWidgets('the button is hidden where photos are not supported', (
    tester,
  ) async {
    await _open(tester, () async => null, supported: false);
    expect(find.byKey(const ValueKey('profile-photo-choose')), findsNothing);
  });
}
