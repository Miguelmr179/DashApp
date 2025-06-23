import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:dashapp/Capacitaciones/screens/Instructor/create_content_instructor.dart';
import 'package:dashapp/Capacitaciones/screens/Instructor/update_content_instructor.dart';
import 'package:dashapp/Capacitaciones/services/theme_notifier.dart';

class ManageInstructorCoursesScreen extends StatefulWidget {
  const ManageInstructorCoursesScreen({Key? key}) : super(key: key);

  @override
  State<ManageInstructorCoursesScreen> createState() =>
      _ManageInstructorCoursesScreenState();
}

class _ManageInstructorCoursesScreenState
    extends State<ManageInstructorCoursesScreen> {
  String? _area;
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _loadUserArea();
  }

  Future<void> _loadUserArea() async {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(_uid).get();
    final data = doc.data();
    setState(() {
      _area = data?['area'];
    });
  }

  Future<void> _deleteContent(String contentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('contents')
          .doc(contentId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contenido eliminado correctamente.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
    }
  }

  void _confirmDelete(String contentId) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmar eliminación'),
            content: const Text('¿Estás seguro de eliminar este contenido?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteContent(contentId);
                },
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = themeNotifier.value == ThemeMode.dark;
    final backgroundGradient =
        isDarkMode
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

    if (_area == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Editar Contenido de Mi Área')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const create_content_instructor(),
            ),
          );
        },

        child: const Icon(Icons.add),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: StreamBuilder<QuerySnapshot>(
          stream:
              FirebaseFirestore.instance
                  .collection('contents')
                  .where('category', isEqualTo: _area)
                  .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Center(
                child: Text('No has subido contenido en tu área.'),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final id = docs[index].id;
                final title = data['title'] ?? 'Sin título';
                final type = data['type'] ?? 'Desconocido';

                return Card(
                  color: isDarkMode ? Colors.black26 : Colors.white,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    title: Text(
                      title,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    subtitle: Text(
                      'Tipo: $type',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white54 : Colors.black54,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            color: Colors.blueAccent,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => UpdateContentInstructorScreen(
                                      contentId: id,
                                      instructorArea: _area!,
                                    ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => _confirmDelete(id),
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
    );
  }
}
