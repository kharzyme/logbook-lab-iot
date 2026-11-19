import 'package:flutter_test/flutter_test.dart';
import 'package:blockchain_app/main.dart';

void main() {
  testWidgets('Smoke test LogbookLabApp', (WidgetTester tester) async {
    await tester.pumpWidget(const LogbookLabApp());
  });
}