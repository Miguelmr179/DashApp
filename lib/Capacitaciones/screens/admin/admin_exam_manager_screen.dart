import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dashapp/Capacitaciones/screens/admin/Create_Examenes.dart';
import 'package:dashapp/Capacitaciones/screens/admin/Edit_Exam.dart';
import 'package:dashapp/Capacitaciones/services/theme_notifier.dart';

class AdminExamManagerScreen extends StatefulWidget {
  const AdminExamManagerScreen({Key? key}) : super(key: key);

  @override
  State<AdminExamManagerScreen> createState() => _AdminExamManagerScreenState();
}

class _AdminExamManagerScreenState extends State<AdminExamManagerScreen> {

  String? _selectedArea;
  String? _selectedCourse;
  String? _selectedLesson;

  List<String> _areas = ['Todos'];
  List<String> _courses = ['Todos'];
  List<String> _lessons = ['Todos'];

  @override
  void initState() {
    super.initState();
    _loadAreas();
  }

  Future<void> _loadAreas() async {
    final snapshot = await FirebaseFirestore.instance.collection('areas').get();
    setState(() {
      _areas = ['Todos'];
      _areas.addAll(snapshot.docs.map((doc) => doc['name'].toString()));
    });
  }

  Future<void> _loadCourses(String? area) async {
    if (area == null || area == 'Todos') {
      setState(() {
        _courses = ['Todos'];
        _selectedCourse = null;
        _lessons = ['Todos'];
        _selectedLesson = null;
      });
      return;
    }
    final snapshot = await FirebaseFirestore.instance
        .collection('courses')
        .where('area', isEqualTo: area)
        .get();
    setState(() {
      _courses = ['Todos'];
      _courses.addAll(snapshot.docs.map((doc) => doc['title'].toString()));
      _selectedCourse = null;
      _lessons = ['Todos'];
      _selectedLesson = null;
    });
  }

  Future<void> _loadLessons(String? course) async {
    if (course == null || course == 'Todos') {
      setState(() {
        _lessons = ['Todos'];
        _selectedLesson = null;
      });
      return;
    }
    final snapshot = await FirebaseFirestore.instance
        .collection('lessons')
        .where('course', isEqualTo: course)
        .get();
    setState(() {
      _lessons = ['Todos'];
      _lessons.addAll(snapshot.docs.map((doc) => doc['title'].toString()));
      _selectedLesson = null;
    });
  }

  Future<void> _deleteExam(BuildContext context, String examId) async {
    await FirebaseFirestore.instance.collection('exams').doc(examId).delete();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Examen eliminado exitosamente')),
    );
  }

  Future<void> _setActiveExam(BuildContext context, String selectedExamId, String lesson) async {
    final examsSnapshot = await FirebaseFirestore.instance
        .collection('exams')
        .where('lesson', isEqualTo: lesson)
        .get();

    final batch = FirebaseFirestore.instance.batch();

    for (var doc in examsSnapshot.docs) {
      final isThis = doc.id == selectedExamId;
      batch.update(doc.reference, {'isActive': isThis});
    }

    await batch.commit();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Examen activado para esta lección.')),
    );
  }

  void _confirmDelete(BuildContext context, String examId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar Examen?'),
        content: const Text('¿Estás seguro de que deseas eliminar este examen? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text('Eliminar'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _deleteExam(context, examId);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = themeNotifier.value == ThemeMode.dark;
    final backgroundGradient = isDarkMode
        ? const LinearGradient(
      colors: [Color(0xFF0F2027), Color(0xFF2C5364)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    )
        : const LinearGradient(
      colors: [Color(0xFFE0E0E0), Color(0xFFFFFFFF)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Administrar Exámenes',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Crear nuevo examen',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminExamScreen()),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        padding: const EdgeInsets.only(top: kToolbarHeight + 24, left: 16, right: 16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _selectedArea,
              decoration: const InputDecoration(labelText: 'Filtrar por Área'),
              items: _areas
                  .map((area) => DropdownMenuItem(value: area == 'Todos' ? null : area, child: Text(area)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedArea = value;
                  _selectedCourse = null;
                  _courses.clear();
                  _lessons.clear();
                });
                _loadCourses(value);
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedCourse,
              decoration: const InputDecoration(labelText: 'Filtrar por Curso'),
              items: _courses
                  .map((course) => DropdownMenuItem(value: course == 'Todos' ? null : course, child: Text(course)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCourse = value;
                  _selectedLesson = null;
                  _lessons.clear();
                });
                _loadLessons(value);
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedLesson,
              decoration: const InputDecoration(labelText: 'Filtrar por Lección'),
              items: _lessons
                  .map((lesson) => DropdownMenuItem(value: lesson == 'Todos' ? null : lesson, child: Text(lesson)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedLesson = value;
                });
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('exams').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No hay exámenes creados.'));
                  }

                  final exams = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final category = data['category'] ?? '';
                    final area = data['area'] ?? '';
                    final lesson = data['lesson'] ?? '';
                    final areaMatch = _selectedArea == null || _selectedArea == 'Todos' || area == _selectedArea;
                    final courseMatch = _selectedCourse == null || _selectedCourse == 'Todos' || category == _selectedCourse;
                    final lessonMatch = _selectedLesson == null || _selectedLesson == 'Todos' || lesson == _selectedLesson;
                    return areaMatch && courseMatch && lessonMatch;
                  }).toList();

                  return ListView.builder(
                    itemCount: exams.length,
                    itemBuilder: (context, index) {
                      final exam = exams[index];
                      final data = exam.data() as Map<String, dynamic>;
                      final isActive = data['isActive'] == true;
                      final docId = exam.id;
                      final category = data['category'] ?? 'Sin categoría';
                      final lesson = data['lesson'] ?? 'Sin lección';

                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Curso: $category',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Lección: $lesson',
                                style: const TextStyle(fontWeight: FontWeight.normal, fontSize: 18),
                              ),
                              const SizedBox(height: 8),
                              //Mostrar la fecha de creación del examen junto con la hora.
                              Text(
                                'Creado: ${data['createdAt']?.toDate().toLocal().toString().substring(0, 16) ?? 'Fecha no disponible'}',
                                style: const TextStyle(color: Colors.grey),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isActive ? '✅ Examen Activo' : 'Inactivo',
                                style: TextStyle(color: isActive ? Colors.green : Colors.grey),
                              ),
                              const Divider(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    tooltip: 'Editar Examen',
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => AdminEditExamScreen(categoryId: docId),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    tooltip: 'Eliminar Examen',
                                    onPressed: () => _confirmDelete(context, docId),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      isActive ? Icons.check_circle : Icons.radio_button_unchecked,
                                      color: isActive ? Colors.green : Colors.grey,
                                    ),
                                    tooltip: isActive ? 'Examen Activo' : 'Activar este Examen',
                                    onPressed: () => _setActiveExam(context, docId, lesson),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
