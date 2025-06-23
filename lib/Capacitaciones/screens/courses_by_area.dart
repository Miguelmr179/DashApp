import 'package:dashapp/Capacitaciones/screens/Lessons_By_Course.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dashapp/Capacitaciones/services/theme_notifier.dart';

class CoursesByAreaScreen extends StatefulWidget {
  final String area;

  const CoursesByAreaScreen({super.key, required this.area});

  @override
  State<CoursesByAreaScreen> createState() => _CoursesByAreaScreenState();
}

class _CoursesByAreaScreenState extends State<CoursesByAreaScreen> {
  final String uid = FirebaseAuth.instance.currentUser!.uid;

  Future<void> _registerCourseStart(String course) async {
    final doc = await FirebaseFirestore.instance
        .collection('course_progress')
        .where('uid', isEqualTo: uid)
        .where('course', isEqualTo: course)
        .limit(1)
        .get();

    if (doc.docs.isEmpty) {
      await FirebaseFirestore.instance.collection('course_progress').add({
        'uid': uid,
        'course': course,
        'area': widget.area,
        'startDate': DateTime.now().toIso8601String(),
        'closed': false,
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

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Cursos de ${widget.area}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('authorized_courses')
                .where('uid', isEqualTo: uid)
                .where('area', isEqualTo: widget.area)
                .where('authorized', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              final courseDocs = snapshot.data!.docs;
              if (courseDocs.isEmpty) {
                return const Center(
                  child: Text('No hay cursos asignados en esta área.'),
                );
              }

              final assignedCourses =
              courseDocs.map((doc) => doc['category'] as String).toList();

              return ListView.builder(
                itemCount: assignedCourses.length,
                itemBuilder: (context, index) {
                  final course = assignedCourses[index];

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('contents')
                        .where('course', isEqualTo: course)
                        .snapshots(),
                    builder: (context, contentSnapshot) {
                      if (!contentSnapshot.hasData) return const SizedBox();

                      final contents = contentSnapshot.data!.docs;
                      final totalContents = contents.length;
                      final contentIds = contents.map((doc) => doc.id).toList();

                      if (totalContents == 0) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            title: Text(course),
                            subtitle: const Text('No hay contenido aún.'),
                          ),
                        );
                      }

                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('content_views')
                            .where('uid', isEqualTo: uid)
                            .where('contentId',
                            whereIn: contentIds.length > 10
                                ? contentIds.sublist(0, 10)
                                : contentIds)
                            .snapshots(),
                        builder: (context, viewSnapshot) {
                          if (!viewSnapshot.hasData) return const SizedBox();

                          final allContents = contents;
                          final viewedContentIds = viewSnapshot.data!.docs
                              .map((doc) => doc['contentId'] as String)
                              .toSet();

                          final vistosTotales = allContents
                              .where((doc) =>
                              viewedContentIds.contains(doc.id))
                              .length;
                          final totalTotales = allContents.length;

                          final progresoGlobal = totalTotales > 0
                              ? vistosTotales / totalTotales.toDouble()
                              : 0.0;
                          final porcentajeGlobal =
                          (progresoGlobal * 100).toStringAsFixed(0);

                          return StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('course_progress')
                                .where('uid', isEqualTo: uid)
                                .where('course', isEqualTo: course)
                                .limit(1)
                                .snapshots(),
                            builder: (context, _) {
                              return Card(
                                elevation: 5,
                                margin: const EdgeInsets.only(bottom: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ListTile(
                                        title: Text(
                                          course,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 8),
                                            LinearProgressIndicator(
                                              value: progresoGlobal,
                                              minHeight: 6,
                                              backgroundColor: Colors.grey[300],
                                              color: progresoGlobal >= 1.0
                                                  ? Colors.green
                                                  : Colors.blueAccent,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Porcentaje de avance: $porcentajeGlobal%',
                                              style: const TextStyle(fontSize: 13),
                                            ),
                                          ],
                                        ),
                                        trailing: const Icon(Icons.arrow_forward_ios),
                                        onTap: () async {
                                          await _registerCourseStart(course);
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  LessonsByCourseScreen(course: course),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
