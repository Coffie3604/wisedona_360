import 'package:flutter_test/flutter_test.dart';

import 'package:wisedona_360/features/auth/auth_screens.dart';
import 'package:wisedona_360/main.dart';

void main() {
  testWidgets('app boots to the splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const WisedonaApp());
    await tester.pump();

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('Wisedona'), findsOneWidget);

    // Let the splash timer fire and settle on the login screen.
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
