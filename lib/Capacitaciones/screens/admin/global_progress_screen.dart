import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class GlobalProgressScreen extends StatefulWidget {
  const GlobalProgressScreen({super.key});

  @override
  _GlobalProgressScreenState createState() => _GlobalProgressScreenState();
}

class _GlobalProgressScreenState extends State<GlobalProgressScreen> {
  String? _selectedCategory;
  String _searchUser = '';
  List<String> _allCategories = [];
  bool _categoriesInitialized = false;


  Stream<List<UserProgressGeneral>> _progressStream() {
    return FirebaseFirestore.instance
        .collection('content_views')
        .limit(500) // 🔹 Limita visualizaciones
        .snapshots()
        .asyncMap((viewsSnapshot) async {
      try {
        debugPrint('⏳ Iniciando carga de datos...');

        final usersSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .limit(500) // 🔹 Limita usuarios
            .get();

        final startedSnapshot = await FirebaseFirestore.instance
            .collection('course_progress')
            .limit(500) // 🔹 Limita cursos iniciados
            .get();

        final contentSnapshot = await FirebaseFirestore.instance
            .collection('contents')
            .limit(500) // 🔹 Limita contenidos
            .get();

        debugPrint('✅ Datos básicos cargados');

        final users = {
          for (var doc in usersSnapshot.docs)
            doc.id: doc.data()['email'] ?? 'Desconocido',
        };

        final Map<String, Set<String>> contentByCourse = {};
        for (var doc in contentSnapshot.docs) {
          final course = doc.data()['course'] ?? 'Sin categoría';
          contentByCourse.putIfAbsent(course, () => {}).add(doc.id);
        }

        final Map<String, Set<String>> viewsByUser = {};
        for (var doc in viewsSnapshot.docs) {
          final uid = doc.data()['uid'];
          final contentId = doc.data()['contentId'];
          if (uid != null && contentId != null) {
            viewsByUser.putIfAbsent(uid, () => {}).add(contentId);
          }
        }

        final Set<String> allCoursesSet = {};
        final Map<String, Map<String, double>> userProgress = {};

        for (var doc in startedSnapshot.docs) {
          final uid = doc.data()['uid'];
          final course = doc.data()['course'];

          if (uid == null || course == null || !users.containsKey(uid)) continue;

          final courseContents = contentByCourse[course] ?? <String>{};
          final userViews = viewsByUser[uid] ?? <String>{};

          final int watched =
              userViews.where((id) => courseContents.contains(id)).length;
          final int total = courseContents.length;

          double progress = 0.0;
          if (total > 0) {
            progress = watched / total;
          }

          allCoursesSet.add(course);
          userProgress.putIfAbsent(uid, () => {})[course] = progress;
        }

        debugPrint('✅ Progreso calculado para ${userProgress.length} usuarios');

        if (mounted && !_categoriesInitialized) {
          setState(() {
            _allCategories = allCoursesSet.toList()..sort();
            if (!_allCategories.contains(_selectedCategory)) {
              _selectedCategory = null;
            }
            _categoriesInitialized = true; // evita más setState
          });
        }


        return userProgress.entries.map((entry) {
          return UserProgressGeneral(
            email: users[entry.key] ?? 'Desconocido',
            courses: entry.value,
          );
        }).toList();
      } catch (e) {
        debugPrint('❌ Error en _progressStream: $e');
        return [];
      }
    });
  }




  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

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
          '📊 Progreso General',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient), // 🔹 Fondo moderno
        child: SafeArea(
          child: StreamBuilder<List<UserProgressGeneral>>(
            stream: _progressStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No hay usuarios con cursos.'));
              }

              final users = snapshot.data!;
              final filteredUsers = users.where((user) {
                final matchesCategory = _selectedCategory == null ||
                    user.courses.containsKey(_selectedCategory);
                final matchesEmail =
                user.email.toLowerCase().contains(_searchUser.toLowerCase());
                return matchesCategory && matchesEmail;
              }).toList();

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _allCategories.contains(_selectedCategory)
                                ? _selectedCategory
                                : null,
                            decoration: InputDecoration(
                              labelText: 'Filtrar por curso',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: isDarkMode ? Colors.grey[900] : Colors.white,
                            ),
                            dropdownColor: isDarkMode ? Colors.grey[900] : Colors.white,
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('Todos'),
                              ),
                              ..._allCategories.map((category) => DropdownMenuItem(
                                value: category,
                                child: Text(category),
                              )),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedCategory = value);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              labelText: 'Buscar por usuario',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.search),
                              filled: true,
                              fillColor: isDarkMode ? Colors.grey[900] : Colors.white,
                            ),
                            onChanged: (value) =>
                                setState(() => _searchUser = value),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = filteredUsers[index];
                        final categoriesToShow = user.courses.entries.where((entry) {
                          if (_selectedCategory == null) return true;
                          return entry.key == _selectedCategory;
                        });

                        return Card(
                          margin:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 6,
                          color: isDarkMode ? Colors.grey[850] : Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.email,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ...categoriesToShow.map((entry) {
                                  final percentage = (entry.value * 100).round();
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.key,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: LinearProgressIndicator(
                                          value: entry.value,
                                          minHeight: 10,
                                          backgroundColor: Colors.grey[300],
                                          color: entry.value >= 1.0
                                              ? Colors.green
                                              : Colors.blueAccent,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$percentage% completado',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      const SizedBox(height: 10),
                                    ],
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class UserProgressGeneral {
  final String email;
  final Map<String, double> courses;

  UserProgressGeneral({required this.email, required this.courses});
}
