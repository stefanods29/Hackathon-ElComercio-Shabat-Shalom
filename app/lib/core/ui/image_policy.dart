import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/features/emergencias/data/emergency_providers.dart';

/// Shared by public image widgets and the photo queue.
///
/// In emergency mode, turned on by hand or by an active event of the zone, images stay off so the
/// critical data syncs first (Phase 2, Lot A 4.3). Outside it, the neighbor can turn them off to
/// save data.
final imagesEnabledProvider = NotifierProvider<ImagesEnabled, bool>(ImagesEnabled.new);

class ImagesEnabled extends Notifier<bool> {
  @override
  bool build() => !ref.watch(emergencyHomeProvider);

  void set(bool enabled) => state = enabled && !ref.read(emergencyHomeProvider);
}
