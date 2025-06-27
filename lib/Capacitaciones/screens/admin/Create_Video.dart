/*
//Version MOVIL
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;
import 'package:dashapp/Capacitaciones/services/theme_notifier.dart';
import '../../Utileria/file_picker_web.dart';


class CreateContentScreen extends StatefulWidget {

  final String? preselectedCategory;

  const CreateContentScreen({Key? key, this.preselectedCategory}) : super(key: key);

  @override
  State<CreateContentScreen> createState() => _CreateContentScreenState();
}

class _CreateContentScreenState extends State<CreateContentScreen> {

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  dynamic _selectedFile;

  Uint8List? _webFileBytes;

  String get _selectedFileName {
    if (kIsWeb && _webFileName != null) {
      return _webFileName!;
    } else if (!kIsWeb && _selectedFile != null) {
      return path.basename(_selectedFile.path);
    }
    return 'No se seleccionó archivo';
  }
  String? _webFileName;
  String? _selectedCategory;
  String? _selectedCourse;
  String? _selectedLesson;
  String _contentType = 'Video';

  double _uploadProgress = 0.0;

  List<String> _categories = [];
  List<String> _courses = [];
  List<String> _lessons = [];

  bool get _hasSelectedFile {
    return (kIsWeb && _webFileBytes != null) || (!kIsWeb && _selectedFile != null);
  }
  bool _isLoading = false;
  bool _isLoadingCategories = true;
  bool _isLoadingCourses = false;
  bool _isLoadingLessons = false;

  final List<String> _contentTypes = ['Video', 'Imagen'];

  @override
  void initState() {
    super.initState();
    if (widget.preselectedCategory != null) {
      _selectedCategory = widget.preselectedCategory;
    }
    _loadCategories();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance.collection('areas').get();
      final loadedCategories = querySnapshot.docs.map((doc) => doc['name'] as String).toList();
      setState(() {
        _categories = loadedCategories;
        _isLoadingCategories = false;
      });
      if (_selectedCategory != null) {
        await _loadCoursesForCategory(_selectedCategory!);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar áreas: $e')));
    }
  }

  Future<void> _loadCoursesForCategory(String category) async {
    setState(() {
      _isLoadingCourses = true;
      _selectedCourse = null;
      _selectedLesson = null;
      _lessons = [];
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('courses')
          .where('area', isEqualTo: category)
          .get();

      final courseList = snapshot.docs.map((doc) => doc['title'] as String).toList();

      setState(() {
        _courses = courseList;
        _isLoadingCourses = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar cursos: $e')),
      );
    }
  }

  Future<void> _loadLessonsForCourse(String course) async {
    setState(() {
      _isLoadingLessons = true;
      _selectedLesson = null;
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('lessons')
          .where('course', isEqualTo: course)
          .get();

      final lessonList = snapshot.docs.map((doc) => doc['title'] as String).toList();

      setState(() {
        _lessons = lessonList;
        _isLoadingLessons = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar lecciones: $e')),
      );
    }
  }

  Future<void> _pickFile() async {
    if (kIsWeb) {
      // Para plataforma web
      await _pickFileWeb();
    } else {
      // Para móvil
      await _pickFileMobile();
    }
  }

  Future<void> _pickFileWeb() async {
    try {
      final result = await pickFileWeb();
      setState(() {
        _webFileName = result['name'];
        _webFileBytes = result['bytes'];
        _selectedFile = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al seleccionar archivo: $e')),
      );
    }
  }

  Future<void> _pickFileMobile() async {
    try {
      final picker = ImagePicker();
      XFile? pickedFile;

      if (_contentType == 'Video') {
        pickedFile = await picker.pickVideo(source: ImageSource.gallery);
      } else if (_contentType == 'Imagen') {
        pickedFile = await picker.pickImage(source: ImageSource.gallery);
      }

      if (pickedFile != null) {
        if (!kIsWeb) {
          _selectedFile = File(pickedFile.path);
        }
        setState(() {
          _webFileBytes = null;
          _webFileName = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al seleccionar archivo: $e')),
      );
    }
  }

  Future<void> _uploadContent() async {
    if (!_formKey.currentState!.validate() || !_hasSelectedFile) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa todos los campos y selecciona un archivo.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _uploadProgress = 0.0;
    });

    try {
      final storageRef = FirebaseStorage.instance.ref();
      final folder = _contentType.toLowerCase() + 's';

      String fileName;
      UploadTask uploadTask;

      if (kIsWeb) {
        // Upload para web
        fileName = _webFileName!;
        final fileRef = storageRef.child('$folder/$fileName');
        uploadTask = fileRef.putData(_webFileBytes!);
      } else {
        // Upload para móvil
        fileName = path.basename(_selectedFile.path);
        final fileRef = storageRef.child('$folder/$fileName');
        uploadTask = fileRef.putFile(_selectedFile);
      }

      uploadTask.snapshotEvents.listen((snapshot) {
        setState(() {
          _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        });
      });

      await uploadTask;
      final fileUrl = await uploadTask.snapshot.ref.getDownloadURL();

      // Obtener el mayor valor de "order" para esta lección
      final query = await FirebaseFirestore.instance
          .collection('contents')
          .where('lesson', isEqualTo: _selectedLesson)
          .orderBy('order', descending: true)
          .limit(1)
          .get();

      int nextOrder = 0;
      if (query.docs.isNotEmpty) {
        final currentMaxOrder = query.docs.first.data()['order'] ?? 0;
        nextOrder = currentMaxOrder + 1;
      }

      final data = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'area': _selectedCategory,
        'course': _selectedCourse,
        'lesson': _selectedLesson,
        'storageUrl': fileUrl,
        'uploader': FirebaseAuth.instance.currentUser!.uid,
        'uploadDate': DateTime.now().toIso8601String(),
        'type': _contentType,
        'order': nextOrder,
      };

      await FirebaseFirestore.instance.collection('contents').add(data);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contenido cargado exitosamente.')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al subir: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showAddCategoryDialog() async {
    String newCategoryName = '';
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nueva área'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Nombre de la nueva área'),
            onChanged: (value) => newCategoryName = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (newCategoryName.trim().isEmpty) return;
                try {
                  await FirebaseFirestore.instance.collection('areas').add({
                    'name': newCategoryName.trim(),
                  });
                  await _loadCategories();
                  setState(() {
                    _selectedCategory = newCategoryName.trim();
                  });
                  Navigator.of(context).pop();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al agregar área: $e')),
                  );
                }
              },
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddCourseDialog() async {
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un área primero.')),
      );
      return;
    }

    String newCourseName = '';

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nuevo curso'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Nombre del nuevo curso'),
            onChanged: (value) => newCourseName = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (newCourseName.trim().isEmpty) return;
                try {
                  await FirebaseFirestore.instance.collection('courses').add({
                    'title': newCourseName.trim(),
                    'area': _selectedCategory,
                    'createdAt': DateTime.now().toIso8601String(),
                  });

                  await _loadCoursesForCategory(_selectedCategory!);
                  setState(() {
                    _selectedCourse = newCourseName.trim();
                  });

                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al agregar curso: $e')),
                  );
                }
              },
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddLessonDialog() async {
    if (_selectedCourse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un curso primero.')),
      );
      return;
    }

    String newLessonName = '';

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nueva lección'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Nombre de la nueva lección'),
            onChanged: (value) => newLessonName = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (newLessonName.trim().isEmpty) return;
                try {
                  await FirebaseFirestore.instance.collection('lessons').add({
                    'title': newLessonName.trim(),
                    'course': _selectedCourse,
                    'area': _selectedCategory,
                    'createdAt': DateTime.now().toIso8601String(),
                  });

                  await _loadLessonsForCourse(_selectedCourse!);
                  setState(() {
                    _selectedLesson = newLessonName.trim();
                  });

                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al agregar lección: $e')),
                  );
                }
              },
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = themeNotifier.value == ThemeMode.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final hintTextColor = isDarkMode ? Colors.white54 : Colors.black45;

    return Scaffold(
      appBar: AppBar(title: const Text('Crear nuevo contenido')),
      body: AnimatedContainer(
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
                  if (kDebugMode)
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Plataforma: ${kIsWeb ? 'Web' : 'Móvil'}',
                        style: TextStyle(color: textColor, fontSize: 12),
                      ),
                    ),

                  DropdownButtonFormField<String>(
                    value: _contentType,
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
                        _webFileBytes = null;
                        _webFileName = null;
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
                    validator: (value) => value == null || value.isEmpty ? 'Ingresa un título' : null,
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
                    validator: (value) => value == null || value.isEmpty ? 'Ingresa una descripción' : null,
                  ),
                  const SizedBox(height: 20),
                  _isLoadingCategories
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<String>(
                    value: _categories.contains(_selectedCategory) ? _selectedCategory : null,
                    decoration: const InputDecoration(
                      labelText: 'Área',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      ..._categories.map((category) => DropdownMenuItem(value: category, child: Text(category))),
                      const DropdownMenuItem(value: 'add_new', child: Text('➕ Agregar nueva área')),
                    ],
                    onChanged: widget.preselectedCategory != null
                        ? null
                        : (value) async {
                      if (value == 'add_new') {
                        await _showAddCategoryDialog();
                      } else {
                        setState(() {
                          _selectedCategory = value;
                          _selectedCourse = null;
                          _selectedLesson = null;
                        });
                        await _loadCoursesForCategory(value!);
                      }
                    },
                    validator: (value) => value == null ? 'Selecciona un área' : null,
                  ),
                  const SizedBox(height: 20),
                  _isLoadingCourses
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<String>(
                    value: _selectedCourse,
                    decoration: const InputDecoration(
                      labelText: 'Curso',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      ..._courses.map((course) => DropdownMenuItem(value: course, child: Text(course))),
                      const DropdownMenuItem(value: 'add_new_course', child: Text('➕ Agregar nuevo curso')),
                    ],
                    onChanged: (value) async {
                      if (value == 'add_new_course') {
                        await _showAddCourseDialog();
                      } else {
                        setState(() {
                          _selectedCourse = value;
                          _selectedLesson = null;
                        });
                        await _loadLessonsForCourse(value!);
                      }
                    },
                    validator: (value) => value == null ? 'Selecciona un curso' : null,
                  ),
                  const SizedBox(height: 20),
                  _isLoadingLessons
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<String>(
                    value: _selectedLesson,
                    decoration: const InputDecoration(
                      labelText: 'Lección',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      ..._lessons.map((lesson) => DropdownMenuItem(value: lesson, child: Text(lesson))),
                      const DropdownMenuItem(value: 'add_new_lesson', child: Text('➕ Agregar nueva lección')),
                    ],
                    onChanged: (value) async {
                      if (value == 'add_new_lesson') {
                        await _showAddLessonDialog();
                      } else {
                        setState(() => _selectedLesson = value);
                      }
                    },
                    validator: (value) => value == null ? 'Selecciona una lección' : null,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.upload_file),
                    label: Text(kIsWeb ? 'Seleccionar archivo (Web)' : 'Seleccionar archivo (Móvil)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6A11CB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _hasSelectedFile
                      ? Text('Archivo: $_selectedFileName', style: TextStyle(color: textColor))
                      : Text('No se seleccionó archivo', style: TextStyle(color: hintTextColor)),
                  const SizedBox(height: 30),
                  _isLoading
                      ? Column(
                    children: [
                      LinearProgressIndicator(value: _uploadProgress, minHeight: 10),
                      const SizedBox(height: 10),
                      Text('${(_uploadProgress * 100).toStringAsFixed(0)}%', style: TextStyle(color: textColor)),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
*/

