import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

abstract interface class ShareService {
  Future<bool> share(String text, Rect origin);
}

class SystemShareService implements ShareService {
  @override
  Future<bool> share(String text, Rect origin) async {
    final result = await SharePlus.instance.share(
      ShareParams(text: text, sharePositionOrigin: origin),
    );
    return result.status == ShareResultStatus.success;
  }
}

final shareServiceProvider = Provider<ShareService>((ref) => SystemShareService());
