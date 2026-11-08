import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:url_launcher/url_launcher.dart';

abstract interface class AppShare {
  Future<bool> text(String text, Rect origin);
  Future<bool> json(Map<String, Object?> data, Rect origin);
}

class SystemAppShare implements AppShare {
  @override
  Future<bool> text(String text, Rect origin) async =>
      (await SharePlus.instance.share(
        ShareParams(text: text, sharePositionOrigin: origin),
      )).status !=
      ShareResultStatus.dismissed;
  @override
  Future<bool> json(Map<String, Object?> data, Rect origin) async {
    final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(data));
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'application/json')],
        fileNameOverrides: ['mis-datos-vecinal.json'],
        sharePositionOrigin: origin,
      ),
    );
    return result.status != ShareResultStatus.dismissed;
  }
}

final appShareProvider = Provider<AppShare>((ref) => SystemAppShare());
Rect shareOrigin(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  return box == null ? const Rect.fromLTWH(0, 0, 1, 1) : box.localToGlobal(Offset.zero) & box.size;
}

abstract interface class PhoneDialer {
  Future<bool> dial(String number);
}

class SystemPhoneDialer implements PhoneDialer {
  @override
  Future<bool> dial(String number) => launchUrl(Uri(scheme: 'tel', path: number));
}

final phoneDialerProvider = Provider<PhoneDialer>((ref) => SystemPhoneDialer());

/// Opens a draft for the user to review. A successful launch is never a delivery receipt.
abstract interface class SmsComposer {
  Future<bool> compose({required String recipient, required String body});
}

class SystemSmsComposer implements SmsComposer {
  @override
  Future<bool> compose({required String recipient, required String body}) {
    if (!RegExp(r'^\+?[0-9]{6,15}$').hasMatch(recipient) || body.isEmpty) {
      return Future.value(false);
    }
    return launchUrl(
      Uri(scheme: 'sms', path: recipient, query: 'body=${Uri.encodeComponent(body)}'),
    );
  }
}

final smsComposerProvider = Provider<SmsComposer>((ref) => SystemSmsComposer());

/// Selected local files are deliberately distinct from uploaded public file ids.
class SelectedPhoto {
  const SelectedPhoto({required this.path, required this.name, this.uploadedFileId});
  final String path;
  final String name;
  final String? uploadedFileId;
}

abstract interface class PhotoPicker {
  Future<List<SelectedPhoto>> pick(int remaining);
}

class SystemPhotoPicker implements PhotoPicker {
  @override
  Future<List<SelectedPhoto>> pick(int remaining) async {
    if (remaining <= 0) return [];
    final files = await ImagePicker().pickMultiImage(
      limit: remaining == 1 ? null : remaining,
      requestFullMetadata: false,
    );
    return files
        .take(remaining)
        .map((file) => SelectedPhoto(path: file.path, name: file.name))
        .toList();
  }
}

final photoPickerProvider = Provider<PhotoPicker>((ref) => SystemPhotoPicker());

abstract interface class CommentDictation {
  Future<bool> start(void Function(String) onWords, void Function() onFailure);
  Future<void> stop();
}

class SystemCommentDictation implements CommentDictation {
  final SpeechToText _speech = SpeechToText();
  void Function()? _onFailure;
  @override
  Future<bool> start(void Function(String) onWords, void Function() onFailure) async {
    _onFailure = onFailure;
    if (!await _speech.initialize(onError: (_) => _onFailure?.call())) return false;
    final locales = await _speech.locales();
    final spanish = locales.where((locale) => locale.localeId.startsWith('es')).firstOrNull;
    if (spanish == null) return false;
    await _speech.listen(
      onResult: (result) => onWords(result.recognizedWords),
      listenOptions: SpeechListenOptions(
        localeId: spanish.localeId,
        listenMode: ListenMode.dictation,
        cancelOnError: true,
      ),
    );
    return true;
  }

  @override
  Future<void> stop() => _speech.stop();
}

final commentDictationProvider = Provider<CommentDictation>((ref) => SystemCommentDictation());