//Version WEB
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;


// Imports condicionales
import 'dart:io' if (dart.library.html) 'dart:html' as html_import;
import 'dart:html' as html show FileUploadInputElement, FileReader;

import '../../services/theme_notifier.dart';

class CreateContentScreen extends StatefulWidget {
  final String? preselectedCategory;
  const CreateContentScreen({Key? key, this.preselectedCategory}) : super(key: key);

  @override
  State<CreateContentScreen> createState() => _CreateContentScreenState();
}

class _CreateContentScreenState extends State<CreateContentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();


  dynamic _selectedFile;

  // Para web
  Uint8List? _webFileBytes;
  String? _webFileName;

  String? _selectedCategory;
  String? _selectedCourse;
  String? _selectedLesson;
  String _contentType = 'Video';
  bool _isLoading = false;
  double _uploadProgress = 0.0;

  List<String> _categories = [];
  List<String> _courses = [];
  List<String> _lessons = [];
  bool _isLoadingCategories = true;
  bool _isLoadingCourses = false;
  bool _isLoadingLessons = false;

  final List<String> _contentTypes = ['Video', 'Imagen'];

  @override
  void initState() {
    super.initState();
    if (widget.preselectedCategory != null) {
      _selectedCategory = widget.preselectedCategory;
    }
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance.collection('areas').get();
      final loadedCategories = querySnapshot.docs.map((doc) => doc['name'] as String).toList();
      setState(() {
        _categories = loadedCategories;
        _isLoadingCategories = false;
      });
      if (_selectedCategory != null) {
        await _loadCoursesForCategory(_selectedCategory!);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar áreas: $e')));
    }
  }

  Future<void> _loadCoursesForCategory(String category) async {
    setState(() {
      _isLoadingCourses = true;
      _selectedCourse = null;
      _selectedLesson = null;
      _lessons = [];
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('courses')
          .where('area', isEqualTo: category)
          .get();

      final courseList = snapshot.docs.map((doc) => doc['title'] as String).toList();

      setState(() {
        _courses = courseList;
        _isLoadingCourses = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar cursos: $e')),
      );
    }
  }

  Future<void> _loadLessonsForCourse(String course) async {
    setState(() {
      _isLoadingLessons = true;
      _selectedLesson = null;
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('lessons')
          .where('course', isEqualTo: course)
          .get();

      final lessonList = snapshot.docs.map((doc) => doc['title'] as String).toList();

      setState(() {
        _lessons = lessonList;
        _isLoadingLessons = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar lecciones: $e')),
      );
    }
  }

  Future<void> _pickFile() async {
    if (kIsWeb) {
      // Para plataforma web
      await _pickFileWeb();
    } else {
      // Para móvil
      await _pickFileMobile();
    }
  }

  Future<void> _pickFileWeb() async {
    try {
      // Crear elemento input file
      final uploadInput = html.FileUploadInputElement();

      // Configurar el tipo de archivos según el contenido
      if (_contentType == 'Video') {
        uploadInput.accept = 'video/*';
      } else if (_contentType == 'Imagen') {
        uploadInput.accept = 'image/*';
      }

      uploadInput.multiple = false;

      // Simular click para abrir el selector de archivos
      uploadInput.click();

      // Esperar a que el usuario seleccione un archivo
      await uploadInput.onChange.first;

      final files = uploadInput.files;
      if (files != null && files.isNotEmpty) {
        final file = files[0];
        final reader = html.FileReader();

        reader.onLoadEnd.listen((e) {
          setState(() {
            _webFileBytes = reader.result as Uint8List;
            _webFileName = file.name;
            // Limpiar archivo móvil si existía
            _selectedFile = null;
          });
        });

        reader.readAsArrayBuffer(file);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al seleccionar archivo: $e')),
      );
    }
  }

  Future<void> _pickFileMobile() async {
    try {
      final picker = ImagePicker();
      XFile? pickedFile;

      if (_contentType == 'Video') {
        pickedFile = await picker.pickVideo(source: ImageSource.gallery);
      } else if (_contentType == 'Imagen') {
        pickedFile = await picker.pickImage(source: ImageSource.gallery);
      }

      if (pickedFile != null) {
        // Solo crear File si no estamos en web
        if (!kIsWeb) {
          _selectedFile = File(pickedFile.path);
        }
        setState(() {
          // Limpiar datos web si existían
          _webFileBytes = null;
          _webFileName = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al seleccionar archivo: $e')),
      );
    }
  }

  bool get _hasSelectedFile {
    return (kIsWeb && _webFileBytes != null) || (!kIsWeb && _selectedFile != null);
  }

  String get _selectedFileName {
    if (kIsWeb && _webFileName != null) {
      return _webFileName!;
    } else if (!kIsWeb && _selectedFile != null) {
      return path.basename(_selectedFile.path);
    }
    return 'No se seleccionó archivo';
  }

  Future<void> _uploadContent() async {
    if (!_formKey.currentState!.validate() || !_hasSelectedFile) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa todos los campos y selecciona un archivo.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _uploadProgress = 0.0;
    });

    try {
      final storageRef = FirebaseStorage.instance.ref();
      final folder = _contentType.toLowerCase() + 's';

      String fileName;
      UploadTask uploadTask;

      if (kIsWeb) {
        // Upload para web
        fileName = _webFileName!;
        final fileRef = storageRef.child('$folder/$fileName');
        uploadTask = fileRef.putData(_webFileBytes!);
      } else {
        // Upload para móvil
        fileName = path.basename(_selectedFile.path);
        final fileRef = storageRef.child('$folder/$fileName');
        uploadTask = fileRef.putFile(_selectedFile);
      }

      uploadTask.snapshotEvents.listen((snapshot) {
        setState(() {
          _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        });
      });

      await uploadTask;
      final fileUrl = await uploadTask.snapshot.ref.getDownloadURL();

      // Obtener el mayor valor de "order" para esta lección
      final query = await FirebaseFirestore.instance
          .collection('contents')
          .where('lesson', isEqualTo: _selectedLesson)
          .orderBy('order', descending: true)
          .limit(1)
          .get();

      int nextOrder = 0;
      if (query.docs.isNotEmpty) {
        final currentMaxOrder = query.docs.first.data()['order'] ?? 0;
        nextOrder = currentMaxOrder + 1;
      }

      final data = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'area': _selectedCategory,
        'course': _selectedCourse,
        'lesson': _selectedLesson,
        'storageUrl': fileUrl,
        'uploader': FirebaseAuth.instance.currentUser!.uid,
        'uploadDate': DateTime.now().toIso8601String(),
        'type': _contentType,
        'order': nextOrder,
      };

      await FirebaseFirestore.instance.collection('contents').add(data);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contenido cargado exitosamente.')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al subir: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showAddCategoryDialog() async {
    String newCategoryName = '';
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nueva área'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Nombre de la nueva área'),
            onChanged: (value) => newCategoryName = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (newCategoryName.trim().isEmpty) return;
                try {
                  await FirebaseFirestore.instance.collection('areas').add({
                    'name': newCategoryName.trim(),
                  });
                  await _loadCategories();
                  setState(() {
                    _selectedCategory = newCategoryName.trim();
                  });
                  Navigator.of(context).pop();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al agregar área: $e')),
                  );
                }
              },
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddCourseDialog() async {
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un área primero.')),
      );
      return;
    }

    String newCourseName = '';

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nuevo curso'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Nombre del nuevo curso'),
            onChanged: (value) => newCourseName = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (newCourseName.trim().isEmpty) return;
                try {
                  await FirebaseFirestore.instance.collection('courses').add({
                    'title': newCourseName.trim(),
                    'area': _selectedCategory,
                    'createdAt': DateTime.now().toIso8601String(),
                  });

                  await _loadCoursesForCategory(_selectedCategory!);
                  setState(() {
                    _selectedCourse = newCourseName.trim();
                  });

                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al agregar curso: $e')),
                  );
                }
              },
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddLessonDialog() async {
    if (_selectedCourse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un curso primero.')),
      );
      return;
    }

    String newLessonName = '';

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nueva lección'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Nombre de la nueva lección'),
            onChanged: (value) => newLessonName = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (newLessonName.trim().isEmpty) return;
                try {
                  await FirebaseFirestore.instance.collection('lessons').add({
                    'title': newLessonName.trim(),
                    'course': _selectedCourse,
                    'area': _selectedCategory,
                    'createdAt': DateTime.now().toIso8601String(),
                  });

                  await _loadLessonsForCourse(_selectedCourse!);
                  setState(() {
                    _selectedLesson = newLessonName.trim();
                  });

                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al agregar lección: $e')),
                  );
                }
              },
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );
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
    final hintTextColor = isDarkMode ? Colors.white54 : Colors.black45;

    return Scaffold(
      appBar: AppBar(title: const Text('Crear nuevo contenido')),
      body: AnimatedContainer(
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
                  // Indicador de plataforma (opcional, para debugging)
                  if (kDebugMode)
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Plataforma: ${kIsWeb ? 'Web' : 'Móvil'}',
                        style: TextStyle(color: textColor, fontSize: 12),
                      ),
                    ),

                  DropdownButtonFormField<String>(
                    value: _contentType,
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
                        _webFileBytes = null;
                        _webFileName = null;
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
                    validator: (value) => value == null || value.isEmpty ? 'Ingresa un título' : null,
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
                    validator: (value) => value == null || value.isEmpty ? 'Ingresa una descripción' : null,
                  ),
                  const SizedBox(height: 20),
                  _isLoadingCategories
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<String>(
                    value: _categories.contains(_selectedCategory) ? _selectedCategory : null,
                    decoration: const InputDecoration(
                      labelText: 'Área',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      ..._categories.map((category) => DropdownMenuItem(value: category, child: Text(category))),
                      const DropdownMenuItem(value: 'add_new', child: Text('➕ Agregar nueva área')),
                    ],
                    onChanged: widget.preselectedCategory != null
                        ? null
                        : (value) async {
                      if (value == 'add_new') {
                        await _showAddCategoryDialog();
                      } else {
                        setState(() {
                          _selectedCategory = value;
                          _selectedCourse = null;
                          _selectedLesson = null;
                        });
                        await _loadCoursesForCategory(value!);
                      }
                    },
                    validator: (value) => value == null ? 'Selecciona un área' : null,
                  ),
                  const SizedBox(height: 20),
                  _isLoadingCourses
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<String>(
                    value: _selectedCourse,
                    decoration: const InputDecoration(
                      labelText: 'Curso',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      ..._courses.map((course) => DropdownMenuItem(value: course, child: Text(course))),
                      const DropdownMenuItem(value: 'add_new_course', child: Text('➕ Agregar nuevo curso')),
                    ],
                    onChanged: (value) async {
                      if (value == 'add_new_course') {
                        await _showAddCourseDialog();
                      } else {
                        setState(() {
                          _selectedCourse = value;
                          _selectedLesson = null;
                        });
                        await _loadLessonsForCourse(value!);
                      }
                    },
                    validator: (value) => value == null ? 'Selecciona un curso' : null,
                  ),
                  const SizedBox(height: 20),
                  _isLoadingLessons
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<String>(
                    value: _selectedLesson,
                    decoration: const InputDecoration(
                      labelText: 'Lección',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      ..._lessons.map((lesson) => DropdownMenuItem(value: lesson, child: Text(lesson))),
                      const DropdownMenuItem(value: 'add_new_lesson', child: Text('➕ Agregar nueva lección')),
                    ],
                    onChanged: (value) async {
                      if (value == 'add_new_lesson') {
                        await _showAddLessonDialog();
                      } else {
                        setState(() => _selectedLesson = value);
                      }
                    },
                    validator: (value) => value == null ? 'Selecciona una lección' : null,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.upload_file),
                    label: Text(kIsWeb ? 'Seleccionar archivo (Web)' : 'Seleccionar archivo (Móvil)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6A11CB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _hasSelectedFile
                      ? Text('Archivo: $_selectedFileName', style: TextStyle(color: textColor))
                      : Text('No se seleccionó archivo', style: TextStyle(color: hintTextColor)),
                  const SizedBox(height: 30),
                  _isLoading
                      ? Column(
                    children: [
                      LinearProgressIndicator(value: _uploadProgress, minHeight: 10),
                      const SizedBox(height: 10),
                      Text('${(_uploadProgress * 100).toStringAsFixed(0)}%', style: TextStyle(color: textColor)),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
