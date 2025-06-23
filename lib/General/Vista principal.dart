import 'package:dashapp/Capacitaciones/screens/manager/manage_global_progress_screen.dart';
import 'package:dashapp/Utileria/global_exports.dart';



class HomeIntranetScreen extends StatefulWidget {
  final String role;
  const HomeIntranetScreen({super.key, required this.role});

  @override
  State<HomeIntranetScreen> createState() => _HomeIntranetScreenState();
}

class _HomeIntranetScreenState extends State<HomeIntranetScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (Route<dynamic> route) => false,
      );
    }
  }

  void _openNotificationsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NotificationsScreen(uid: currentUser!.uid),
      ),
    );
  }

  void _navigate(Widget page) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  @override
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

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: Text('No se encontraron permisos del usuario.')),
          );
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final role = userData['role'] ?? 'user';
        final estado = userData['estado'] ?? 'activo';

        if (estado != 'activo') {
          return Scaffold(
            body: Center(
              child: Text(
                'Tu cuenta está deshabilitada.\nContacta al administrador.',
                style: TextStyle(fontSize: 18, color: Colors.red[800]),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return _buildMainScaffold(role, backgroundGradient);
      },
    );
  }
  Widget _buildMainScaffold(String role, Gradient backgroundGradient) {

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: true,
        title: const Text(
          'CapacitacionesDCC',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('uid', isEqualTo: currentUser!.uid)
                .where('readByReceiver', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data?.docs.length ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none),
                    tooltip: 'Notificaciones',
                    onPressed: _openNotificationsScreen,
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          if (role == 'user')
            IconButton(
              icon: const Icon(Icons.manage_accounts),
              tooltip: 'Kardex',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UserCardexScreen(),
                  ),
                );
              },
            ),
          IconButton(
            icon: Icon(
              themeNotifier.value == ThemeMode.dark
                  ? Icons.wb_sunny_outlined
                  : Icons.nightlight_round,
            ),
            onPressed: () {
              themeNotifier.value =
              themeNotifier.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
              setState(() {});
            },
          ),
        ],
      ),
      drawer: role == 'admin'
          ? _buildAdminDrawer()
          : role == 'jefe'
          ? _buildManagerDrawer()
          : role == 'instructor'
          ? _buildInstructorDrawer()
          : _buildUserDrawer(),

      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: _buildBodyContent(),
      ),
    );
  }


  Widget _buildBodyContent() {
    if (currentUser == null) {
      return const Center(child: Text("Usuario no autenticado"));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('authorized_courses')
          .where('uid', isEqualTo: currentUser!.uid)
          .where('authorized', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final authorizedDocs = snapshot.data?.docs ?? [];
        if (authorizedDocs.isEmpty) {
          return const Center(
            child: Text(
              'Aún no se te ha asignado ninguna área.\nPor favor, contacta con el administrador.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          );
        }

        final Set<String> uniqueAreas = {};
        for (final doc in authorizedDocs) {
          final area = doc['area'] as String?;
          if (area != null) {
            uniqueAreas.add(area);
          }
        }

        final areasList = uniqueAreas.toList();

        return Padding(
          padding: const EdgeInsets.only(top: kToolbarHeight + 32),
          child: ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: areasList.length,
            itemBuilder: (context, index) {
              final area = areasList[index];

              return Card(
                elevation: 5,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  title: Text(
                    area,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CoursesByAreaScreen(area: area),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  Drawer _buildAdminDrawer() {
    final isDarkMode = themeNotifier.value == ThemeMode.dark;
    final drawerBackground = isDarkMode ? Colors.black : Colors.white;
    final drawerTextColor = isDarkMode ? Colors.white : Colors.black87;

    return Drawer(
      backgroundColor: drawerBackground,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Stack(
            children: [
              UserAccountsDrawerHeader(
                accountName: Text(
                  currentUser?.displayName ?? 'Administrador 👑',
                ),
                accountEmail: Text(currentUser?.email ?? ''),
                currentAccountPicture: CircleAvatar(
                  backgroundImage:
                  currentUser?.photoURL != null
                      ? NetworkImage(currentUser!.photoURL!)
                      : const AssetImage('assets/ds.png') as ImageProvider,
                ),
                decoration: const BoxDecoration(color: Colors.blueAccent),
              ),
              Positioned(
                bottom: 8,
                right: 12,
                child: IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white),
                  tooltip: 'Configuración de Perfil',
                  onPressed: () {
                    Navigator.pop(context); // Cierra el Drawer
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EditProfileScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          _buildDrawerItem(
            Icons.home,
            'Inicio',
                () => _navigate(const HomeIntranetScreen(role: '',)),
            drawerTextColor,
          ),
          ExpansionTile(
            leading: Icon(Icons.school, color: drawerTextColor),
            title: Text(
              'Administrar capacitaciones',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: drawerTextColor,
              ),
            ),
            collapsedIconColor: drawerTextColor,
            iconColor: drawerTextColor,
            children: [
              _buildDrawerItem(
                Icons.manage_accounts,
                'Administrar Áreas',
                    () => _navigate(const ManageAreasAndCoursesScreen()),
                drawerTextColor,
              ),
              _buildDrawerItem(
                Icons.video_collection,
                'Contenido de Cursos',
                    () => _navigate(const AdminResourcesScreen()),
                drawerTextColor,
              ),
              _buildDrawerItem(
                Icons.settings_accessibility,
                'Acceso a Cursos',
                    () => _navigate(const ManageCourseAccessScreen()),
                drawerTextColor,
              ),
              _buildDrawerItem(
                Icons.edit_document,
                'Administrar Exámenes',
                    () => _navigate(const AdminExamManagerScreen()),
                drawerTextColor,
              ),
              _buildDrawerItem(
                Icons.assignment,
                'Resultados de Exámenes',
                    () => _navigate(const ExamResultsScreen()),
                drawerTextColor,
              ),
              _buildDrawerItem(
                Icons.group,
                'Progreso General',
                    () => _navigate(const GlobalProgressScreen()),
                drawerTextColor,
              ),
              _buildDrawerItem(
                Icons.supervisor_account,
                'Gestionar Usuarios',
                    () => _navigate(const AdminManageUsersScreen()),
                drawerTextColor,
              ),
              _buildDrawerItem(
                Icons.description,
                'Kardex',
                    () => _navigate(const CardexScreen()),
                drawerTextColor,
              ),
            ],
          ),
          const Divider(),
          ExpansionTile(
            leading: Icon(Icons.fingerprint, color: drawerTextColor),
            title: Text(
              'Administrar Huellas',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: drawerTextColor,
              ),
            ),
            collapsedIconColor: drawerTextColor,
            iconColor: drawerTextColor,
            children: [
              _buildDrawerItem(
                Icons.settings,
                'Subir checadas pendientes',
                    () async {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ConfiguracionSubidasScreen()),
                  );
                },
                drawerTextColor,
              ),
              _buildDrawerItem(
                Icons.history,
                'Registros de Checadas',
                    () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ResumenChecadasScreen()),
                ),
                drawerTextColor,
              ),
            ],
          ),
          const Divider(),
          _buildDrawerItem(
            Icons.logout,
            'Cerrar Sesión',
            _logout,
            drawerTextColor,
          ),
        ],
      ),
    );
  }

  Drawer _buildManagerDrawer() {
    final isDarkMode = themeNotifier.value == ThemeMode.dark;
    final drawerBackground = isDarkMode ? Colors.black : Colors.white;
    final drawerTextColor = isDarkMode ? Colors.white : Colors.black87;

    return Drawer(
      backgroundColor: drawerBackground,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Stack(
            children: [
              UserAccountsDrawerHeader(
                accountName: Text(currentUser?.displayName ?? 'Jefe de área'),
                accountEmail: Text(currentUser?.email ?? ''),
                currentAccountPicture: CircleAvatar(
                  backgroundImage:
                  currentUser?.photoURL != null
                      ? NetworkImage(currentUser!.photoURL!)
                      : const AssetImage('assets/ds.png') as ImageProvider,
                ),
                decoration: const BoxDecoration(color: Colors.blueAccent),
              ),
              Positioned(
                bottom: 8,
                right: 12,
                child: IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white),
                  tooltip: 'Configuración de Perfil',
                  onPressed: () {
                    Navigator.pop(context); // Cierra el Drawer
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EditProfileScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          _buildDrawerItem(
            Icons.assignment_ind,
            'Asignar Cursos Área',
                () => _navigate(const AssignAreaCoursesScreen()),
            drawerTextColor,
          ),
          _buildDrawerItem(
            Icons.group,
            'Ver Progreso General',
                () => _navigate(const ManageGlobalProgressScreen()),
            drawerTextColor,
          ),
          _buildDrawerItem(
            Icons.logout,
            'Cerrar Sesión',
            _logout,
            drawerTextColor,
          ),
        ],
      ),
    );
  }

  Drawer _buildInstructorDrawer() {
    final isDarkMode = themeNotifier.value == ThemeMode.dark;
    final drawerBackground = isDarkMode ? Colors.black : Colors.white;
    final drawerTextColor = isDarkMode ? Colors.white : Colors.black87;

    return Drawer(
      backgroundColor: drawerBackground,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Stack(
            children: [
              UserAccountsDrawerHeader(
                accountName: Text(currentUser?.displayName ?? 'Instructor'),
                accountEmail: Text(currentUser?.email ?? ''),
                currentAccountPicture: CircleAvatar(
                  backgroundImage:
                  currentUser?.photoURL != null
                      ? NetworkImage(currentUser!.photoURL!)
                      : const AssetImage('assets/ds.png') as ImageProvider,
                ),
                decoration: const BoxDecoration(color: Colors.blueAccent),
              ),
              Positioned(
                bottom: 8,
                right: 12,
                child: IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white),
                  tooltip: 'Configuración de Perfil',
                  onPressed: () {
                    Navigator.pop(context); // Cierra el Drawer
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EditProfileScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          _buildDrawerItem(
            Icons.edit,
            'Administrar Contenido de Área',
                () => _navigate(const ManageInstructorCoursesScreen()),
            drawerTextColor,
          ),
          _buildDrawerItem(
            Icons.logout,
            'Cerrar Sesión',
            _logout,
            drawerTextColor,
          ),
        ],
      ),
    );
  }

  Drawer _buildUserDrawer() {
    final isDarkMode = themeNotifier.value == ThemeMode.dark;
    final drawerBackground = isDarkMode ? Colors.black : Colors.white;
    final drawerTextColor = isDarkMode ? Colors.white : Colors.black87;

    return Drawer(
      backgroundColor: drawerBackground,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(currentUser?.displayName ?? 'Usuario'),
            accountEmail: Text(currentUser?.email ?? ''),
            currentAccountPicture: CircleAvatar(
              backgroundImage: currentUser?.photoURL != null
                  ? NetworkImage(currentUser!.photoURL!)
                  : const AssetImage('assets/ds.png') as ImageProvider,
            ),
            decoration: const BoxDecoration(color: Colors.blueAccent),
          ),
          _buildDrawerItem(
            Icons.settings,
            'Configuración de Perfil',
                () => _navigate(const EditProfileScreen()),
            drawerTextColor,
          ),
          _buildDrawerItem(
            Icons.logout,
            'Cerrar Sesión',
            _logout,
            drawerTextColor,
          ),
        ],
      ),
    );
  }

  ListTile _buildDrawerItem(
      IconData icon,
      String title,
      VoidCallback onTap,
      Color textColor,
      ) {
    return ListTile(
      leading: Icon(icon, color: textColor),
      title: Text(title, style: TextStyle(color: textColor)),
      onTap: onTap,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _CardItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _CardItem({required this.title, required this.subtitle, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.indigo),
        title: Text(title),
        subtitle: Text(subtitle),
        onTap: onTap,
      ),
    );
  }
}


