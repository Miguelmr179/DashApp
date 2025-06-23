import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';


class AgregarNoticiaScreen extends StatefulWidget {
  const AgregarNoticiaScreen({super.key});

  @override
  State<AgregarNoticiaScreen> createState() => _AgregarNoticiaScreenState();
}

class _AgregarNoticiaScreenState extends State<AgregarNoticiaScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _contenidoController = TextEditingController();

  Uint8List? _imagenBytes;
  String? _imagenNombre;
  bool _subiendo = false;

  Future<void> _seleccionarImagen() async {
    final input = html.FileUploadInputElement()..accept = 'image/*';
    input.click();

    input.onChange.listen((event) {
      final file = input.files!.first;
      final reader = html.FileReader();

      reader.readAsArrayBuffer(file);
      reader.onLoadEnd.listen((event) {
        setState(() {
          _imagenBytes = reader.result as Uint8List;
          _imagenNombre = file.name;
        });
      });
    });
  }

  Future<String?> _subirImagen() async {
    if (_imagenBytes == null || _imagenNombre == null) return null;

    final storageRef = FirebaseStorage.instance
        .ref()
        .child('noticias_imagenes')
        .child('${DateTime.now().millisecondsSinceEpoch}_$_imagenNombre');

    final uploadTask = await storageRef.putData(_imagenBytes!);
    return await uploadTask.ref.getDownloadURL();
  }

  Future<void> _guardarNoticia() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _subiendo = true);

    try {
      String? urlImagen = await _subirImagen();

      await FirebaseFirestore.instance.collection('noticias').add({
        'titulo': _tituloController.text.trim(),
        'contenido': _contenidoController.text.trim(),
        'timestamp': Timestamp.now(),
        'autor': 'Administrador',
        'imagenUrl': urlImagen,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Noticia publicada correctamente')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error al guardar: $e')),
        );
      }
    } finally {
      setState(() => _subiendo = false);
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _contenidoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar Noticia'),
        backgroundColor: isDarkMode ? Colors.black : Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _tituloController,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                (value == null || value.trim().isEmpty)
                    ? 'El título es obligatorio.' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _contenidoController,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Contenido',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (value) =>
                (value == null || value.trim().isEmpty)
                    ? 'El contenido es obligatorio.' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.image),
                label: const Text('Seleccionar imagen'),
                onPressed: _seleccionarImagen,
              ),
              if (_imagenBytes != null) ...[
                const SizedBox(height: 10),
                const Text('Vista previa de la imagen:'),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    _imagenBytes!,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
              const SizedBox(height: 30),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: Text(_subiendo ? 'Guardando...' : 'Guardar Noticia'),
                onPressed: _subiendo ? null : _guardarNoticia,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
