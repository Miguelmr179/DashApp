// lib/utils/file_picker_stub.dart
import 'package:flutter/foundation.dart';

Future<Map<String, dynamic>> pickFileWeb() {
  if (kIsWeb) {
    throw UnsupportedError("Este archivo no debe usarse en Web.");
  }
  return Future.error('Solo disponible en Web');
}
