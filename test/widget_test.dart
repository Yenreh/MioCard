import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miocard/main.dart';

void main() {
  testWidgets('App loads correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MIOCardApp()),
    );
    await tester.pumpAndSettle();

    // Verify that app title is shown
    expect(find.text('MIOCard'), findsOneWidget);
  });
}
