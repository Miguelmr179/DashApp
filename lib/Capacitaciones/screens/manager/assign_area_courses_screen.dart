import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AssignAreaCoursesScreen extends StatefulWidget {
  const AssignAreaCoursesScreen({Key? key}) : super(key: key);

  @override
  State<AssignAreaCoursesScreen> createState() =>
      _AssignAreaCoursesScreenState();
}

class _AssignAreaCoursesScreenState extends State<AssignAreaCoursesScreen> {
  String? _area;
  Map<String, String> _assignedUsers = {}; // uid -> docId
  String _searchText = '';
  String _filter = 'Todos'; // 'Todos', 'Asignados', 'No asignados'

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAreaAndCourse();
  }

  Future<void> _loadAreaAndCourse() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final area = userDoc.data()?['area'];
    if (area == null) return;

    final courseQuery = await FirebaseFirestore.instance
        .collection('contents')
        .where('category', isEqualTo: area)
        .limit(1)
        .get();

    if (courseQuery.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se encontró un curso con el título "$area"'),
        ),
      );
      return;
    }

    final assignedQuery = await FirebaseFirestore.instance
        .collection('authorized_courses')
        .where('category', isEqualTo: area)
        .get();

    final assigned = {
      for (var doc in assignedQuery.docs) doc['uid'] as String: doc.id,
    };

    setState(() {
      _area = area;
      _assignedUsers = assigned;
    });
  }

  Future<void> _assignUserToCourse(String uid) async {
    if (_area == null) return;

    final docRef = await FirebaseFirestore.instance
        .collection('authorized_courses')
        .add({'authorized': true, 'uid': uid, 'category': _area});

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'area': _area});

    setState(() {
      _assignedUsers[uid] = docRef.id;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Curso asignado y área actualizada')),
    );
  }

  Future<void> _removeUserFromCourse(String uid) async {
    final docId = _assignedUsers[uid];
    if (docId == null) return;

    await FirebaseFirestore.instance
        .collection('authorized_courses')
        .doc(docId)
        .delete();

    setState(() {
      _assignedUsers.remove(uid);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Curso eliminado')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_area == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text('Asignar curso: $_area')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Buscar por correo',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchText = value.toLowerCase();
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: DropdownButtonFormField<String>(
              value: _filter,
              items: const [
                DropdownMenuItem(value: 'Todos', child: Text('Todos')),
                DropdownMenuItem(value: 'Asignados', child: Text('Asignados')),
                DropdownMenuItem(value: 'No asignados', child: Text('No asignados')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _filter = value;
                  });
                }
              },
              decoration: const InputDecoration(
                labelText: 'Filtrar por estado',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final users = snapshot.data!.docs.where((user) {
                  final email = (user['email'] ?? '').toString().toLowerCase();
                  final uid = user.id;
                  final isAssigned = _assignedUsers.containsKey(uid);

                  final matchesSearch = email.contains(_searchText);

                  if (_filter == 'Asignados' && !isAssigned) return false;
                  if (_filter == 'No asignados' && isAssigned) return false;

                  return matchesSearch;
                }).toList();

                if (users.isEmpty) {
                  return const Center(child: Text('No se encontraron usuarios.'));
                }

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final uid = user.id;
                    final email = user['email'] ?? 'Sin email';
                    final isAssigned = _assignedUsers.containsKey(uid);

                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        title: Text(email),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isAssigned)
                              const Icon(Icons.check_circle, color: Colors.green),
                            const SizedBox(width: 8),
                            isAssigned
                                ? IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    tooltip: 'Eliminar curso',
                                    onPressed: () => _removeUserFromCourse(uid),
                                  )
                                : ElevatedButton(
                                    onPressed: () => _assignUserToCourse(uid),
                                    child: const Text('Asignar'),
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
        ],
      ),
    );
  }
}
