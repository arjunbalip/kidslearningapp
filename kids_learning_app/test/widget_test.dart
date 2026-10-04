import 'package:flutter_test/flutter_test.dart';

import 'package:kids_learning_app/app/app.dart';

void main() {
  testWidgets('Home shows the Letters and Numbers worlds', (tester) async {
    await tester.pumpWidget(const KidsApp());
    await tester.pumpAndSettle();

    expect(find.text('Letters'), findsOneWidget);
    expect(find.text('Numbers'), findsOneWidget);
  });
}
