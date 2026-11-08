import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart' as native;
import 'package:vecinal/features/media/domain/photo_ports.dart';

class DevicePhotoPicker implements PhotoPicker {
  DevicePhotoPicker([native.ImagePicker? picker]) : _picker = picker ?? native.ImagePicker();
  final native.ImagePicker _picker;
  @override
  Future<Uint8List?> pickSanitized() async {
    // Android Photo Picker / PHPicker avoid requesting access to the entire gallery.
    native.XFile? recovered;
    if (Platform.isAndroid) {
      final lost = await _picker.retrieveLostData();
      if (lost.exception != null) throw const PhotoFailure('seleccion_interrumpida');
      if (lost.files?.isNotEmpty == true) recovered = lost.files!.first;
    }
    final selected = recovered ?? await _picker.pickImage(source: native.ImageSource.gallery);
    if (selected == null) return null;
    if (await selected.length() > 15 * 1024 * 1024) {
      throw const PhotoFailure('foto_muy_grande', retryable: false);
    }
    final input = await selected.readAsBytes();
    final buffer = await ui.ImmutableBuffer.fromUint8List(input);
    ui.ImageDescriptor? descriptor;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      if (descriptor.width * descriptor.height > 20000000) {
        throw const PhotoFailure('foto_muy_grande', retryable: false);
      }
      final ratio = math.min(1.0, 1280 / math.max(descriptor.width, descriptor.height));
      final result = await FlutterImageCompress.compressWithList(
        input,
        minWidth: math.max(1, (descriptor.width * ratio).round()),
        minHeight: math.max(1, (descriptor.height * ratio).round()),
        quality: 75,
        format: CompressFormat.jpeg,
        keepExif: false,
        autoCorrectionAngle: true,
      );
      if (result.isEmpty || result.length > 2097152) {
        throw const PhotoFailure('foto_muy_grande', retryable: false);
      }
      return result;
    } finally {
      descriptor?.dispose();
      buffer.dispose();
    }
  }
}
