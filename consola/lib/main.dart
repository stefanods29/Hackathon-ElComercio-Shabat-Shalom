import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal_consola/app.dart';
import 'package:vecinal_consola/core/config/console_environment.dart';
import 'package:vecinal_consola/core/network/api_errors.dart';
import 'package:vecinal_consola/features/casos/data/cases_providers.dart';
import 'package:vecinal_consola/features/casos/data/http_cases_repository.dart';
import 'package:vecinal_consola/features/celdas/data/cells_providers.dart';
import 'package:vecinal_consola/features/celdas/data/http_cells_repository.dart';
import 'package:vecinal_consola/features/turnos/data/http_shifts_repository.dart';
import 'package:vecinal_consola/features/turnos/data/shifts_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The semantics tree is always on: screen readers find the console without an extra step.
  SemanticsBinding.instance.ensureSemantics();
  final environment = ConsoleEnvironment.fromDefines();
  if (environment.phoneAuthWithFirebase) await _startFirebase(environment);
  runApp(
    ProviderScope(
      overrides: [
        consoleEnvironmentProvider.overrideWithValue(environment),
        // Emergencias of Phase 2, Lot B. `CONSOLE_DATA=demo` still uses the fictitious data.
        operationalCasesFactoryProvider.overrideWithValue(HttpCasesRepository.new),
        operationalCellsFactoryProvider.overrideWithValue(HttpCellsRepository.new),
        operationalShiftsFactoryProvider.overrideWithValue(HttpShiftsRepository.new),
      ],
      // Only a lost connection is retried on its own; a Problem Details answer is explained.
      retry: (attempt, error) =>
          error is ConnectionProblem && attempt < 3 ? Duration(seconds: 2 << attempt) : null,
      child: const ConsoleApp(),
    ),
  );
}

Future<void> _startFirebase(ConsoleEnvironment environment) async {
  if (environment.firebaseAppId.isEmpty) {
    debugPrint('PHONE_AUTH=firebase sin FIREBASE_APP_ID: no se podrá enviar el código.');
    return;
  }
  try {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: environment.firebaseApiKey,
        appId: environment.firebaseAppId,
        messagingSenderId: environment.firebaseSenderId,
        projectId: environment.firebaseProjectId,
        authDomain: environment.firebaseAuthDomain.isEmpty ? null : environment.firebaseAuthDomain,
      ),
    );
    // Firebase keeps no session of its own in this browser (no IndexedDB, no localStorage).
    await FirebaseAuth.instance.setPersistence(Persistence.NONE);
  } on Object catch (error) {
    // The console still opens; signing in then explains that the code could not be sent.
    debugPrint('Firebase no inició: ${error.runtimeType}');
  }
}
