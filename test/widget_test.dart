import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nursaflow/main.dart';

void main() {
  testWidgets('App boots and shows onboarding', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: NursaFlowApp()));
    await tester.pumpAndSettle();

    // Onboarding screen's first-page headline should be visible on launch.
    expect(find.text('Master Nursing with AI.'), findsOneWidget);
  });
}