import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vecinal/core/platform/device_services.dart';
import 'package:vecinal/features/emergencias/data/emergency_contacts.dart';
import 'package:vecinal/features/emergencias/data/emergency_providers.dart';
import 'package:vecinal/features/emergencias/domain/emergency.dart';
import 'package:vecinal/features/emergencias/presentation/emergency_contacts_page.dart';
import 'package:vecinal/l10n/app_localizations.dart';

const _zone = '01970000-0000-7000-8000-000000000001';
const _scope = EmergencyScope(accountId: 'cuenta', zoneId: _zone, practice: true);

/// The phone's own picker: it answers with a contact, with nothing (closed) or with an error.
class _Picker implements ContactPicker {
  _Picker(this._answer);
  final Future<PickedContact?> Function() _answer;
  var calls = 0;
  @override
  Future<PickedContact?> pick() {
    calls++;
    return _answer();
  }
}

void main() {
  late AppLocalizations t;
  setUpAll(() async => t = await AppLocalizations.delegate.load(const Locale('es')));

  group('EmergencyContact', () {
    test('deja los números como los escribe la gente o la agenda en solo dígitos', () {
      expect(EmergencyContact.normalizePhone(' +51 987-654 321 '), '+51987654321');
      expect(EmergencyContact.normalizePhone('(01) 555 4444'), '015554444');
      expect(EmergencyContact.normalizePhone('987 654 321'), '987654321');
    });

    test('los contactos guardados antes del parentesco y del alterno se siguen leyendo', () {
      final contact = EmergencyContact.fromJson({'id': 'a', 'name': 'Ana', 'phone': '987654321'});
      expect(contact.relationship, isNull);
      expect(contact.alternatePhone, isNull);
      expect(contact.valid, isTrue);
      expect(contact.toJson(), {'id': 'a', 'name': 'Ana', 'phone': '987654321'});
    });

    test('guarda el parentesco y el alterno, e ignora un parentesco desconocido', () {
      const contact = EmergencyContact(
        id: 'a',
        name: 'Ana',
        phone: '987654321',
        relationship: ContactRelationship.mother,
        alternatePhone: '015554444',
      );
      final read = EmergencyContact.fromJson(contact.toJson());
      expect(read.relationship, ContactRelationship.mother);
      expect(read.alternatePhone, '015554444');
      final unknown = EmergencyContact.fromJson({...contact.toJson(), 'relationship': 'vecino'});
      expect(unknown.relationship, isNull);
    });

    test('un teléfono alternativo inválido invalida el contacto', () {
      const contact = EmergencyContact(
        id: 'a',
        name: 'Ana',
        phone: '987654321',
        alternatePhone: '12',
      );
      expect(contact.valid, isFalse);
    });
  });

  Future<ProviderContainer> show(WidgetTester tester, {ContactPicker? picker}) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        emergencyScopeProvider.overrideWithValue(_scope),
        if (picker != null) contactPickerProvider.overrideWithValue(picker),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const EmergencyContactsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);
  List<EmergencyContact> saved(ProviderContainer container) =>
      container.read(emergencyContactsProvider).value!;

  testWidgets('en práctica el título se lee completo: el distintivo queda como ícono', (
    tester,
  ) async {
    await show(tester);
    final chip = find.widgetWithIcon(IconButton, Icons.science_outlined);
    expect(chip, findsOneWidget);
    expect(find.byTooltip(t.practiceChip), findsOneWidget);
    final title = tester.getRect(find.text(t.emergencyContactsTitle).first);
    expect(title.right, lessThanOrEqualTo(tester.getRect(chip).left));
    // One line of the title style, not squeezed into several.
    expect(title.height, lessThan(40));
  });

  testWidgets('guarda nombre y apellido, parentesco, teléfono principal y alternativo', (
    tester,
  ) async {
    final container = await show(tester);
    await tester.enterText(field(t.emergencyContactName), 'Ana Pérez');
    await tester.tap(find.widgetWithText(ChoiceChip, t.relationshipMother));
    await tester.enterText(field(t.emergencyContactPhone), '+51 987 654 321');
    await tester.enterText(field(t.emergencyContactAlternatePhone), '(01) 555 4444');
    await tester.tap(find.text(t.emergencySaveContact));
    await tester.pumpAndSettle();

    final contact = saved(container).single;
    expect(contact.name, 'Ana Pérez');
    expect(contact.relationship, ContactRelationship.mother);
    expect(contact.phone, '+51987654321');
    expect(contact.alternatePhone, '015554444');
    expect(find.text('${t.relationshipMother} · +51987654321'), findsOneWidget);
    expect(find.text(t.emergencyContactAlternateShort('015554444')), findsOneWidget);

    // Editing brings every field back, the relationship chip included.
    await tester.tap(find.byTooltip(t.emergencyEditContact));
    await tester.pumpAndSettle();
    expect(field('Ana Pérez'), findsOneWidget);
    expect(field('015554444'), findsOneWidget);
    expect(
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, t.relationshipMother)).selected,
      isTrue,
    );
  });

  testWidgets('el parentesco y el alterno son opcionales; un alterno igual no se repite', (
    tester,
  ) async {
    final container = await show(tester);
    await tester.enterText(field(t.emergencyContactName), 'Luis');
    await tester.enterText(field(t.emergencyContactPhone), '987654321');
    await tester.enterText(field(t.emergencyContactAlternatePhone), '987 654 321');
    await tester.tap(find.text(t.emergencySaveContact));
    await tester.pumpAndSettle();
    final contact = saved(container).single;
    expect(contact.relationship, isNull);
    expect(contact.alternatePhone, isNull);
  });

  testWidgets('un teléfono alternativo inválido no se guarda', (tester) async {
    final container = await show(tester);
    await tester.enterText(field(t.emergencyContactName), 'Luis');
    await tester.enterText(field(t.emergencyContactPhone), '987654321');
    await tester.enterText(field(t.emergencyContactAlternatePhone), '12');
    await tester.tap(find.text(t.emergencySaveContact));
    await tester.pumpAndSettle();
    expect(find.text(t.emergencyContactPhoneInvalid), findsOneWidget);
    expect(saved(container), isEmpty);
  });

  testWidgets('elegir de mis contactos llena el formulario y no guarda hasta confirmar', (
    tester,
  ) async {
    final picker = _Picker(
      () async => const PickedContact(
        name: 'Luis Quispe',
        // The agenda keeps the first number twice, written in two ways.
        phones: ['+51 999-888-777', '+51999888777', '(01) 555 4444'],
      ),
    );
    final container = await show(tester, picker: picker);
    await tester.tap(find.text(t.emergencyPickFromPhone));
    await tester.pumpAndSettle();
    expect(picker.calls, 1);
    expect(field('Luis Quispe'), findsOneWidget);
    expect(field('+51999888777'), findsOneWidget);
    expect(field('015554444'), findsOneWidget);
    expect(saved(container), isEmpty);

    await tester.tap(find.widgetWithText(ChoiceChip, t.relationshipFriend));
    await tester.tap(find.text(t.emergencySaveContact));
    await tester.pumpAndSettle();
    final contact = saved(container).single;
    expect(contact.name, 'Luis Quispe');
    expect(contact.relationship, ContactRelationship.friend);
    expect(contact.alternatePhone, '015554444');
  });

  testWidgets('un contacto sin teléfono válido pide escribirlo a mano', (tester) async {
    await show(
      tester,
      picker: _Picker(() async => const PickedContact(name: 'Rosa', phones: ['12'])),
    );
    await tester.tap(find.text(t.emergencyPickFromPhone));
    await tester.pumpAndSettle();
    expect(field('Rosa'), findsOneWidget);
    expect(find.text(t.emergencyPickedWithoutPhone), findsOneWidget);
  });

  testWidgets('si se cierra la agenda no cambia nada, y si falla se escribe a mano', (
    tester,
  ) async {
    var fail = false;
    await show(tester, picker: _Picker(() async => fail ? throw StateError('sin agenda') : null));
    await tester.enterText(field(t.emergencyContactName), 'Ana');
    await tester.tap(find.text(t.emergencyPickFromPhone));
    await tester.pumpAndSettle();
    expect(field('Ana'), findsOneWidget);
    expect(find.text(t.emergencyPickFailed), findsNothing);

    fail = true;
    await tester.tap(find.text(t.emergencyPickFromPhone));
    await tester.pumpAndSettle();
    expect(find.text(t.emergencyPickFailed), findsOneWidget);
    expect(field('Ana'), findsOneWidget);
  });
}
