// lib/utils/file_picker_web_impl.dart
import 'dart:async';
import 'dart:html' as html;
import 'dart:nativewrappers/_internal/vm/lib/typed_data_patch.dart';

Future<Map<String, dynamic>> pickFileWeb() async {
  final input = html.FileUploadInputElement();
  input.accept = '*/*';
  input.click();

  await input.onChange.first;

  final file = input.files?.first;
  final reader = html.FileReader();

  final completer = Completer<Map<String, dynamic>>();

  reader.onLoadEnd.listen((_) {
    completer.complete({
      'name': file?.name,
      'bytes': reader.result as Uint8List,
    });
  });

  reader.readAsArrayBuffer(file!);
  return completer.future;
}
