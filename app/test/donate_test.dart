import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/donate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the link names the payee, in rupees, with no amount', () {
    expect(upiId, 'das.arani@pingpay');
    expect(upiLink.scheme, 'upi');
    expect(upiLink.host, 'pay');
    expect(upiLink.queryParameters['pa'], upiId);
    expect(upiLink.queryParameters['pn'], 'Arani Das');
    expect(upiLink.queryParameters['cu'], 'INR');
    expect(upiLink.queryParameters.containsKey('am'), isFalse);
  });

  test('the bundled QR code is there, and declared', () {
    final svg = File('assets/donate/upi-qr.svg').readAsStringSync();
    expect(svg, contains('<svg'));
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('- assets/donate/'),
    );
    // the generator says what it encodes, and agrees with the app
    final py = File('tools/make_donate_qr.py').readAsStringSync();
    expect(py, contains('UPI_ID = "$upiId"'));
    expect(py, contains('NAME = "$upiName"'));
  });

  Future<void> show(
    WidgetTester tester, {
    Future<bool> Function(Uri)? open,
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: DonateSection(open: open)),
        ),
      ),
    );
    // SVG assets are read with real file IO
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pump();
  }

  testWidgets('shows the QR code and the UPI ID', (tester) async {
    await show(tester);
    expect(find.byKey(const ValueKey('donate-qr')), findsOneWidget);
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.text(upiId), findsOneWidget);
    expect(find.text(upiName), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('copy puts the UPI ID on the clipboard', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await show(tester);
    await tester.tap(find.byKey(const ValueKey('donate-copy')));
    await tester.pump();
    expect(copied, upiId);
    expect(find.text('copied $upiId'), findsOneWidget);
  });

  testWidgets('the button hands the UPI link to the phone', (tester) async {
    Uri? opened;
    await show(
      tester,
      open: (u) async {
        opened = u;
        return true;
      },
    );
    await tester.tap(find.byKey(const ValueKey('donate-pay')));
    await tester.pump();
    expect(opened, upiLink);
    expect(find.byKey(const ValueKey('donate-note')), findsNothing);
  });

  testWidgets('with no UPI app it says what to do instead', (tester) async {
    await show(tester, open: (_) async => false);
    await tester.tap(find.byKey(const ValueKey('donate-pay')));
    await tester.pump();
    expect(find.textContaining('no UPI app opened'), findsOneWidget);
  });
}
