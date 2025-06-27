import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dashapp/Capacitaciones/models/ExamModel.dart';
import 'package:dashapp/Capacitaciones/services/theme_notifier.dart';

class AdminEditExamScreen extends StatefulWidget {

  final String categoryId;

  const AdminEditExamScreen({Key? key, required this.categoryId})
      : super(key: key);

  @override
  State<AdminEditExamScreen> createState() => _AdminEditExamScreenState();
}

class _AdminEditExamScreenState extends State<AdminEditExamScreen> {

  ExamModel? _exam;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadExam();
  }

  Future<void> _loadExam() async {
    final doc = await FirebaseFirestore.instance
        .collection('exams')
        .doc(widget.categoryId)
        .get();

    if (doc.exists) {
      setState(() {
        _exam = ExamModel.fromJson(doc.data()!);
        _loading = false;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_exam != null) {
      final docRef =
      FirebaseFirestore.instance.collection('exams').doc(widget.categoryId);
      final existingDoc = await docRef.get();
      final isActive = existingDoc.data()?['isActive'] ?? false;

      final data = _exam!.toJson();
      data['isActive'] = isActive;

      await docRef.set(data);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Cambios guardados')),
      );
    }
  }

  void _editQuestionDialog({int? index}) {
    final isEditing = index != null;
    final question = isEditing ? _exam!.questions[index] : null;
    final questionController =
    TextEditingController(text: question?.question ?? '');
    final optionControllers = List.generate(
      4,
          (i) => TextEditingController(
        text: question != null && i < question.options.length
            ? question.options[i]
            : '',
      ),
    );
    int correctAnswer = question?.answer ?? 0;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEditing ? '✏️ Editar Pregunta' : '➕ Nueva Pregunta'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: questionController,
                decoration: const InputDecoration(labelText: 'Pregunta'),
              ),
              const SizedBox(height: 10),
              ...List.generate(optionControllers.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: optionControllers[i],
                    decoration:
                    InputDecoration(labelText: 'Opción ${i + 1}'),
                  ),
                );
              }),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                value: correctAnswer,
                decoration: const InputDecoration(labelText: 'Respuesta Correcta'),
                items: List.generate(optionControllers.length, (i) {
                  return DropdownMenuItem(
                    value: i,
                    child: Text('Opción ${i + 1}'),
                  );
                }),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => correctAnswer = val);
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Guardar'),
            onPressed: () {
              final newQuestion = QuestionModel(
                question: questionController.text,
                options: optionControllers.map((c) => c.text).toList(),
                answer: correctAnswer,
              );
              setState(() {
                if (isEditing) {
                  _exam!.questions[index!] = newQuestion;
                } else {
                  _exam!.questions.add(newQuestion);
                }
              });
              Navigator.pop(context);
              _saveChanges();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteQuestion(int index) async {
    setState(() {
      _exam!.questions.removeAt(index);
    });
    _saveChanges();
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

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Editar Examen'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        padding: const EdgeInsets.only(top: kToolbarHeight + 24, left: 16, right: 16),
        child: ListView.builder(
          itemCount: _exam!.questions.length,
          itemBuilder: (context, index) {
            final question = _exam!.questions[index];
            return Card(
              elevation: 5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text(question.question),
                subtitle: Text('Correcta: Opción ${question.answer + 1}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: 'Editar',
                      onPressed: () => _editQuestionDialog(index: index),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      tooltip: 'Eliminar',
                      onPressed: () => _deleteQuestion(index),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Nueva Pregunta'),
        backgroundColor: Colors.indigo,
        onPressed: () => _editQuestionDialog(),
      ),
    );
  }
}
