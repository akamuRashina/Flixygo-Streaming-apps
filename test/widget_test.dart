import 'package:flutter_test/flutter_test.dart';
import 'package:flixygo/main.dart';
import 'package:flixygo/pages/login_page.dart';

void main() {
  testWidgets('FlixyGoApp launches and displays LoginPage', (WidgetTester tester) async {
    await tester.pumpWidget(const FlixyGoApp());
    expect(find.byType(LoginPage), findsOneWidget);
  });
}
