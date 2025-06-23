import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ReorderVideosScreen extends StatefulWidget {
  final String? initialArea;
  final String? initialCourse;
  final String? initialLesson;

  const ReorderVideosScreen({
    super.key,
    this.initialArea,
    this.initialCourse,
    this.initialLesson,
  });

  @override
  State<ReorderVideosScreen> createState() => _ReorderVideosScreenState();
}

class _ReorderVideosScreenState extends State<ReorderVideosScreen> {
  String? _selectedArea;
  String? _selectedCourse;
  String? _selectedLesson;
  List<String> _areas = ['Todos'];
  List<String> _courses = ['Todos'];
  List<String> _lessons = [];
  List<Map<String, dynamic>> _videos = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAreas().then((_) {
      if (widget.initialArea != null) {
        setState(() => _selectedArea = widget.initialArea);
        _loadCourses(widget.initialArea!).then((_) {
          if (widget.initialCourse != null) {
            setState(() => _selectedCourse = widget.initialCourse);
            _loadLessons().then((_) {
              if (widget.initialLesson != null && _lessons.contains(widget.initialLesson)) {
                setState(() => _selectedLesson = widget.initialLesson);
              }
              _loadVideos();
            });
          }
        });
      }
    });
  }

  Future<void> _loadAreas() async {
    final snapshot = await FirebaseFirestore.instance.collection('areas').get();
    setState(() {
      _areas = ['Todos'];
      _areas.addAll(snapshot.docs.map((e) => e['name'].toString()));
    });
  }

  Future<void> _loadCourses(String area) async {
    Query query = FirebaseFirestore.instance.collection('courses');
    if (area != 'Todos') {
      query = query.where('area', isEqualTo: area);
    }

    final snapshot = await query.get();
    setState(() {
      _courses = ['Todos'];
      _courses.addAll(snapshot.docs.map((e) => e['title'].toString()));
    });
  }

  Future<void> _loadLessons() async {
    if (_selectedArea == null || _selectedCourse == null) return;
    if (_selectedArea == 'Todos' || _selectedCourse == 'Todos') {
      setState(() => _lessons = []);
      return;
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('lessons')
        .where('area', isEqualTo: _selectedArea)
        .where('course', isEqualTo: _selectedCourse)
        .get();

    setState(() {
      _lessons = snapshot.docs.map((e) => e['title'].toString()).toList();
    });
  }

  Future<void> _loadVideos() async {
    setState(() => _isLoading = true);

    Query query = FirebaseFirestore.instance.collection('contents');

    if (_selectedArea != null && _selectedArea != 'Todos') {
      query = query.where('area', isEqualTo: _selectedArea);
    }

    if (_selectedCourse != null && _selectedCourse != 'Todos') {
      query = query.where('course', isEqualTo: _selectedCourse);
    }

    if (_selectedLesson != null) {
      query = query.where('lesson', isEqualTo: _selectedLesson);
    }

    final snapshot = await query.get();

    final items = snapshot.docs.map((doc) {
      final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      return {
        'id': doc.id,
        'title': data['title'] ?? '',
        'order': data['order'] ?? 9999,
      };
    }).toList();

    items.sort((a, b) => a['order'].compareTo(b['order']));

    setState(() {
      _videos = items;
      _isLoading = false;
    });
  }

  Future<void> _saveOrder() async {
    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < _videos.length; i++) {
      final docRef = FirebaseFirestore.instance.collection('contents').doc(_videos[i]['id']);
      batch.update(docRef, {'order': i});
    }
    await batch.commit();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Orden guardado correctamente')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundGradient = isDark
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
        title: const Text('Ordenar Videos por Curso'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Guardar orden',
            onPressed: _saveOrder,
          )
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        padding: const EdgeInsets.only(top: kToolbarHeight + 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedArea ?? 'Todos',
                        decoration: const InputDecoration(labelText: 'Seleccionar área'),
                        items: _areas
                            .map((area) => DropdownMenuItem(
                          value: area,
                          child: Text(area),
                        ))
                            .toList(),
                        onChanged: (value) async {
                          setState(() {
                            _selectedArea = value;
                            _selectedCourse = null;
                            _selectedLesson = null;
                            _courses = ['Todos'];
                            _lessons = [];
                            _videos = [];
                          });
                          if (value != null) await _loadCourses(value);
                          await _loadVideos();
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedCourse ?? 'Todos',
                        decoration: const InputDecoration(labelText: 'Seleccionar curso'),
                        items: _courses
                            .map((course) => DropdownMenuItem(
                          value: course,
                          child: Text(course),
                        ))
                            .toList(),
                        onChanged: (value) async {
                          setState(() {
                            _selectedCourse = value;
                            _selectedLesson = null;
                            _lessons = [];
                          });
                          await _loadLessons();
                          await _loadVideos();
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedLesson,
                        decoration: const InputDecoration(labelText: 'Seleccionar lección'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Todas las lecciones')),
                          ..._lessons.map((lesson) => DropdownMenuItem(
                            value: lesson,
                            child: Text(lesson),
                          )),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedLesson = value);
                          _loadVideos();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _isLoading
                  ? const CircularProgressIndicator()
                  : Expanded(
                child: _videos.isEmpty
                    ? const Center(
                  child: Text(
                    'No hay videos para esta selección.',
                    style: TextStyle(fontSize: 16),
                  ),
                )
                    : ReorderableListView(
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) newIndex -= 1;
                    setState(() {
                      final item = _videos.removeAt(oldIndex);
                      _videos.insert(newIndex, item);
                    });
                  },
                  children: [
                    for (int i = 0; i < _videos.length; i++)
                      Card(
                        key: ValueKey(_videos[i]['id']),
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.drag_handle),
                          title: Text(
                            _videos[i]['title'],
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text('Orden actual: ${_videos[i]['order']}'),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
