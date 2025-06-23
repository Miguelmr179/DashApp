import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class UpdateContentInstructorScreen extends StatefulWidget {
  final String contentId;
  final String instructorArea;

  const UpdateContentInstructorScreen({
    Key? key,
    required this.contentId,
    required this.instructorArea,
  }) : super(key: key);

  @override
  State<UpdateContentInstructorScreen> createState() =>
      _UpdateContentInstructorScreenState();
}

class _UpdateContentInstructorScreenState extends State<UpdateContentInstructorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  File? _selectedFile;
  String _contentType = 'Video';
  String? _storageUrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    final doc = await FirebaseFirestore.instance.collection('contents').doc(widget.contentId).get();
    final data = doc.data();
    if (data != null) {
      setState(() {
        _titleController.text = data['title'] ?? '';
        _descriptionController.text = data['description'] ?? '';
        _contentType = data['type'] ?? 'Video';
        _storageUrl = data['storageUrl'];
        _loading = false;
      });
    }
  }

  Future<void> _pickFile() async {
    final picker = ImagePicker();
    XFile? pickedFile;

    if (_contentType == 'Video') {
      pickedFile = await picker.pickVideo(source: ImageSource.gallery);
    } else if (_contentType == 'Imagen') {
      pickedFile = await picker.pickImage(source: ImageSource.gallery);
    }

    if (pickedFile != null) {
      setState(() {
        _selectedFile = File(pickedFile!.path);
      });
    }
  }

  Future<void> _updateContent() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      String url = _storageUrl!;
      if (_selectedFile != null) {
        final ref = FirebaseStorage.instance.ref().child(
          "uploads/${DateTime.now().toIso8601String()}.${_selectedFile!.path.split('.').last}",
        );
        await ref.putFile(_selectedFile!);
        url = await ref.getDownloadURL();
      }

      await FirebaseFirestore.instance.collection('contents').doc(widget.contentId).update({
        'title': _titleController.text,
        'description': _descriptionController.text,
        'type': _contentType,
        'storageUrl': url,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contenido actualizado.')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Editar Contenido')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<String>(
                value: _contentType,
                decoration: const InputDecoration(labelText: 'Tipo de contenido'),
                items: ['Video', 'Imagen'].map((type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),
                onChanged: (value) => setState(() => _contentType = value!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Título'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Descripción'),
                maxLines: 3,
                validator: (value) =>
                    value == null || value.isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: widget.instructorArea,
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'Categoría (Área)',
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.upload_file),
                label: Text('Reemplazar archivo ($_contentType)'),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _updateContent,
                icon: const Icon(Icons.save),
                label: const Text('Guardar cambios'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
