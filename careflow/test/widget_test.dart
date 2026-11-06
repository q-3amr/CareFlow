import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:careflow/main.dart';
import 'package:careflow/providers/chat_provider.dart';
import 'helpers/firebase_mock_helper.dart';

void main() {
  setUpAll(() {
    setupFirebaseMocks();
  });

  testWidgets('MyApp should build a MaterialApp', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ChatProvider>(
            create: (_) => ChatProvider(),
          ),
        ],
        child: const MyApp(),
      ),
    );

    // Pump once to let the widget settle without waiting for async Firebase calls
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
