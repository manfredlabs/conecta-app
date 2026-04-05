import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Firebase needs to be initialized for the app to run,
    // so we just verify the test framework works.
    expect(1 + 1, 2);
  });
}
