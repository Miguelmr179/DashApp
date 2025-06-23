import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageAreasAndCoursesScreen extends StatefulWidget {
  const ManageAreasAndCoursesScreen({super.key});

  @override
  State<ManageAreasAndCoursesScreen> createState() =>
      _ManageAreasAndCoursesScreenState();
}

class _ManageAreasAndCoursesScreenState
    extends State<ManageAreasAndCoursesScreen> {
  final _areaController = TextEditingController();
  final _courseController = TextEditingController();
  final _editCourseController = TextEditingController();

  Future<void> _deleteLessonsByCourse(String course) async {
    final snapshot = await FirebaseFirestore.instance.collection('lessons').where('course', isEqualTo: course).get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  Future<void> _deleteLesson(String lessonId) async {
    final lessonDoc = await FirebaseFirestore.instance.collection('lessons').doc(lessonId).get();
    final lessonTitle = lessonDoc['title'];
    final courseTitle = lessonDoc['course'];

    // Borrar videos relacionados
    final contentsSnapshot = await FirebaseFirestore.instance
        .collection('contents')
        .where('lesson', isEqualTo: lessonTitle)
        .where('course', isEqualTo: courseTitle)
        .get();

    for (final doc in contentsSnapshot.docs) {
      final data = doc.data();
      final storageUrl = data['storageUrl'] as String?;

      // Borrar del storage si hay URL válida
      if (storageUrl != null && storageUrl.contains('/o/')) {
        final path = Uri.decodeFull(storageUrl.split('/o/').last.split('?').first);
        await FirebaseStorage.instance.ref(path).delete().catchError((_) {});
      }

      await doc.reference.delete();
    }

    await FirebaseFirestore.instance.collection('lessons').doc(lessonId).delete();
    setState(() {});
  }

  Future<List<Map<String, dynamic>>> _fetchLessons(String course) async {
    final snapshot = await FirebaseFirestore.instance.collection('lessons').where('course', isEqualTo: course).get();
    return snapshot.docs.map((doc) => {'id': doc.id, 'title': doc['title']}).toList();
  }

  Future<void> _deleteCoursesAndLessonsByArea(String area) async {
    final courseSnapshot = await FirebaseFirestore.instance.collection('courses').where('area', isEqualTo: area).get();
    for (final courseDoc in courseSnapshot.docs) {
      final courseId = courseDoc.id;
      final courseTitle = courseDoc['title'];
      await _deleteLessonsByCourse(courseTitle);
      await FirebaseFirestore.instance.collection('courses').doc(courseId).delete();
    }
  }

  Future<List<String>> _fetchAreas() async {
    final snapshot = await FirebaseFirestore.instance.collection('areas').get();
    return snapshot.docs.map((doc) => doc['name'] as String).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchCourses(String area) async {
    final snapshot = await FirebaseFirestore.instance.collection('courses').where('area', isEqualTo: area).get();
    return snapshot.docs.map((doc) => {'id': doc.id, 'title': doc['title']}).toList();
  }

  Future<void> _addArea(String name) async {
    if (name.trim().isEmpty) return;
    await FirebaseFirestore.instance.collection('areas').add({'name': name.trim()});
    setState(() {});
  }

  Future<void> _deleteArea(String name) async {
    final areaDocs = await FirebaseFirestore.instance.collection('areas').where('name', isEqualTo: name).get();
    for (final doc in areaDocs.docs) {
      await doc.reference.delete();
    }
    setState(() {});
  }

  Future<void> _addCourse(String area, String title) async {
    if (title.trim().isEmpty) return;
    await FirebaseFirestore.instance.collection('courses').add({
      'title': title.trim(),
      'area': area,
      'createdAt': DateTime.now().toIso8601String(),
    });
    setState(() {});
  }

  Future<void> _deleteCourse(String id) async {
    await FirebaseFirestore.instance.collection('courses').doc(id).delete();
    setState(() {});
  }

  Future<void> _moveCourse(String courseId, String newArea) async {
    await FirebaseFirestore.instance.collection('courses').doc(courseId).update({'area': newArea});
    setState(() {});
  }

  Future<void> _renameCourse(String courseId, String oldTitle, String newTitle) async {
    await FirebaseFirestore.instance.collection('courses').doc(courseId).update({'title': newTitle});
    final contentSnapshot = await FirebaseFirestore.instance.collection('contents').where('course', isEqualTo: oldTitle).get();
    for (final doc in contentSnapshot.docs) {
      await doc.reference.update({'course': newTitle});
    }
    setState(() {});
  }

  Future<bool> _showConfirmDeleteDialog({required String title, required String content}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(color: Colors.redAccent)),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    return result == true;
  }

  @override
  void dispose() {
    _areaController.dispose();
    _courseController.dispose();
    _editCourseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundGradient = isDarkMode
        ? const LinearGradient(colors: [Color(0xFF0F2027), Color(0xFF2C5364)], begin: Alignment.topCenter, end: Alignment.bottomCenter)
        : const LinearGradient(colors: [Color(0xFFE0E0E0), Color(0xFFFFFFFF)], begin: Alignment.topCenter, end: Alignment.bottomCenter);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Administrar Áreas y Cursos', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: FutureBuilder<List<String>>(
          future: _fetchAreas(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final areas = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 32, 16, 32),
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar nueva área'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 3,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _showAddAreaDialog,
                ),
                const SizedBox(height: 18),
                ...areas.map((area) => Card(
                  margin: const EdgeInsets.only(bottom: 18),
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      title: Row(
                        children: [
                          const Icon(Icons.apartment, color: Colors.deepPurple),
                          const SizedBox(width: 10),
                          Text(area, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        tooltip: "Eliminar área",
                        onPressed: () async {
                          final confirmed = await _showConfirmDeleteDialog(
                            title: 'Eliminar Área',
                            content: '¿Está seguro que desea eliminar el área "$area"? Esta acción eliminará también todos los cursos y lecciones vinculados.',
                          );
                          if (confirmed) {
                            await _deleteCoursesAndLessonsByArea(area);
                            await _deleteArea(area);
                          }
                        },
                      ),
                      children: [
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: _fetchCourses(area),
                          builder: (context, courseSnapshot) {
                            if (!courseSnapshot.hasData) return const Center(child: CircularProgressIndicator());
                            final courses = courseSnapshot.data!;
                            return Column(
                                children: courses.map((course) => ExpansionTile(
                                  title: ListTile(
                                    leading: const Icon(Icons.menu_book, color: Colors.blueAccent),
                                    title: Text(course['title'], style: const TextStyle(fontWeight: FontWeight.w600)),
                                    trailing: Wrap(
                                      spacing: 6,
                                      children: [
                                        IconButton(icon: const Icon(Icons.edit, color: Colors.deepPurple), onPressed: () => _showRenameCourseDialog(course['id'], course['title'])),
                                        IconButton(icon: const Icon(Icons.compare_arrows, color: Colors.orange), onPressed: () => _showMoveCourseDialog(course['id'])),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                                          tooltip: "Eliminar curso",
                                          onPressed: () async {
                                            final confirm = await _showConfirmDeleteDialog(
                                                title: 'Eliminar Curso',
                                                content: '¿Deseas eliminar el curso "${course['title']}" y sus lecciones?'
                                            );
                                            if (confirm) {
                                              await _deleteLessonsByCourse(course['title']);
                                              await _deleteCourse(course['id']);
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  children: [
                                    FutureBuilder<List<Map<String, dynamic>>>(
                                      future: _fetchLessons(course['title']),
                                      builder: (context, lessonSnapshot) {
                                        if (!lessonSnapshot.hasData) return const SizedBox.shrink();
                                        final lessons = lessonSnapshot.data!;
                                        if (lessons.isEmpty) return const ListTile(title: Text('No hay lecciones registradas.'));
                                        return Column(
                                          children: lessons.map((lesson) => ListTile(
                                            title: Text(lesson['title']),
                                            trailing: IconButton(
                                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                              onPressed: () async {
                                                final confirm = await _showConfirmDeleteDialog(
                                                    title: 'Eliminar Lección',
                                                    content: '¿Deseas eliminar la lección "${lesson['title']}"?'
                                                );
                                                if (confirm) await _deleteLesson(lesson['id']);
                                              },
                                            ),
                                          )).toList(),
                                        );
                                      },
                                    )
                                  ],
                                )).toList()
                            );
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 14),
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Agregar curso a esta área'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
                            ),
                            onPressed: () => _showAddCourseDialog(area),
                          ),
                        ),
                      ],
                    ),
                  ),
                ))
              ],
            );
          },
        ),
      ),
    );
  }


  Future<void> _showAddAreaDialog() async {
    _areaController.clear();
    await showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Nueva Área'),
            content: TextField(
              controller: _areaController,
              decoration: const InputDecoration(hintText: 'Nombre de la área'),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed:
                    () => _addArea(
                      _areaController.text,
                    ).then((_) => Navigator.pop(context)),
                child: const Text('Agregar'),
              ),
            ],
          ),
    );
  }

  Future<void> _showAddCourseDialog(String area) async {
    _courseController.clear();
    await showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text('Nuevo Curso para "$area"'),
            content: TextField(
              controller: _courseController,
              decoration: const InputDecoration(hintText: 'Nombre del curso'),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed:
                    () => _addCourse(
                      area,
                      _courseController.text,
                    ).then((_) => Navigator.pop(context)),
                child: const Text('Agregar'),
              ),
            ],
          ),
    );
  }

  Future<void> _showMoveCourseDialog(String courseId) async {
    final areas = await _fetchAreas();
    String? selectedArea;
    await showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Mover curso a otra área'),
            content: DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Nueva área'),
              items:
                  areas
                      .map(
                        (area) =>
                            DropdownMenuItem(value: area, child: Text(area)),
                      )
                      .toList(),
              onChanged: (value) => selectedArea = value,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  if (selectedArea != null) {
                    _moveCourse(
                      courseId,
                      selectedArea!,
                    ).then((_) => Navigator.pop(context));
                  }
                },
                child: const Text('Mover'),
              ),
            ],
          ),
    );
  }

  Future<void> _showRenameCourseDialog(
    String courseId,
    String currentTitle,
  ) async {
    _editCourseController.text = currentTitle;
    await showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Renombrar curso'),
            content: TextField(
              controller: _editCourseController,
              decoration: const InputDecoration(
                hintText: 'Nuevo nombre del curso',
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed:
                    () => _renameCourse(
                      courseId,
                      currentTitle,
                      _editCourseController.text,
                    ).then((_) => Navigator.pop(context)),
                child: const Text('Actualizar'),
              ),
            ],
          ),
    );
  }
}
