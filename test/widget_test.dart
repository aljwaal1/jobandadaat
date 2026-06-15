import 'package:flutter_test/flutter_test.dart';
import 'package:habits_tasks/main.dart';

void main() {
  testWidgets('Habits Tasks starts', (tester) async {
    await tester.pumpWidget(const HabitsTasksApp());
    expect(find.text('مهامي وعاداتي'), findsOneWidget);
  });
}
