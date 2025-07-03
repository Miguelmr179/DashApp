/*
//Version MOVIL
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class EditarCarruselComedorScreen extends StatefulWidget {
  const EditarCarruselComedorScreen({super.key});

  @override
  State<EditarCarruselComedorScreen> createState() => _EditarCarruselComedorScreenState();
}

class _EditarCarruselComedorScreenState extends State<EditarCarruselComedorScreen> {

  bool _subiendo = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _seleccionarYSubirImagen() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _subiendo = true);

    final fileName = const Uuid().v4();
    final storageRef = FirebaseStorage.instance.ref('carrusel_comedor/$fileName.jpg');

    try {
      final uploadTask = await storageRef.putFile(File(image.path));
      final url = await uploadTask.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('carrusel_comedor').add({
        'imagenUrl': url,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir la imagen: $e')),
      );
    }

    setState(() => _subiendo = false);
  }

  Future<void> _eliminarImagen(String docId, String url) async {
    try {
      await FirebaseFirestore.instance.collection('carrusel_comedor').doc(docId).delete();
      final ref = FirebaseStorage.instance.refFromURL(url);
      await ref.delete();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Carrusel Comedor'),
        actions: [
          IconButton(
            icon: _subiendo
                ? const CircularProgressIndicator(color: Colors.white)
                : const Icon(Icons.add_photo_alternate),
            onPressed: _subiendo ? null : _seleccionarYSubirImagen,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('carrusel_comedor')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No hay imágenes aún.'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final url = data['imagenUrl'] as String?;

              return Card(
                margin: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    if (url != null)
                      Image.network(url, height: 200, fit: BoxFit.cover),
                    TextButton.icon(
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('Eliminar'),
                      onPressed: () => _eliminarImagen(doc.id, url!),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
*/
//Version WEB
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class EditarCarruselComedorScreen extends StatefulWidget {
  const EditarCarruselComedorScreen({super.key});

  @override
  State<EditarCarruselComedorScreen> createState() => _EditarCarruselComedorScreenState();
}

class _EditarCarruselComedorScreenState extends State<EditarCarruselComedorScreen> {
  bool _subiendo = false;

  Future<void> _seleccionarYSubirImagen() async {
    final input = html.FileUploadInputElement()..accept = 'image/*';
    input.click();

    input.onChange.listen((event) async {
      final file = input.files!.first;
      final reader = html.FileReader();

      reader.readAsArrayBuffer(file);
      await reader.onLoad.first;

      final bytes = reader.result as Uint8List;
      final fileName = const Uuid().v4();
      final storageRef = FirebaseStorage.instance.ref('carrusel_comedor/$fileName.jpg');

      setState(() => _subiendo = true);

      final uploadTask = await storageRef.putData(bytes);
      final url = await uploadTask.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('carrusel_comedor').add({
        'imagenUrl': url,
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() => _subiendo = false);
    });
  }

  Future<void> _eliminarImagen(String docId, String url) async {
    try {
      await FirebaseFirestore.instance.collection('carrusel_comedor').doc(docId).delete();
      final ref = FirebaseStorage.instance.refFromURL(url);
      await ref.delete();
    } catch (_) {
      // manejar errores
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Carrusel Comedor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate),
            onPressed: _subiendo ? null : _seleccionarYSubirImagen,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('carrusel_comedor')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No hay imágenes aún.'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final url = data['imagenUrl'] as String?;

              return Card(
                margin: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    if (url != null)
                      Image.network(url, height: 200, fit: BoxFit.cover),
                    TextButton.icon(
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('Eliminar'),
                      onPressed: () => _eliminarImagen(doc.id, url!),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}


