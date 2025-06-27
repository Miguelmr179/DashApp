import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:dashapp/Capacitaciones/models/user.dart';
import 'package:dashapp/Capacitaciones/services/area_service.dart';
import 'package:dashapp/Capacitaciones/services/theme_notifier.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminManageUsersScreen extends StatefulWidget {
  const AdminManageUsersScreen({Key? key}) : super(key: key);

  @override
  State<AdminManageUsersScreen> createState() => _AdminManageUsersScreenState();
}

class _AdminManageUsersScreenState extends State<AdminManageUsersScreen> {

  final AreaService _areaService = AreaService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final List<String> _roles = ['user', 'instructor', 'jefe', 'admin'];

  List<String> _areas = [];

  String _searchQuery = '';
  String _nominaQuery = '';
  String _nameQuery = '';
  String? _selectedRoleFilter;

  int _activeFilter = 0; // 0 = email, 1 = nómina, 2 = nombre

  @override
  void initState() {
    super.initState();
    _loadAreas();
  }

  Future<void> _loadAreas() async {
    final areas = await _areaService.getAllAreas();
    setState(() {
      _areas = areas;
    });
  }

  Future<void> _addNewArea() async {
    String newArea = '';
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nueva Área'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Nombre del Área'),
            onChanged: (value) {
              newArea = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (newArea.trim().isEmpty) return;
                await _areaService.addArea(newArea.trim());
                await _loadAreas();
                Navigator.pop(context);
              },
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateUserRole(String uid, String role) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'role': role,
    });
  }

  Future<void> _updateUserArea(String uid, String? area) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'area': area,
    });
  }

  Future<void> _editUserInfo(UserModel user) async {
    String updatedName = user.fullName ?? '';
    String updatedNomina = user.nomina ?? '';

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar información del usuario'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: TextEditingController(text: updatedName),
                onChanged: (value) => updatedName = value,
                decoration: const InputDecoration(labelText: 'Nombre completo'),
              ),
              TextField(
                controller: TextEditingController(text: updatedNomina),
                onChanged: (value) => updatedNomina = value,
                decoration: const InputDecoration(labelText: 'Número de nómina'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.id)
                    .update({
                  'fullName': updatedName.trim(),
                  'nomina': updatedNomina.trim(),
                });
                Navigator.pop(context);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteUser(String uid, String email) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Estás seguro de eliminar la cuenta de "$email"? Esto eliminará al usuario tanto de Firestore como de Firebase Auth.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).delete();
        final methods = await _auth.fetchSignInMethodsForEmail(email);
        if (methods.isNotEmpty) {
          await FirebaseAuth.instance.currentUser?.delete();
        }
      } catch (e) {
        debugPrint('Error al eliminar usuario: $e');
      }
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _userStream() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('users');

    if (_activeFilter == 0 && _searchQuery.trim().isNotEmpty) {
      query = query
          .where('email', isGreaterThanOrEqualTo: _searchQuery.trim())
          .where('email', isLessThanOrEqualTo: '${_searchQuery.trim()}');
    } else if (_activeFilter == 1 && _nominaQuery.trim().isNotEmpty) {
      query = query
          .where('nomina', isGreaterThanOrEqualTo: _nominaQuery.trim())
          .where('nomina', isLessThanOrEqualTo: '${_nominaQuery.trim()}');
    } else if (_activeFilter == 2 && _nameQuery.trim().isNotEmpty) {
      query = query
          .where('fullName', isGreaterThanOrEqualTo: _nameQuery.trim())
          .where('fullName', isLessThanOrEqualTo: '${_nameQuery.trim()}');
    }

    if (_selectedRoleFilter != null && _selectedRoleFilter != 'Todos') {
      query = query.where('role', isEqualTo: _selectedRoleFilter);
    }

    return query.snapshots();
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
      appBar: AppBar(
        title: const Text('Gestionar Usuarios y Áreas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Agregar Nueva Área',
            onPressed: _addNewArea,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  // Filter selector
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, icon: Icon(Icons.email), label: Text('Email')),
                      ButtonSegment(value: 1, icon: Icon(Icons.badge), label: Text('Nómina')),
                      ButtonSegment(value: 2, icon: Icon(Icons.person), label: Text('Nombre')),
                    ],
                    selected: {_activeFilter},
                    onSelectionChanged: (Set<int> newSelection) {
                      setState(() {
                        _activeFilter = newSelection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  // Search field based on selected filter
                  if (_activeFilter == 0)
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Buscar por correo',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  if (_activeFilter == 1)
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Buscar por nómina',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _nominaQuery = value;
                        });
                      },
                    ),
                  if (_activeFilter == 2)
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Buscar por nombre',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _nameQuery = value;
                        });
                      },
                    ),
                  const SizedBox(height: 8),
                  // Role filter dropdown
                  Row(
                    children: [
                      const Text('Filtrar por rol: '),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _selectedRoleFilter ?? 'Todos',
                        items: [
                          const DropdownMenuItem(
                            value: 'Todos',
                            child: Text('Todos'),
                          ),
                          ..._roles.map(
                                (role) => DropdownMenuItem(
                              value: role,
                              child: Text(role[0].toUpperCase() + role.substring(1)),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedRoleFilter = value == 'Todos' ? null : value;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _userStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No hay usuarios disponibles.'));
                  }

                  final users = snapshot.data!.docs;

                  return ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = UserModel.fromJson(users[index].data());
                      final userData = users[index].data();

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.fullName != null && user.fullName!.trim().isNotEmpty
                                              ? user.fullName!
                                              : user.email,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        if (user.nomina != null && user.nomina!.trim().isNotEmpty)
                                          Text(
                                            'Nómina: ${user.nomina}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (option) {
                                      if (option == 'editar') {
                                        _editUserInfo(user);
                                      } else if (option == 'eliminar') {
                                        _deleteUser(user.id, user.email);
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: 'editar',
                                        child: Text('Editar'),
                                      ),
                                      PopupMenuItem(
                                        value: 'eliminar',
                                        child: Text('Eliminar'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Text('Rol: '),
                                  DropdownButton<String>(
                                    value: user.role ?? 'user',
                                    items: const [
                                      DropdownMenuItem(value: 'user', child: Text('Usuario')),
                                      DropdownMenuItem(value: 'instructor', child: Text('Instructor')),
                                      DropdownMenuItem(value: 'jefe', child: Text('Jefe')),
                                      DropdownMenuItem(value: 'admin', child: Text('Administrador')),
                                    ],
                                    onChanged: (newRole) async {
                                      if (newRole != null && newRole != user.role) {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Confirmar cambio de rol'),
                                            content: Text('¿Estás seguro de cambiar el rol de este usuario a "$newRole"?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, false),
                                                child: const Text('Cancelar'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () => Navigator.pop(context, true),
                                                child: const Text('Confirmar'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          await _updateUserRole(user.id, newRole);
                                          if (newRole == 'user') {
                                            await _updateUserArea(user.id, null);
                                          }
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Text('Área: '),
                                  DropdownButton<String>(
                                    value: (user.role == 'user' || user.role == 'admin') ? null : user.area,
                                    hint: const Text('Sin área'),
                                    items: _areas.map((area) {
                                      return DropdownMenuItem(
                                        value: area,
                                        child: Text(area),
                                      );
                                    }).toList(),
                                    onChanged: (user.role == 'user' || user.role == 'admin')
                                        ? null
                                        : (newArea) {
                                      _updateUserArea(user.id, newArea);
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Estado: '),
                                  Row(
                                    children: [
                                      Text(
                                        (userData['activo'] ?? false) ? 'Activo' : 'Inactivo',
                                        style: TextStyle(
                                          color: (userData['activo'] ?? false) ? Colors.green : Colors.red,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Switch(
                                        value: userData['activo'] == true,
                                        onChanged: (value) async {
                                          final userRef = FirebaseFirestore.instance.collection('users').doc(user.id);
                                          if (value) {
                                            await userRef.set({'activo': true}, SetOptions(merge: true));
                                          } else {
                                            await userRef.update({'activo': FieldValue.delete()});
                                          }
                                          setState(() {});
                                        },
                                      ),
                                    ],
                                  ),
                                ],
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
      ),
    );
  }
}