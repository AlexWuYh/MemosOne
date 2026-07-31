import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memos_one/app/app.dart';

void main() {
  testWidgets('app boots and shows scaffold home', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MemosOneApp(),
      ),
    );

    expect(find.text('Memos One'), findsOneWidget);
    expect(
      find.text('One Client. Every Device. Your Memos.'),
      findsOneWidget,
    );
  });
}
