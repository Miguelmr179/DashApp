// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dashapp/Capacitaciones/screens/admin/Delete_Access_Of_Courses.dart';
import 'package:dashapp/Capacitaciones/screens/admin/MassiveAssignScreen.dart';
import 'package:dashapp/Capacitaciones/services/theme_notifier.dart';

class ManageCourseAccessScreen extends StatefulWidget {
  const ManageCourseAccessScreen({Key? key}) : super(key: key);

  @override
  _ManageCourseAccessScreenState createState() =>
      _ManageCourseAccessScreenState();
}

class _ManageCourseAccessScreenState extends State<ManageCourseAccessScreen> {

  final TextEditingController _searchController = TextEditingController();
  final Map<String, bool> _expandedTiles = {};
  final Map<String, String?> _selectedAreas = {};
  final Map<String, List<String>> _selectedCourses = {};
  final Map<String, List<String>> _areaCourses = {};

  List<String> _allAreas = [];
  List<String> _allCourses = [];

  @override
  void initState() {
    super.initState();
    _loadAreasAndCourses();
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _usersStream() {
    return FirebaseFirestore.instance.collection('users').snapshots();
  }

  Stream<List<String>> _userCoursesStream(String uid) {
    return FirebaseFirestore.instance
        .collection('authorized_courses')
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => doc.data()['category'] as String)
          .toList();
    });
  }

  Future<void> _loadAreasAndCourses() async {
    try {
      final areasSnapshot =
          await FirebaseFirestore.instance.collection('areas').get();
      final coursesSnapshot =
          await FirebaseFirestore.instance.collection('courses').get();

      setState(() {
        _allAreas =
            areasSnapshot.docs.map((doc) => doc['name'] as String).toList();
        _allCourses =
            coursesSnapshot.docs.map((doc) => doc['title'] as String).toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al cargar datos: $e')));
    }
  }

  Future<void> _assignCourseToUser(String uid, String courseTitle) async {
    try {
      final courseSnapshot =
          await FirebaseFirestore.instance
              .collection('courses')
              .where('title', isEqualTo: courseTitle)
              .limit(1)
              .get();

      if (courseSnapshot.docs.isEmpty) throw 'Curso no encontrado';

      final area = courseSnapshot.docs.first.data()['area'];

      await FirebaseFirestore.instance.collection('authorized_courses').add({
        'uid': uid,
        'category': courseTitle,
        'authorized': true,
        'area': area,
      });
      await FirebaseFirestore.instance.collection('notifications').add({
        'message': "Se te ha asignado el curso $courseTitle",
        'readBySender': false,
        'readByReceiver': false,
        'timestamp': Timestamp.now(),
        'uid': uid,
        'senderUid': "admin",
        'type': 'success',
        'deletedByReceiver': false,
        'deletedBySender': false,
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al asignar curso: $e')));
    }
  }

  Future<void> _removeAccess(String uid, String category) async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('authorized_courses')
              .where('uid', isEqualTo: uid)
              .where('category', isEqualTo: category)
              .get();

      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Curso removido exitosamente.')),
      );
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al remover curso: $e')));
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.value == ThemeMode.dark;
    final backgroundGradient =
        isDark
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
            'Gestionar Accesos a Cursos',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_forever),
              tooltip: 'Eliminar Accesos',
              onPressed: () => _navigateTo(const ViewCourseAccessScreen()),
            ),
            IconButton(
              icon: const Icon(Icons.group_add),
              tooltip: 'Asignación Masiva',
              onPressed: () =>
                  _navigateTo(MassiveAssignScreen(categories: _allCourses)),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: SafeArea(
                bottom: false,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por correo, nombre o nómina...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _searchController.clear(),
                    )
                        : const Icon(Icons.search),
                  ),
                ),
              ),
            ),
          ),
        ),
        body: SafeArea(child:

      Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _usersStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final searchText = _searchController.text.trim().toLowerCase();
            final users = snapshot.data?.docs ?? [];
            final filteredUsers =
                searchText.isEmpty
                    ? users
                    : users.where((user) {
                      final data = user.data();
                      final email =
                          (data['email'] ?? '').toString().toLowerCase();
                      final fullName =
                          (data['fullName'] ?? '').toString().toLowerCase();
                      final nomina =
                          (data['nomina'] ?? '').toString().toLowerCase();
                      return email.contains(searchText) ||
                          fullName.contains(searchText) ||
                          nomina.contains(searchText);
                    }).toList();

            if (filteredUsers.isEmpty) {
              return const Center(child: Text('No se encontraron usuarios.'));
            }

            return ListView.builder(
              padding: const EdgeInsets.only(
                top: kToolbarHeight -30,
                bottom: 32,
                left: 16,
                right: 16,
              ),
              itemCount: filteredUsers.length,
              itemBuilder: (context, index) {
                final user = filteredUsers[index];
                final data = user.data();
                final uid = user['id'];
                final email = user['email'];
                final name = data['fullName'] ?? 'Usuario sin nombre';
                final nomina = data['nomina'] ?? 'Nómina no disponible';
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: Theme.of(context).brightness == Brightness.dark
                          ? [const Color(0xFF1C1C1E), const Color(0xFF2C5364)]
                          : [Colors.white, const Color(0xFFF1F1F1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: StatefulBuilder(
                    builder: (context, expandSetState) {
                      final isExpanded = _expandedTiles[uid] ?? false;

                      return Column(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            leading: CircleAvatar(
                              backgroundColor: Colors.deepPurple,
                              child: Text(
                                email[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(
                              name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Correo: $email\nNómina: $nomina',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).textTheme.bodyMedium?.color,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                StreamBuilder<List<String>>(
                                  stream: _userCoursesStream(uid),
                                  builder: (context, snapshot) {
                                    final courses = snapshot.data ?? [];
                                    return Text(
                                      courses.isEmpty
                                          ? 'Sin cursos asignados'
                                          : 'Cursos: ${courses.join(", ")}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).textTheme.bodyMedium?.color,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                isExpanded ? Icons.expand_less : Icons.expand_more,
                                color: Theme.of(context).iconTheme.color,
                              ),
                              onPressed: () {
                                expandSetState(() {
                                  _expandedTiles[uid] = !isExpanded;
                                });
                              },
                            ),
                          ),

                          if (isExpanded)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  StreamBuilder<List<String>>(
                                    stream: _userCoursesStream(uid),
                                    builder: (context, snapshot) {
                                      final userCourses = snapshot.data ?? [];
                                      return Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: userCourses.map(
                                              (course) => Chip(
                                            label: Text(
                                              course,
                                              style: TextStyle(
                                                color: Theme.of(context).textTheme.bodyLarge?.color,
                                              ),
                                            ),
                                            backgroundColor: Colors.deepPurple.shade100,
                                            deleteIcon: Icon(Icons.close, color: Colors.grey.shade700),
                                            onDeleted: () => _removeAccess(uid, course),
                                          ),
                                        ).toList(),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  DropdownButtonFormField<String>(
                                    value: _selectedAreas[uid],
                                    decoration: InputDecoration(
                                      labelText: 'Seleccionar área',
                                      filled: true,
                                      fillColor: Theme.of(context).cardColor,
                                      labelStyle: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).textTheme.bodyLarge?.color,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    ),
                                    dropdownColor: Theme.of(context).cardColor,
                                    icon: const Icon(Icons.arrow_drop_down),
                                    items: _allAreas.map((area) {
                                      return DropdownMenuItem(
                                        value: area,
                                        child: Text(
                                          area,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: Theme.of(context).textTheme.bodyLarge?.color,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (area) async {
                                      expandSetState(() {
                                        _selectedAreas[uid] = area;
                                        _selectedCourses[uid] = [];
                                      });

                                      final snapshot = await FirebaseFirestore.instance
                                          .collection('courses')
                                          .where('area', isEqualTo: area)
                                          .get();

                                      expandSetState(() {
                                        _areaCourses[uid] =
                                            snapshot.docs.map((doc) => doc['title'] as String).toList();
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  if ((_areaCourses[uid] ?? []).isNotEmpty) ...[
                                    Text(
                                      'Selecciona cursos:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).textTheme.bodyLarge?.color,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: _areaCourses[uid]!.map((course) {
                                        final isSelected = (_selectedCourses[uid] ?? []).contains(course);
                                        return FilterChip(
                                          label: Text(
                                            course,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              color: isSelected
                                                  ? Colors.white
                                                  : Theme.of(context).textTheme.bodyLarge?.color,
                                            ),
                                          ),
                                          selected: isSelected,
                                          selectedColor: Colors.deepPurple,
                                          backgroundColor: Theme.of(context).cardColor,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            side: BorderSide(
                                              color: isSelected ? Colors.deepPurple : Colors.grey.shade400,
                                            ),
                                          ),
                                          onSelected: (selected) {
                                            final current = List<String>.from(_selectedCourses[uid] ?? []);
                                            if (selected && !current.contains(course)) {
                                              current.add(course);
                                            } else if (!selected) {
                                              current.remove(course);
                                            }
                                            expandSetState(() {
                                              _selectedCourses[uid] = current;
                                            });
                                          },
                                        );
                                      }).toList(),
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.add),
                                        label: const Text('Asignar'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.teal,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                        ),
                                        onPressed: (_selectedCourses[uid]?.isNotEmpty ?? false)
                                            ? () async {
                                          for (final course in _selectedCourses[uid]!) {
                                            await _assignCourseToUser(uid, course);
                                          }

                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Se asignaron ${_selectedCourses[uid]!.length} curso(s) correctamente.',
                                              ),
                                              backgroundColor: Colors.green,
                                            ),
                                          );

                                          expandSetState(() {
                                            _selectedCourses[uid] = [];
                                            _selectedAreas[uid] = null;
                                            _areaCourses[uid] = [];
                                          });
                                        }
                                            : null,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                );

              },
            );
          },
        ),
      ),
      )
    );
  }
}
