import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:loonbox/app.dart';

void main() {
  testWidgets('LoonBox app renders', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: LoonBoxApp()));
    expect(find.text('LoonBox — Phase 1 Foundation'), findsOneWidget);
  });
}
