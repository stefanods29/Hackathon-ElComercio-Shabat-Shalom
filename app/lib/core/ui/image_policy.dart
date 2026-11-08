import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/features/emergencias/data/emergency_providers.dart';

/// Entering emergency mode resets the optional image download preference.
final imagesEnabledProvider = NotifierProvider<ImagesEnabled, bool>(ImagesEnabled.new);

class ImagesEnabled extends Notifier<bool> {
  @override
  bool build() => !ref.watch(emergencyHomeProvider);
  void set(bool enabled) => state = enabled;
}
