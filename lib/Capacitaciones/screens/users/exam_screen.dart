
import 'package:dashapp/General/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dashapp/Capacitaciones/models/ExamModel.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;

import '../../services/theme_notifier.dart';

class ExamScreen extends StatefulWidget {

  final String category;
  final String examId;
  final String lesson;

  const ExamScreen({
    Key? key,
    required this.category,
    required this.examId,
    required this.lesson,
  }) : super(key: key);

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> with WidgetsBindingObserver {

  ExamModel? _exam;

  final Map<int, int> _answers = {};
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  int _score = 0;

  bool _submitted = false;
  bool _submitting = false;
  bool _isLastExamCompleted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadExam();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
        _handleSuspiciousActivity('App pausada - posible screenshot');
        break;
      case AppLifecycleState.inactive:
        _handleSuspiciousActivity('App inactiva - posible screenshot');
        break;
      case AppLifecycleState.resumed:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _handleSuspiciousActivity(String activity) {
    FirebaseFirestore.instance.collection('suspicious_activity').add({
      'uid': _uid,
      'activity': activity,
      'examId': widget.examId,
      'category': widget.category,
      'lesson': widget.lesson,
      'timestamp': DateTime.now(),
      'deviceInfo': {
        'platform': Platform.operatingSystem,
        'version': Platform.operatingSystemVersion,
      }
    });
  }

  Widget _buildSecurityOverlay({required Widget child}) {
    return Stack(
      children: [
        child,
        if (!_submitted)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 2.0,
                    colors: [
                      Colors.transparent,
                      Colors.red.withOpacity(0.1),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
                child: Center(
                  child: Transform.rotate(
                    angle: -0.3,
                    child: Text(
                      'EXAMEN CONFIDENCIAL\n${DateTime.now().toIso8601String()}\nUID: ${_uid.substring(0, 8)}...',
                      style: TextStyle(
                        color: Colors.red.withOpacity(0.2),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _loadExam() async {
    final doc = await FirebaseFirestore.instance
        .collection('exams')
        .doc(widget.examId)
        .get();

    if (doc.exists && doc.data()?['isActive'] == true) {
      final loadedExam = ExamModel.fromJson(doc.data()!);
      loadedExam.questions.shuffle();
      setState(() {
        _exam = loadedExam;
      });
    } else {
      setState(() {
        _exam = null;
        _submitted = true;
      });
    }
  }

  Future<void> _submitExam() async {
    setState(() {
      _submitting = true;
    });

    try {
      final totalQuestions = _exam!.questions.length;
      int score = 0;

      List<Map<String, dynamic>> respuestas = [];

      for (int i = 0; i < totalQuestions; i++) {
        final pregunta = _exam!.questions[i];
        final respuestaUsuario = _answers[i] ?? -1;
        final esCorrecta = respuestaUsuario == pregunta.answer;

        if (esCorrecta) score++;

        respuestas.add({
          'esCorrecta': esCorrecta,
          'pregunta': pregunta.question,
          'respuestaCorrecta': pregunta.options[pregunta.answer],
          'respuestaUsuario': respuestaUsuario >= 0
              ? pregunta.options[respuestaUsuario]
              : 'Sin respuesta',
        });
      }

      final percentage = ((score / totalQuestions) * 100).round();

      await FirebaseFirestore.instance.collection('exam_results').add({
        'uid': _uid,
        'examId': widget.examId,
        'category': widget.category,
        'lesson': widget.lesson,
        'score': score,
        'total': totalQuestions,
        'percentage': percentage,
        'timestamp': DateTime.now(),
        'respuestas': respuestas,
      });

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
      final userEmail = userDoc.data()?['email'] ?? 'Desconocido';

      final adminsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      final now = Timestamp.now();
      final senderUid = FirebaseAuth.instance.currentUser?.uid ?? 'system';

      final passed = percentage >= 80;
      final tipoNotificacion = passed ? 'success' : 'warning';
      final mensaje = passed
          ? '✅ El usuario $userEmail aprobó el examen "${widget.lesson}" (${widget.category}) con $percentage%'
          : '⚠️ El usuario $userEmail reprobó el examen "${widget.lesson}" (${widget.category}) con $percentage%';

      if (passed) {
        final temporalData = {
          'uid': _uid,
          'course': widget.category,
          'lesson': widget.lesson,
          'finalScore': percentage,
          'timestamp': DateTime.now(),
        };

        await FirebaseFirestore.instance
            .collection('exam_final_scores_temporal')
            .doc('$_uid-${widget.category}-${widget.lesson}')
            .set(temporalData);

        // ✅ Revisar si ya terminó todos los exámenes del curso
        final allExamDocs = await FirebaseFirestore.instance
            .collection('exams')
            .where('category', isEqualTo: widget.category)
            .where('isActive', isEqualTo: true)
            .get();

        final allLessons = allExamDocs.docs.map((doc) => doc['lesson'] as String).toSet();

        final temporalesSnapshot = await FirebaseFirestore.instance
            .collection('exam_final_scores_temporal')
            .where('uid', isEqualTo: _uid)
            .where('course', isEqualTo: widget.category)
            .get();

        final completadas = temporalesSnapshot.docs.map((doc) => doc['lesson'] as String).toSet();

        final haCompletadoTodo = allLessons.difference(completadas).isEmpty;

        if (haCompletadoTodo) {
          // Mover datos a colección final
          for (final doc in temporalesSnapshot.docs) {
            final data = doc.data();
            final lesson = data['lesson'];
            await FirebaseFirestore.instance
                .collection('exam_final_scores')
                .doc('$_uid-${widget.category}-$lesson')
                .set(data);

            await doc.reference.delete();
          }

          // Cerrar el curso
          final progressSnapshot = await FirebaseFirestore.instance
              .collection('course_progress')
              .where('uid', isEqualTo: _uid)
              .where('course', isEqualTo: widget.category)
              .where('closed', isEqualTo: false)
              .get();

          for (final doc in progressSnapshot.docs) {
            await doc.reference.update({
              'closed': true,
              'endDate': DateTime.now(),
            });
          }

          // Limpiar content_views de todo el curso
          final contents = await FirebaseFirestore.instance
              .collection('contents')
              .where('course', isEqualTo: widget.category)
              .get();

          final contentIds = contents.docs.map((doc) => doc.id).toList();

          if (contentIds.isNotEmpty) {
            final viewsSnapshot = await FirebaseFirestore.instance
                .collection('content_views')
                .where('uid', isEqualTo: _uid)
                .where('contentId', whereIn: contentIds)
                .get();

            for (final view in viewsSnapshot.docs) {
              batch.delete(view.reference);
            }
          }
        }
      }

      for (final admin in adminsSnapshot.docs) {
        final notifRef = FirebaseFirestore.instance.collection('notifications').doc();
        batch.set(notifRef, {
          'uid': admin.id,
          'senderUid': senderUid,
          'message': mensaje,
          'type': tipoNotificacion,
          'timestamp': now,
          'readBySender': false,
          'readByReceiver': false,
          'deletedByReceiver': false,
          'deletedBySender': false,
        });
      }

      await batch.commit();

      final remaining = await FirebaseFirestore.instance
          .collection('exams')
          .where('category', isEqualTo: widget.category)
          .where('lesson', isEqualTo: widget.lesson)
          .where('isActive', isEqualTo: true)
          .get();

      setState(() {
        _submitted = true;
        _score = score;
        _isLastExamCompleted = remaining.docs.length <= 1;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar el examen: $e')),
      );
    } finally {
      setState(() {
        _submitting = false;
      });
    }
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

    final totalQuestions = _exam?.questions.length ?? 0;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Examen: ${widget.lesson}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
        ),
      ),
      body: _buildSecurityOverlay(
        child: Container(
          decoration: BoxDecoration(gradient: backgroundGradient),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: (_exam == null && !_submitted)
                ? const Center(child: CircularProgressIndicator())
                : (_exam == null && _submitted)
                ? const Center(child: Text('Este examen no está activo actualmente.'))
                : _submitted
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _score / totalQuestions >= 0.8
                        ? Icons.verified
                        : Icons.warning_amber_rounded,
                    size: 70,
                    color: _score / totalQuestions >= 0.8
                        ? Colors.greenAccent
                        : Colors.redAccent,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Resultado: $_score / $totalQuestions',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Volver'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: () async {
                      final userDoc = await FirebaseFirestore.instance
                          .collection('users')
                          .doc(_uid)
                          .get();
                      final rol = userDoc.data()?['role'] ?? 'user';

                      if (_isLastExamCompleted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => HomeScreen(role: rol)),
                        );
                      } else {
                        Navigator.pop(context);
                      }
                    },
                  ),
                ],
              ),
            )
                : Column(
              children: [
                const SizedBox(height: kToolbarHeight + 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.security, size: 16, color: Colors.red),
                      const SizedBox(width: 4),
                      Text(
                        'Examen Protegido',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _answers.length / totalQuestions,
                  minHeight: 8,
                  backgroundColor: Colors.black12,
                  color: Colors.deepPurpleAccent,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: _exam!.questions.length,
                    itemBuilder: (context, i) {
                      final q = _exam!.questions[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${i + 1}. ${q.question}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ...List.generate(q.options.length, (j) {
                                return RadioListTile<int>(
                                  title: Text(q.options[j]),
                                  value: j,
                                  groupValue: _answers[i],
                                  activeColor: Colors.deepPurple,
                                  onChanged: (val) {
                                    setState(() {
                                      _answers[i] = val!;
                                    });
                                  },
                                );
                              }),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  icon: _submitting
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.check),
                  label: Text(_submitting ? 'Enviando...' : 'Enviar Examen'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _answers.length == totalQuestions
                        ? Colors.deepPurple
                        : Colors.grey,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: (_answers.length == totalQuestions && !_submitting)
                      ? _submitExam
                      : null,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
