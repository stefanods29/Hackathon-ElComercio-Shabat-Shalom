import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/core/mode/app_mode.dart';

/// Shared by public image widgets and the photo queue.
final imagesEnabledProvider = NotifierProvider<ImagesEnabled, bool>(ImagesEnabled.new);

class ImagesEnabled extends Notifier<bool> {
  @override
  bool build() => ref.watch(appModeProvider) != AppMode.emergency;

  void set(bool enabled) => state = enabled && ref.read(appModeProvider) != AppMode.emergency;
}
