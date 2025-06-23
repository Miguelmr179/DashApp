import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:dashapp/Capacitaciones/screens/ReorderVideosScreen.dart';
import 'package:dashapp/Capacitaciones/screens/admin/Create_Video.dart';
import 'package:dashapp/Capacitaciones/screens/admin/Update_Videos.dart';
import 'package:dashapp/Capacitaciones/services/theme_notifier.dart';

class AdminResourcesScreen extends StatefulWidget {
  const AdminResourcesScreen({Key? key}) : super(key: key);

  @override
  State<AdminResourcesScreen> createState() => _AdminResourcesScreenState();
}

class _AdminResourcesScreenState extends State<AdminResourcesScreen> {
  String? _selectedArea;
  String? _selectedCategory;
  List<String> _areas = [];
  List<String> _categories = [];
  String? _selectedLesson;
  List<String> _lessons = [];

  @override
  void initState() {
    super.initState();
    _loadAreas();
  }

  Future<void> _loadAreas() async {
    final snapshot = await FirebaseFirestore.instance.collection('areas').get();
    final areaList =
    snapshot.docs.map((doc) => doc['name'].toString()).toList();
    setState(() {
      _areas = areaList;
    });
  }

  Future<void> _loadCategories() async {
    if (_selectedArea == null) {
      setState(() => _categories = []);
      return;
    }

    final snapshot =
    await FirebaseFirestore.instance
        .collection('courses')
        .where('area', isEqualTo: _selectedArea)
        .get();

    final courseList =
    snapshot.docs.map((doc) => doc['title'].toString()).toSet().toList();

    setState(() {
      _categories = courseList;
    });
  }

  Future<void> _loadLessons() async {
    if (_selectedCategory == null || _selectedCategory!.isEmpty || _selectedArea == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('lessons')
        .where('area', isEqualTo: _selectedArea)
        .where('course', isEqualTo: _selectedCategory)
        .get();

    final lessonList = snapshot.docs.map((doc) => doc['title'].toString()).toSet().toList();

    setState(() {
      _lessons = lessonList;
    });
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

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Administrar Recursos de Cursos', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Dentro del IconButton de ordenar videos:
          IconButton(
            icon: const Icon(Icons.sort),
            tooltip: 'Ordenar Videos por Curso',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReorderVideosScreen(
                    initialArea: _selectedArea,
                    initialCourse: _selectedCategory,
                    initialLesson: _selectedLesson,
                  ),
                ),
              );
            },
          ),

          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Agregar Video',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateContentScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: Column(
          children: [
            const SizedBox(height: kToolbarHeight + 24),
            // Filtros en Card elevado
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Card(
                elevation: 6,
                color: isDarkMode ? Colors.black54 : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedArea,
                        decoration: InputDecoration(
                          labelText: 'Filtrar por área',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          filled: true,
                          fillColor: isDarkMode ? Colors.white12 : Colors.white,
                        ),
                        dropdownColor: isDarkMode ? Colors.grey[900] : Colors.white,
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Todas las áreas'),
                          ),
                          ..._areas.map(
                                (area) =>
                                DropdownMenuItem(value: area, child: Text(area)),
                          ),
                        ],
                        onChanged: (value) async {
                          setState(() {
                            _selectedArea = value;
                            _selectedCategory = null;
                            _categories = [];
                          });
                          await _loadCategories();
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: InputDecoration(
                          labelText: 'Filtrar por curso',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          filled: true,
                          fillColor: isDarkMode ? Colors.white12 : Colors.white,
                        ),
                        dropdownColor: isDarkMode ? Colors.grey[900] : Colors.white,
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Todos los cursos'),
                          ),
                          ..._categories.map(
                                (cat) => DropdownMenuItem(value: cat, child: Text(cat)),
                          ),
                        ],
                          onChanged: (value) async {
                            setState(() {
                              _selectedCategory = value;
                              _selectedLesson = null;
                              _lessons = [];
                            });
                            await _loadLessons();
                          }

                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedLesson,
                        decoration: InputDecoration(
                          labelText: 'Filtrar por lección',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          filled: true,
                          fillColor: isDarkMode ? Colors.white12 : Colors.white,
                        ),
                        dropdownColor: isDarkMode ? Colors.grey[900] : Colors.white,
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Todas las lecciones'),
                          ),
                          ..._lessons.map((lesson) => DropdownMenuItem(value: lesson, child: Text(lesson))),
                        ],
                          onChanged: (value) {
                            setState(() {
                              _selectedLesson = value;
                            });
                          }


                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Lista de videos
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream:
                FirebaseFirestore.instance
                    .collection('contents')
                    .orderBy('uploadDate')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final docs = snapshot.data?.docs ?? [];

                  final filteredDocs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;

                    final matchArea = _selectedArea == null || data['area'] == _selectedArea;
                    final matchCourse = _selectedCategory == null || data['course'] == _selectedCategory;
                    final matchLesson = _selectedLesson == null || data['lesson'] == _selectedLesson;

                    return matchArea && matchCourse && matchLesson;
                  }).toList();


                  if (filteredDocs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No hay recursos cargados.',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18.0,
                      vertical: 10.0,
                    ),
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      final data =
                      filteredDocs[index].data() as Map<String, dynamic>;
                      final id = filteredDocs[index].id;
                      final title = data['title'] ?? 'Sin título';
                      final category = data['course'] ?? 'Sin categoría';
                      final type = data['type'] ?? 'Desconocido';

                      return Card(
                        elevation: 6,
                        color: isDarkMode ? Colors.black45 : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
                          leading: Icon(Icons.video_library, color: Colors.deepPurple[400]),
                          title: Text(
                            title,
                            style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            'Curso: $category • Tipo: $type',
                            style: TextStyle(
                              color: isDarkMode ? Colors.white70 : Colors.black54,
                              fontSize: 13.5,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.edit,
                            color: Colors.blueAccent,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => UpdateVideoScreen(videoId: id),
                              ),
                            );
                          },
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
