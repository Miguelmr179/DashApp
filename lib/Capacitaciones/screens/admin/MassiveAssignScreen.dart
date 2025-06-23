import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:dashapp/Capacitaciones/services/theme_notifier.dart';

class MassiveAssignScreen extends StatefulWidget {
  final List<String> categories;
  const MassiveAssignScreen({Key? key, required this.categories}) : super(key: key);

  @override
  State<MassiveAssignScreen> createState() => _MassiveAssignScreenState();
}

class _MassiveAssignScreenState extends State<MassiveAssignScreen> {
  String? _selectedArea;
  String? _selectedCourse;
  final Set<String> _selectedUserIds = {};
  List<String> _areas = [];
  List<String> _coursesByArea = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _users = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filteredUsers = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAreas();
    _loadUsers();
    _searchController.addListener(() {
      _filterUsers(_searchController.text);
    });
  }

  Future<void> _loadAreas() async {
    final snapshot = await FirebaseFirestore.instance.collection('areas').get();
    setState(() {
      _areas = snapshot.docs.map((doc) => doc['name'].toString()).toList();
    });
  }

  Future<void> _loadCoursesByArea(String area) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('courses')
        .where('area', isEqualTo: area)
        .get();
    setState(() {
      _coursesByArea = snapshot.docs.map((doc) => doc['title'].toString()).toList();
    });
  }

  Future<void> _loadUsers() async {
    final snapshot = await FirebaseFirestore.instance.collection('users').get();
    // Filtrar: Solo usuarios que tienen email (puedes poner más condiciones si lo deseas)
    final filtered = snapshot.docs.where((doc) {
      final data = doc.data();
      final email = (data['email'] ?? '').toString().trim();
      // Si quieres obligar también nombre y nómina, agrega aquí las validaciones.
      return email.isNotEmpty;
    }).toList();

    setState(() {
      _users = filtered;
      _filteredUsers = _users;
      _isLoading = false;
    });
  }

  void _filterUsers(String query) {
    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredUsers = _users.where((doc) {
        final data = doc.data();
        final email = (data['email'] ?? '').toString().toLowerCase();
        final nombre = (data['fullName'] ?? '').toString().toLowerCase();
        final nomina = (data['nomina'] ?? '').toString().toLowerCase();
        return email.contains(lowerQuery) ||
            nombre.contains(lowerQuery) ||
            nomina.contains(lowerQuery);
      }).toList();
    });
  }

  Future<void> _assignToAll() async {
    if (_selectedArea == null || _selectedCourse == null || _selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona un área, un curso y al menos un usuario.'),
        ),
      );
      return;
    }

    final batch = FirebaseFirestore.instance.batch();

    for (final uid in _selectedUserIds) {
      final ref = FirebaseFirestore.instance.collection('authorized_courses').doc();
      batch.set(ref, {
        'uid': uid,
        'area': _selectedArea,
        'category': _selectedCourse,
        'authorized': true,
      });
    }

    await batch.commit();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Asignación masiva completada.')),
      );
      Navigator.pop(context);
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
        title: const Text('Asignación Masiva'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + kToolbarHeight,
            left: 16,
            right: 16,
            bottom: 16,
          ),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedArea,
                decoration: const InputDecoration(labelText: 'Seleccionar área'),
                items: _areas.map((area) => DropdownMenuItem(value: area, child: Text(area))).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedArea = value;
                    _selectedCourse = null;
                    _coursesByArea = [];
                  });
                  if (value != null) _loadCoursesByArea(value);
                },
              ),
              const SizedBox(height: 10),
              if (_coursesByArea.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: _selectedCourse,
                  decoration: const InputDecoration(labelText: 'Seleccionar curso'),
                  items: _coursesByArea
                      .map((course) => DropdownMenuItem(value: course, child: Text(course)))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCourse = value;
                      _selectedUserIds.clear();
                    });
                  },
                ),
              const SizedBox(height: 20),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Buscar usuario por nombre, correo o nómina',
                  border: OutlineInputBorder(),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _filterUsers('');
                    },
                  )
                      : const Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _filteredUsers.isEmpty
                    ? const Center(child: Text('No hay usuarios disponibles.'))
                    : ListView.builder(
                  itemCount: _filteredUsers.length,
                  itemBuilder: (context, index) {
                    final doc = _filteredUsers[index];
                    final data = doc.data();
                    final uid = data['id'];
                    final email = (data['email'] ?? '');
                    final nombre = (data['fullName'] ?? '');
                    final nomina = (data['nomina'] ?? '');
                    return CheckboxListTile(
                      title: Text(
                        (nombre != null && nombre.toString().isNotEmpty)
                            ? nombre
                            : email,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Row(
                        children: [
                          if (email.toString().isNotEmpty)
                            Flexible(
                              child: Text(
                                email,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          if (nomina.toString().isNotEmpty)
                            Flexible(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: Text(
                                  "Nómina: $nomina",
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                        ],
                      ),
                      value: _selectedUserIds.contains(uid),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedUserIds.add(uid);
                          } else {
                            _selectedUserIds.remove(uid);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.send),
                  label: const Text('Asignar Curso Masivamente'),
                  onPressed: _assignToAll,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
