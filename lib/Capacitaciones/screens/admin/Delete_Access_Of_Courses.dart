import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dashapp/Capacitaciones/services/theme_notifier.dart';

class ViewCourseAccessScreen extends StatefulWidget {
  const ViewCourseAccessScreen({Key? key}) : super(key: key);

  @override
  _ViewCourseAccessScreenState createState() => _ViewCourseAccessScreenState();
}

class _ViewCourseAccessScreenState extends State<ViewCourseAccessScreen> {

  late Future<Map<String, Map<String, dynamic>>> _usersFuture;
  late Future<List<Map<String, dynamic>>> _accessFuture;

  String _searchQuery = '';

  List<Map<String, dynamic>> _allAccesses = [];
  List<Map<String, dynamic>> _filterAccesses(String query) {
    if (query.isEmpty) return _allAccesses;
    final lowerQuery = query.toLowerCase();
    return _allAccesses.where((access) {
      final uid = access['uid'];
      final user = _userData[uid] ?? {};
      final email = (user['email'] ?? '').toString().toLowerCase();
      final fullName = (user['fullName'] ?? '').toString().toLowerCase();
      final nomina = (user['nomina'] ?? '').toString().toLowerCase();
      return email.contains(lowerQuery) ||
          fullName.contains(lowerQuery) ||
          nomina.contains(lowerQuery);
    }).toList();
  }

  Map<String, Map<String, dynamic>> _userData = {}; // uid -> {email, fullName, nomina}

  @override
  void initState() {
    super.initState();
    _usersFuture = _fetchUsers();
    _accessFuture = _fetchAccesses();
  }

  Future<Map<String, Map<String, dynamic>>> _fetchUsers() async {
    final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
    final users = <String, Map<String, dynamic>>{};
    for (var doc in usersSnapshot.docs) {
      final data = doc.data();
      users[doc.id] = {
        'email': data['email'] ?? 'Desconocido',
        'fullName': data['fullName'] ?? '',
        'nomina': data['nomina'] ?? '',
      };
    }
    _userData = users;
    return users;
  }

  Future<List<Map<String, dynamic>>> _fetchAccesses() async {
    final snapshot = await FirebaseFirestore.instance.collection('authorized_courses').get();
    final accesses = <Map<String, dynamic>>[];
    for (var doc in snapshot.docs) {
      final data = doc.data();
      accesses.add({
        'docId': doc.id,
        'uid': data['uid'],
        'category': data['category'],
      });
    }
    _allAccesses = accesses;
    return accesses;
  }

  Future<void> _removeAccess(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('authorized_courses').doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Acceso eliminado.')),
      );
      setState(() {
        _accessFuture = _fetchAccesses();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _confirmRemoveAccess(String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmar eliminación'),
        content: const Text('¿Eliminar este permiso?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _removeAccess(docId);
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
        centerTitle: true,
        title: const Text(
          'Eliminar acceso a Cursos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: Column(
          children: [
            const SizedBox(height: kToolbarHeight + 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Card(
                elevation: 6,
                color: isDarkMode ? Colors.black54 : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Buscar por correo, nombre o nómina',
                      border: InputBorder.none,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                          : null,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder(
                future: Future.wait([_usersFuture, _accessFuture]),
                builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  } else if (!snapshot.hasData || (snapshot.data?[1] as List).isEmpty) {
                    return const Center(child: Text('No hay permisos asignados.'));
                  } else {
                    final accesses = _filterAccesses(_searchQuery);
                    if (accesses.isEmpty) {
                      return const Center(child: Text('No se encontraron resultados.'));
                    }

                    // Agrupa por usuario
                    final Map<String, List<Map<String, dynamic>>> grouped = {};
                    for (final access in accesses) {
                      final uid = access['uid'];
                      final user = _userData[uid] ?? {};
                      final email = user['email'] ?? 'Desconocido';
                      grouped.putIfAbsent(email, () => []);
                      grouped[email]!.add({
                        'category': access['category'],
                        'docId': access['docId'],
                        'fullName': user['fullName'] ?? '',
                        'nomina': user['nomina'] ?? '',
                      });
                    }

                    return ListView(
                      padding: const EdgeInsets.only(bottom: 22),
                      children: grouped.entries.map((entry) {
                        final email = entry.key;
                        final courses = entry.value;
                        final first = courses.first;

                        return Card(
                          elevation: 5,
                          color: isDarkMode ? Colors.black45 : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.person, color: Colors.deepPurple),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            email,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: isDarkMode ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                          if ((first['fullName'] ?? '').toString().isNotEmpty)
                                            Text(
                                              'Nombre: ${first['fullName']}',
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                color: isDarkMode ? Colors.white70 : Colors.black54,
                                              ),
                                            ),
                                          if ((first['nomina'] ?? '').toString().isNotEmpty)
                                            Text(
                                              'Nómina: ${first['nomina']}',
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                color: isDarkMode ? Colors.white70 : Colors.black54,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ...courses.map((c) => Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '• ${c['category']}',
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: isDarkMode ? Colors.white70 : Colors.black87,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                                      tooltip: "Eliminar acceso",
                                      onPressed: () => _confirmRemoveAccess(c['docId']),
                                    ),
                                  ],
                                )),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
