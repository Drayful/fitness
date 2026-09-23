import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fitness_app/main.dart';
import 'package:fitness_app/app/screens/login_screen.dart';
import 'package:fitness_app/app/screens/dashboard_screen.dart';

void main() {
  testWidgets('Authenticated dashboard has no demo readiness or HRV', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'auth_token': 'test',
      'auth_user_name': 'Tester',
    });
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.pumpWidget(const FitnessApp());
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.text('Tester'), findsOneWidget);
    expect(find.text('72'), findsNothing);
    expect(find.text('78'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.show_chart));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.fitness_center));
    await tester.pumpAndSettle();
    expect(
      find.text('В этой сессии пока нет записанных тренировок.'),
      findsOneWidget,
    );
    expect(find.textContaining('14–16'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    expect(find.textContaining('2024'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Opens login without a session', (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.pumpWidget(const FitnessApp());
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
