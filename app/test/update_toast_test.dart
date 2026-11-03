import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexodle/main.dart';
import 'package:lexodle/update_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> open(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      scaffoldMessengerKey: appMessengerKey,
      home: const Scaffold(body: SizedBox()),
    ),
  );

  testWidgets('the toast names the version and has an underlined link', (
    tester,
  ) async {
    await open(tester);
    showUpdateToast('9.9.9');
    await tester.pump();
    expect(find.byKey(const ValueKey('update-toast')), findsOneWidget);
    final text = tester.widget<Text>(
      find.byKey(const ValueKey('update-toast-text')),
    );
    final root = text.textSpan! as TextSpan;
    final spans = root.children!.cast<TextSpan>();
    expect(spans.first.text, contains('9.9.9'));
    final link = spans.last;
    expect(link.text, 'download it');
    expect(link.style!.decoration, TextDecoration.underline);
    expect(link.recognizer, isA<TapGestureRecognizer>());
    expect(spans.first.style?.decoration, isNull, reason: 'only the link');
  });

  testWidgets('the toast stays long enough to be tapped, with a close', (
    tester,
  ) async {
    await open(tester);
    showUpdateToast('9.9.9');
    await tester.pump();
    final bar = tester.widget<SnackBar>(
      find.byKey(const ValueKey('update-toast')),
    );
    expect(bar.duration, greaterThanOrEqualTo(const Duration(seconds: 10)));
    expect(bar.showCloseIcon, isTrue);
  });

  testWidgets('a toast with no screen to show on does nothing', (tester) async {
    showUpdateToast('9.9.9');
    await tester.pump();
    expect(find.byType(SnackBar), findsNothing);
  });
}
