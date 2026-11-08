import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vecinal/features/emergencias/presentation/emergency_dashboard_page.dart';
import 'package:vecinal/l10n/app_localizations.dart';

import '../../../tool/phone_practice.dart' as rehearsal;

void main() {
  testWidgets('el ensayo abre práctica sin ingreso y permite entrar al tablero real', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final t = await AppLocalizations.delegate.load(const Locale('es'));
    await rehearsal.main();
    await tester.pumpAndSettle();
    expect(find.text(t.practiceMode), findsWidgets);
    expect(find.byType(TextFormField), findsNothing);
    expect((await SharedPreferences.getInstance()).getBool('practiceMode'), isTrue);
    final emergency = find.widgetWithText(FilledButton, t.activateLocalEmergency);
    await tester.ensureVisible(emergency);
    await tester.tap(emergency);
    await tester.pumpAndSettle();
    expect(find.byType(EmergencyDashboardPage), findsOneWidget);
    expect(find.text(t.emergencyPracticeHelp), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
