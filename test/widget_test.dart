import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pushup_tracker/main.dart';
import 'package:pushup_tracker/pushup_counter_controller.dart';

void main() {
  testWidgets('Smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => PushupCounterController()),
        ],
        child: const MaterialApp(
          home: AppEntry(),
        ),
      ),
    );

    // Verify that our app shows the error screen when no camera is present.
    expect(find.textContaining('No camera found'), findsOneWidget);
  });
}
