import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/features/onboarding/practice_mode.dart';

/// Five fictional profiles for local exploration, without attributing results to real people.
class DemoProfile {
  const DemoProfile({required this.id, required this.name, required this.trustLevel});
  final String id;
  final String name;
  final int trustLevel;
}

const demoProfiles = [
  DemoProfile(
    id: '01970000-0000-7000-8000-0000000000b1',
    name: 'Perfil de práctica 1',
    trustLevel: 0,
  ),
  DemoProfile(
    id: '01970000-0000-7000-8000-00000000db02',
    name: 'Perfil de práctica 2',
    trustLevel: 1,
  ),
  DemoProfile(
    id: '01970000-0000-7000-8000-00000000db03',
    name: 'Perfil de práctica 3',
    trustLevel: 2,
  ),
  DemoProfile(
    id: '01970000-0000-7000-8000-00000000db04',
    name: 'Perfil de práctica 4',
    trustLevel: 0,
  ),
  DemoProfile(
    id: '01970000-0000-7000-8000-00000000db05',
    name: 'Perfil de práctica 5',
    trustLevel: 1,
  ),
];
final demoProfileIndexProvider = NotifierProvider<DemoProfileIndex, int>(DemoProfileIndex.new);

class DemoProfileIndex extends Notifier<int> {
  @override
  int build() => 0;
  void select(int index) {
    if (index < 0 || index >= demoProfiles.length) throw RangeError.index(index, demoProfiles);
    state = index;
  }
}

final effectiveSessionProvider = Provider<LocalSession>((ref) {
  final actual = ref.watch(sessionProvider);
  if (ref.watch(practiceModeProvider).value != true) return actual;
  final profile = demoProfiles[ref.watch(demoProfileIndexProvider)];
  return LocalSession(
    neighborId: profile.id,
    zoneId: actual.zoneId,
    displayName: profile.name,
    trustLevel: profile.trustLevel,
  );
});
