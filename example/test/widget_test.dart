import 'package:flutter_test/flutter_test.dart';
import 'package:wts_sdk_example/main.dart';

void main() {
  testWidgets('renders SDK status', (WidgetTester tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.text('No deep link'), findsOneWidget);
  });
}
