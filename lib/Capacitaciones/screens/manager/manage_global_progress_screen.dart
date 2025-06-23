import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:dashapp/Capacitaciones/services/theme_notifier.dart';

class ManageGlobalProgressScreen extends StatefulWidget {
  const ManageGlobalProgressScreen({Key? key}) : super(key: key);

  @override
  State<ManageGlobalProgressScreen> createState() => _ManageGlobalProgressScreenState();
}

class _ManageGlobalProgressScreenState extends State<ManageGlobalProgressScreen> {
  String? _selectedCategory;
  String _searchUser = '';
  String? _jefeArea;
  List<UserProgressGeneral> _allUsers = [];

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadJefeAreaAndProgress();
  }

  Future<void> _loadJefeAreaAndProgress() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final area = userDoc.data()?['area'];
    if (area == null) return;

    final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
    final authorizedSnapshot = await FirebaseFirestore.instance.collection('authorized_courses').get();
    final contentSnapshot = await FirebaseFirestore.instance.collection('contents').get();
    final viewsSnapshot = await FirebaseFirestore.instance.collection('content_views').get();

    final users = {
      for (var doc in usersSnapshot.docs)
        if (doc.data()['area'] == area)
          doc.id: doc.data()['email'] ?? 'Desconocido',
    };

    final contentByCategory = <String, List<String>>{};
    for (var doc in contentSnapshot.docs) {
      final category = doc.data()['category'] ?? 'Sin categoría';
      contentByCategory.putIfAbsent(category, () => []).add(doc.id);
    }

    final viewsGrouped = <String, Set<String>>{};
    for (var doc in viewsSnapshot.docs) {
      final uid = doc.data()['uid'];
      final contentId = doc.data()['contentId'];
      viewsGrouped.putIfAbsent(uid, () => {}).add(contentId);
    }

    final Map<String, Map<String, double>> userProgress = {};
    final Set<String> allCategoriesSet = {};

    for (var auth in authorizedSnapshot.docs) {
      final uid = auth.data()['uid'];
      final category = auth.data()['category'];
      final authorized = auth.data()['authorized'] ?? false;

      if (!authorized || !users.containsKey(uid)) continue;

      allCategoriesSet.add(category);

      final userViews = viewsGrouped[uid] ?? {};
      final contents = contentByCategory[category] ?? [];

      double progress = contents.isEmpty ? 0 : userViews.where((v) => contents.contains(v)).length / contents.length;
      userProgress.putIfAbsent(uid, () => {})[category] = progress;
    }

    setState(() {
      _jefeArea = area;
      _allUsers = userProgress.entries.map((entry) {
        final uid = entry.key;
        final courses = entry.value;
        return UserProgressGeneral(email: users[uid] ?? 'Desconocido', courses: courses);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = themeNotifier.value == ThemeMode.dark;
    final backgroundGradient = isDarkMode
        ? const LinearGradient(colors: [Color(0xFF0F2027), Color(0xFF2C5364)], begin: Alignment.topCenter, end: Alignment.bottomCenter)
        : const LinearGradient(colors: [Color(0xFFE0E0E0), Color(0xFFFFFFFF)], begin: Alignment.topCenter, end: Alignment.bottomCenter);

    final filteredUsers = _allUsers.where((user) {
      final matchesCategory = _selectedCategory == null || user.courses.containsKey(_selectedCategory);
      final matchesEmail = user.email.toLowerCase().contains(_searchUser.toLowerCase());
      return matchesCategory && matchesEmail;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Progreso por Área')),
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: _jefeArea == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              labelText: 'Buscar por correo',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _searchUser = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: filteredUsers.isEmpty
                        ? const Center(child: Text('No se encontraron usuarios.'))
                        : ListView.builder(
                            itemCount: filteredUsers.length,
                            itemBuilder: (context, index) {
                              final user = filteredUsers[index];
                              final coursesToShow = user.courses.entries.where((entry) {
                                return _selectedCategory == null || entry.key == _selectedCategory;
                              });

                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                elevation: 4,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(user.email, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      const SizedBox(height: 8),
                                      ...coursesToShow.map((entry) {
                                        final percent = (entry.value * 100).round();
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(entry.key, style: const TextStyle(fontSize: 14)),
                                            const SizedBox(height: 4),
                                            LinearProgressIndicator(
                                              value: entry.value,
                                              backgroundColor: Colors.grey[300],
                                              color: entry.value >= 1.0 ? Colors.blue : Colors.green,
                                              minHeight: 8,
                                            ),
                                            const SizedBox(height: 4),
                                            Text('$percent% completado'),
                                            const SizedBox(height: 12),
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
