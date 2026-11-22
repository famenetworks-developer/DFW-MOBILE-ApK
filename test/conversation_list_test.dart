import 'package:dfw_communication/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('conversation rows stay bounded and the complete list scrolls', (
    tester,
  ) async {
    final rows = List.generate(
      20,
      (index) => <String, dynamic>{
        'id': 'conversation-$index',
        'contact': <String, dynamic>{'profile_name': 'Contact $index'},
        'last_message': <String, dynamic>{'body': 'Message $index'},
        'unread_message_count': 0,
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 600,
            child: ConversationList(rows: rows, onOpen: (_) {}),
          ),
        ),
      ),
    );

    expect(find.text('Contact 0'), findsOneWidget);
    expect(
      tester
          .getSize(
            find.ancestor(
              of: find.text('Contact 0'),
              matching: find.byType(DecoratedBox),
            ),
          )
          .height,
      81,
    );

    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();

    expect(find.text('Contact 19'), findsOneWidget);
  });
}
