import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wisedona_360/core/data/app_repository.dart';
import 'package:wisedona_360/core/data/app_scope.dart';
import 'package:wisedona_360/features/auth/auth_screens.dart';
import 'package:wisedona_360/features/wallet/wallet_screen.dart';
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

  testWidgets('wallet Pay button opens the pay sheet', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repo = AppRepository();

    await tester.pumpWidget(
      AppScope(
        repository: repo,
        child: const MaterialApp(home: WalletScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pay'), findsOneWidget);
    await tester.tap(find.text('Pay'));
    await tester.pumpAndSettle();

    expect(find.text('Pay with Wisedona'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });
}
