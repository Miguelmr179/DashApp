import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;
import 'package:dashapp/Capacitaciones/services/theme_notifier.dart';

class create_content_instructor extends StatefulWidget {
  const create_content_instructor({Key? key}) : super(key: key);

  @override
  State<create_content_instructor> createState() => _CreateContentInstructorState();
}

class _CreateContentInstructorState extends State<create_content_instructor> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  File? _selectedFile;
  String? _instructorArea;
  String _contentType = 'Video';
  bool _isLoading = false;
  double _uploadProgress = 0.0;

  final List<String> _contentTypes = ['Video', 'Imagen'];

  @override
  void initState() {
    super.initState();
    _loadInstructorArea();
  }

  Future<void> _loadInstructorArea() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final area = userDoc.data()?['area'];

    if (area == null || area.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No tienes un área asignada. Contacta al administrador.')),
        );
        Navigator.pop(context);
      }
    } else {
      setState(() {
        _instructorArea = area;
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

  Future<void> _uploadContent() async {
    if (!_formKey.currentState!.validate() || _selectedFile == null || _instructorArea == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos y selecciona un archivo.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _uploadProgress = 0.0;
    });

    try {
      final storageRef = FirebaseStorage.instance.ref();
      final fileName = path.basename(_selectedFile!.path);
      final folder = _contentType.toLowerCase() + 's';
      final fileRef = storageRef.child('$folder/$fileName');
      final uploadTask = fileRef.putFile(_selectedFile!);

      uploadTask.snapshotEvents.listen((snapshot) {
        setState(() {
          _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        });
      });

      await uploadTask;
      final fileUrl = await fileRef.getDownloadURL();

      await FirebaseFirestore.instance.collection('contents').add({
        'title': _titleController.text,
        'description': _descriptionController.text,
        'category': _instructorArea,
        'storageUrl': fileUrl,
        'uploader': FirebaseAuth.instance.currentUser!.uid,
        'uploadDate': DateTime.now().toIso8601String(),
        'type': _contentType,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contenido subido exitosamente.')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = themeNotifier.value == ThemeMode.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final Color hintTextColor = isDarkMode ? Colors.white54 : Colors.black45;

    return Scaffold(
      appBar: AppBar(title: const Text('Subir contenido de área')),
      body: _instructorArea == null
          ? const Center(child: CircularProgressIndicator())
          : AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              decoration: BoxDecoration(
                gradient: isDarkMode
                    ? const LinearGradient(
                        colors: [Color(0xFF0F2027), Color(0xFF2C5364)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      )
                    : const LinearGradient(
                        colors: [Color(0xFFE0E0E0), Color(0xFFFFFFFF)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
              ),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          value: _contentTypes.contains(_contentType) ? _contentType : null,
                          decoration: const InputDecoration(
                            labelText: 'Tipo de contenido',
                            border: OutlineInputBorder(),
                          ),
                          items: _contentTypes.map((type) {
                            return DropdownMenuItem(value: type, child: Text(type));
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _contentType = value!;
                              _selectedFile = null;
                            });
                          },
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _titleController,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: textColor.withOpacity(0.05),
                            hintText: 'Título',
                            hintStyle: TextStyle(color: hintTextColor),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (value) =>
                              value == null || value.isEmpty ? 'Ingresa un título' : null,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _descriptionController,
                          style: TextStyle(color: textColor),
                          maxLines: 3,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: textColor.withOpacity(0.05),
                            hintText: 'Descripción',
                            hintStyle: TextStyle(color: hintTextColor),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (value) =>
                              value == null || value.isEmpty ? 'Ingresa una descripción' : null,
                        ),
                        const SizedBox(height: 20),
                        InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Área asignada',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            _instructorArea ?? '',
                            style: TextStyle(color: textColor),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _pickFile,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Seleccionar archivo'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6A11CB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _selectedFile != null
                            ? Text(
                                'Archivo: ${path.basename(_selectedFile!.path)}',
                                style: TextStyle(color: textColor),
                              )
                            : Text(
                                'No se seleccionó archivo',
                                style: TextStyle(color: hintTextColor),
                              ),
                        const SizedBox(height: 30),
                        _isLoading
                            ? Column(
                                children: [
                                  LinearProgressIndicator(value: _uploadProgress, minHeight: 10),
                                  const SizedBox(height: 10),
                                  Text('${(_uploadProgress * 100).toStringAsFixed(0)}%',
                                      style: TextStyle(color: textColor)),
                                ],
                              )
                            : SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _uploadContent,
                                  child: const Text('Subir contenido'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6A11CB),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
              ),
        )
    );
  }
}