import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dashapp/Capacitaciones/models/videos.dart';

class UpdateVideoScreen extends StatefulWidget {
  final String videoId;

  const UpdateVideoScreen({super.key, required this.videoId});

  @override
  _UpdateVideoScreenState createState() => _UpdateVideoScreenState();
}

final FirebaseFirestore _firestore = FirebaseFirestore.instance;

class _UpdateVideoScreenState extends State<UpdateVideoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedArea;
  File? _selectedFile;
  String _fileType = 'Video';
  Video? _video;
  String? _selectedCourse;
  String? _selectedLesson;
  List<String> _courses = [];
  List<String> _lessons = [];
  bool _isLoadingCourses = true;
  bool _isLoadingLessons = true;
  bool _isAddingNewCourse = false;
  bool _isAddingNewLesson = false;

  List<String> _categories = [];
  bool _isLoadingCategories = true;

  final List<String> _fileTypes = ["Video", "Imagen", "Archivo"];

  @override
  void initState() {
    super.initState();
    _loadCategories().then((_) => _fetchVideo());
  }

  Future<void> _loadCategories() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance.collection('areas').get();
      final loadedCategories = querySnapshot.docs.map((doc) => doc['name'] as String).toList();
      setState(() {
        _categories = loadedCategories;
        _isLoadingCategories = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al cargar áreas: $e')));
      }
    }
  }

  Future<void> _loadCourses() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('courses').get();
      final loadedCourses = snapshot.docs.map((doc) => doc['title'] as String).toList();

      setState(() {
        _courses = loadedCourses;
        _isLoadingCourses = false;
      });

      if (_selectedCourse != null) {
        await _loadLessonsForCourse(_selectedCourse!);
      }
    } catch (e) {
      _showError('Error al cargar cursos: $e');
    }
  }

  Future<void> _loadLessonsForCourse(String course) async {
    setState(() {
      _isLoadingLessons = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('lessons')
          .where('course', isEqualTo: course)
          .get();

      final lessonList = snapshot.docs.map((doc) => doc['title'] as String).toList();

      // Mantener la lección actual si existe pero no está en la lista
      final currentLesson = _video?.lesson;
      if (currentLesson != null && !lessonList.contains(currentLesson)) {
        lessonList.insert(0, currentLesson);
      }

      setState(() {
        _lessons = lessonList;
        _isLoadingLessons = false;

        // Solo actualizar _selectedLesson si no está establecido
        if (_selectedLesson == null) {
          _selectedLesson = currentLesson;
        }
      });
    } catch (e) {
      _showError('Error al cargar lecciones: $e');
      setState(() {
        _isLoadingLessons = false;
      });
    }
  }

  Future<void> _fetchVideo() async {
    try {
      final video = await VideoService().getVideoById(widget.videoId);

      // Cargar cursos si no están listos
      if (_isLoadingCourses) {
        await _loadCourses();
      }

      setState(() {
        _video = video;
        _titleController.text = video.title;
        _descriptionController.text = video.description;
        _selectedArea = video.area;
        _selectedCourse = video.course;
        _selectedLesson = video.lesson;
      });

      // Cargar lecciones si tenemos curso
      if (video.course != null) {
        await _loadLessonsForCourse(video.course!);
      }
    } catch (e) {
      if (mounted) {
        _showError('Error al cargar el recurso: $e');
      }
    }
  }

  Future<void> _pickFile() async {
    final picker = ImagePicker();
    XFile? pickedFile;

    if (_fileType == 'Video') {
      pickedFile = await picker.pickVideo(source: ImageSource.gallery);
    } else if (_fileType == 'Imagen') {
      pickedFile = await picker.pickImage(source: ImageSource.gallery);
    }

    if (pickedFile != null) {
      setState(() {
        _selectedFile = File(pickedFile!.path);
      });
    }
  }

  Future<void> _updateVideo() async {
    if (_formKey.currentState!.validate()) {
      final confirm = await _showConfirmationDialog(
        '¿Seguro que quieres actualizar el recurso?',
      );
      if (!confirm) return;
      try {
        // Si se está agregando un curso nuevo
        if (_isAddingNewCourse && _selectedCourse != null && _selectedCourse!.isNotEmpty) {
          final existing = _courses.any(
                (c) => c.toLowerCase().trim() == _selectedCourse!.toLowerCase().trim(),
          );
          if (!existing) {
            await FirebaseFirestore.instance.collection('courses').add({
              'area': _selectedArea,
              'createdAt': FieldValue.serverTimestamp(),
              'title': _selectedCourse
            });
            await _loadCourses();
          }
        }

        // Si se está agregando una lección nueva
        if (_isAddingNewLesson && _selectedLesson != null && _selectedLesson!.isNotEmpty) {
          final existing = _lessons.any(
                (l) => l.toLowerCase().trim() == _selectedLesson!.toLowerCase().trim(),
          );
          if (!existing) {
            await FirebaseFirestore.instance.collection('lessons').add({
              'area': _selectedArea,
              'course': _selectedCourse,
              'createdAt': FieldValue.serverTimestamp(),
              'title': _selectedLesson
            });
            await _loadLessonsForCourse(_selectedCourse!);
          }
        }

        String fileUrl = _video!.storageUrl;

        if (_selectedFile != null) {
          fileUrl = await _uploadFile();
        }

        final updatedVideo = Video(
          id: _video!.id,
          title: _titleController.text,
          description: _descriptionController.text,
          area: _selectedArea!,
          storageUrl: fileUrl,
          uploader: _video!.uploader,
          uploadDate: _video!.uploadDate,
          course: _selectedCourse!,
          lesson: _selectedLesson!,
        );

        await VideoService().updateVideo(updatedVideo);

        if (mounted) {
          _showSuccess('Recurso actualizado correctamente');
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          _showError('Error al actualizar el recurso: $e');
        }
      }
    }
  }

  Future<String> _uploadFile() async {
    if (_selectedFile == null) return '';
    final extension = _selectedFile!.path.split('.').last;
    final storageRef = FirebaseStorage.instance.ref().child(
      "uploads/${DateTime.now().toIso8601String()}.$extension",
    );
    final uploadTask = storageRef.putFile(_selectedFile!);
    final snapshot = await uploadTask.whenComplete(() => {});
    return await snapshot.ref.getDownloadURL();
  }

  Future<void> deleteVideo(String videoId) async {
    try {
      final ref = _firestore.collection('contents').doc(videoId);
      final doc = await ref.get();

      if (!doc.exists) {
        throw Exception('El documento no existe');
      }

      final data = doc.data() as Map<String, dynamic>;
      final String storageUrl = data['storageUrl'];

      final fullPath = Uri.decodeFull(
        RegExp(r'\/o\/(.*?)\?alt=').firstMatch(storageUrl)?.group(1)?.replaceAll('%2F', '/') ?? '',
      );

      await FirebaseStorage.instance.ref(fullPath).delete();
      await ref.delete();

      if (mounted) {
        _showSuccess('Recurso eliminado correctamente');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showError('Error eliminando recurso: $e');
      }
    }
  }

  Future<bool> _showConfirmationDialog(String message) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmación'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _showAddLessonDialog() async {
    if (_selectedCourse == null) {
      _showError('Selecciona un curso primero.');
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
                setState(() {
                  _selectedLesson = newLessonName.trim();
                  _isAddingNewLesson = true;
                });
                Navigator.pop(context);
              },
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final hintTextColor = isDarkMode ? Colors.white54 : Colors.black45;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Actualizar Recurso'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDarkMode ? const Color(0xFF0F2027) : Colors.blueAccent,
      ),
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
        child: SafeArea(
          child: _video == null
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  _buildDropdownType(),
                  const SizedBox(height: 16),
                  const Text('Título'),
                  _buildTextField(
                    _titleController,
                    'Título',
                    textColor,
                    hintTextColor,
                  ),
                  const SizedBox(height: 16),
                  const Text('Descripción'),
                  _buildTextField(
                    _descriptionController,
                    'Descripción',
                    textColor,
                    hintTextColor,
                  ),
                  const SizedBox(height: 16),
                  const Text('Área'),
                  _buildDropdownCategory(),
                  const SizedBox(height: 16),
                  const Text('Curso'),
                  _isLoadingCourses
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        value: _courses.contains(_selectedCourse) ? _selectedCourse : null,
                        decoration: const InputDecoration(
                          labelText: 'Selecciona un curso',
                        ),
                        items: [
                          ..._courses.map(
                                (course) => DropdownMenuItem(
                              value: course,
                              child: Text(course),
                            ),
                          ),
                          const DropdownMenuItem(
                            value: 'Agregar nuevo',
                            child: Text('Agregar nuevo curso...'),
                          ),
                        ],
                        onChanged: (value) async {
                          setState(() {
                            if (value == 'Agregar nuevo') {
                              _isAddingNewCourse = true;
                              _selectedCourse = null;
                              _selectedLesson = null;
                            } else {
                              _selectedCourse = value;
                              _isAddingNewCourse = false;
                            }
                          });

                          if (value != null && value != 'Agregar nuevo') {
                            await _loadLessonsForCourse(value);
                          }
                        },
                        validator: (value) => (_selectedCourse == null && !_isAddingNewCourse)
                            ? 'Selecciona o crea un curso'
                            : null,
                      ),
                      if (_isAddingNewCourse)
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: TextFormField(
                            onChanged: (value) => _selectedCourse = value,
                            validator: (value) => value == null || value.isEmpty
                                ? 'Ingresa el nombre del curso'
                                : null,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: textColor.withOpacity(0.05),
                              hintText: 'Nombre del nuevo curso',
                              hintStyle: TextStyle(
                                color: hintTextColor,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Lección'),
                  _isLoadingLessons
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedLesson,
                        decoration: const InputDecoration(
                          labelText: 'Selecciona una lección',
                        ),
                        items: [
                          ..._lessons.map(
                                (lesson) => DropdownMenuItem(
                              value: lesson,
                              child: Text(lesson),
                            ),
                          ),
                          const DropdownMenuItem(
                            value: 'Agregar nueva',
                            child: Text('Agregar nueva lección...'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == 'Agregar nueva') {
                            _showAddLessonDialog();
                          } else {
                            setState(() {
                              _selectedLesson = value;
                              _isAddingNewLesson = false;
                            });
                          }
                        },
                        validator: (value) => (_selectedLesson == null && !_isAddingNewLesson)
                            ? 'Selecciona o crea una lección'
                            : null,
                      ),
                      if (_isAddingNewLesson)
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: TextFormField(
                            onChanged: (value) => _selectedLesson = value,
                            validator: (value) => value == null || value.isEmpty
                                ? 'Ingresa el nombre de la lección'
                                : null,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: textColor.withOpacity(0.05),
                              hintText: 'Nombre de la nueva lección',
                              hintStyle: TextStyle(
                                color: hintTextColor,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.upload_file),
                    label: Text('Seleccionar $_fileType'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: isDarkMode ? Colors.teal : Colors.blue,
                    ),
                  ),
                  if (_selectedFile != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      child: _fileType == 'Imagen'
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _selectedFile!,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      )
                          : Text(
                        'Archivo seleccionado:\n${_selectedFile!.path.split('/').last}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: textColor),
                      ),
                    ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _updateVideo,
                    icon: const Icon(Icons.save),
                    label: const Text('Actualizar Recurso'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final confirm = await _showConfirmationDialog(
                        '¿Seguro que quieres eliminar este recurso?',
                      );
                      if (confirm) {
                        await deleteVideo(widget.videoId);
                      }
                    },
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text(
                      'Eliminar Recurso',
                      style: TextStyle(color: Colors.black),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
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

  Widget _buildTextField(
      TextEditingController controller,
      String label,
      Color textColor,
      Color hintTextColor,
      ) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: textColor),
      validator: (value) => value == null || value.isEmpty ? 'Campo requerido' : null,
      decoration: InputDecoration(
        filled: true,
        fillColor: textColor.withOpacity(0.05),
        hintText: label,
        hintStyle: TextStyle(color: hintTextColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildDropdownType() {
    return DropdownButtonFormField<String>(
      value: _fileType,
      decoration: const InputDecoration(labelText: 'Tipo de archivo'),
      items: _fileTypes.map(
            (String type) => DropdownMenuItem(value: type, child: Text(type)),
      ).toList(),
      onChanged: (value) => setState(() => _fileType = value!),
      validator: (value) => value == null ? 'Selecciona un tipo' : null,
    );
  }

  Widget _buildDropdownCategory() {
    if (_isLoadingCategories) {
      return const Center(child: CircularProgressIndicator());
    }

    final isValidCategory = _categories.contains(_selectedArea);

    return DropdownButtonFormField<String>(
      value: isValidCategory ? _selectedArea : null,
      decoration: const InputDecoration(labelText: 'Área'),
      items: _categories.map((String category) {
        return DropdownMenuItem(value: category, child: Text(category));
      }).toList(),
      onChanged: (value) => setState(() => _selectedArea = value),
      validator: (value) => value == null ? 'Selecciona una área' : null,
    );
  }
}