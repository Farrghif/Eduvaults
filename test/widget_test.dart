// Basic smoke test for EduVaults app
import 'package:flutter_test/flutter_test.dart';
import 'package:eduvaults/main.dart';

void main() {
  testWidgets('App should render login screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const EduVaultsApp(initialRoute: '/login'));
    await tester.pumpAndSettle();

    // Verify the login screen is shown
    expect(find.text('Welcome to EduVaults'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
