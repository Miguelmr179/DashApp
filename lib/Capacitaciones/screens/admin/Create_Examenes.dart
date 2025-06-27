import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dashapp/Capacitaciones/models/ExamModel.dart';
import 'package:dashapp/Capacitaciones/services/theme_notifier.dart';

class AdminExamScreen extends StatefulWidget {
  const AdminExamScreen({Key? key}) : super(key: key);

  @override
  State<AdminExamScreen> createState() => _AdminExamScreenState();
}

class _AdminExamScreenState extends State<AdminExamScreen> {

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = List.generate(4, (_) => TextEditingController());
  final List<QuestionModel> _questions = [];

  int _correctAnswerIndex = 0;

  List<String> _areas = [];
  List<String> _categories = [];
  List<String> _lessons = [];

  String? _selectedArea;
  String? _selectedCategory;
  String? _selectedLesson;

  @override
  void initState() {
    super.initState();
    _loadAreas();
  }

  Future<void> _loadAreas() async {
    final snapshot = await FirebaseFirestore.instance.collection('areas').get();
    setState(() {
      _areas = snapshot.docs.map((doc) => doc['name'].toString()).toList();
    });
  }

  Future<void> _loadCategories(String area) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('courses')
        .where('area', isEqualTo: area)
        .get();
    setState(() {
      _categories = snapshot.docs.map((doc) => doc['title'].toString()).toList();
      _selectedCategory = null;
      _lessons.clear();
      _selectedLesson = null;
    });
  }

  Future<void> _loadLessons(String category) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('lessons')
        .where('course', isEqualTo: category)
        .orderBy('title')
        .get();
    setState(() {
      _lessons = snapshot.docs.map((doc) => doc['title'].toString()).toList();
      _selectedLesson = null;
    });
  }

  Future<void> _saveExam() async {
    if (_formKey.currentState!.validate() &&
        _questions.isNotEmpty &&
        _selectedArea != null &&
        _selectedCategory != null &&
        _selectedLesson != null) {
      final exam = ExamModel(
        category: _selectedCategory!,
        questions: _questions,
      );
      final data = exam.toJson()
        ..addAll({
          'area': _selectedArea!,
          'lesson': _selectedLesson!,
          'isActive': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

      await FirebaseFirestore.instance.collection('exams').add(data);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Examen guardado exitosamente')),
      );

      _questions.clear();
      setState(() {
        _selectedArea = null;
        _selectedCategory = null;
        _selectedLesson = null;
      });
    }
  }

  void _addQuestion() {
    if (_questionController.text.isNotEmpty &&
        _optionControllers.every((c) => c.text.isNotEmpty)) {
      _questions.add(
        QuestionModel(
          question: _questionController.text,
          options: _optionControllers.map((c) => c.text).toList(),
          answer: _correctAnswerIndex,
        ),
      );

      _questionController.clear();
      for (var c in _optionControllers) {
        c.clear();
      }
      _correctAnswerIndex = 0;
      setState(() {});
    }
  }

  void _editQuestion(int index) {
    final q = _questions[index];
    _questionController.text = q.question;
    for (int i = 0; i < 4; i++) {
      _optionControllers[i].text = q.options[i];
    }
    _correctAnswerIndex = q.answer;
    setState(() {
      _questions.removeAt(index);
    });
  }

  void _deleteQuestion(int index) {
    setState(() {
      _questions.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.value == ThemeMode.dark;
    final gradient = isDark
        ? const LinearGradient(
      colors: [Color(0xFF0F2027), Color(0xFF2C5364)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    )
        : const LinearGradient(
      colors: [Color(0xFFFCE38A), Color(0xFFFFE0AC)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Crear Examen'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        padding:
        const EdgeInsets.only(top: kToolbarHeight + 32, left: 20, right: 20),
        child: Center(
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    const Text(
                      'Información General',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedArea,
                      decoration: const InputDecoration(labelText: 'Área'),
                      items: _areas
                          .map((area) =>
                          DropdownMenuItem(value: area, child: Text(area)))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedArea = value;
                          _selectedCategory = null;
                          _selectedLesson = null;
                          _categories.clear();
                          _lessons.clear();
                        });
                        if (value != null) _loadCategories(value);
                      },
                      validator: (value) =>
                      value == null ? 'Selecciona un área' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration:
                      const InputDecoration(labelText: 'Curso/Categoría'),
                      items: _categories
                          .map((cat) =>
                          DropdownMenuItem(value: cat, child: Text(cat)))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value;
                          _selectedLesson = null;
                          _lessons.clear();
                        });
                        if (value != null) _loadLessons(value);
                      },
                      validator: (value) =>
                      value == null ? 'Selecciona un curso' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedLesson,
                      decoration: const InputDecoration(labelText: 'Lección'),
                      items: _lessons
                          .map((lesson) =>
                          DropdownMenuItem(value: lesson, child: Text(lesson)))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedLesson = value),
                      validator: (value) =>
                      value == null ? 'Selecciona una lección' : null,
                    ),
                    const Divider(height: 32),
                    const Text(
                      'Agregar Pregunta',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _questionController,
                      decoration: const InputDecoration(labelText: 'Pregunta'),
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(4, (index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TextFormField(
                          controller: _optionControllers[index],
                          decoration:
                          InputDecoration(labelText: 'Opción ${index + 1}'),
                        ),
                      );
                    }),
                    DropdownButtonFormField<int>(
                      value: _correctAnswerIndex,
                      decoration:
                      const InputDecoration(labelText: 'Respuesta Correcta'),
                      items: List.generate(
                        4,
                            (i) => DropdownMenuItem(
                            value: i, child: Text('Opción ${i + 1}')),
                      ),
                      onChanged: (val) => setState(() => _correctAnswerIndex = val!),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _addQuestion,
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Agregar Pregunta'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_questions.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Preguntas Agregadas',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          ..._questions.asMap().entries.map((entry) {
                            final i = entry.key;
                            final q = entry.value;
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              child: ListTile(
                                leading: CircleAvatar(child: Text('${i + 1}')),
                                title: Text(q.question),
                                subtitle: Text('Correcta: Opción ${q.answer + 1}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      tooltip: 'Editar',
                                      onPressed: () => _editQuestion(i),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      tooltip: 'Eliminar',
                                      onPressed: () => _deleteQuestion(i),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _saveExam,
                      icon: const Icon(Icons.save),
                      label: const Text('Guardar Examen Completo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}