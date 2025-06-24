import 'dart:async';
import 'dart:ui';
import 'package:dashapp/General/agregar%20foto%20por%20usuario.dart';
import 'package:dashapp/General/agregar_Noticias.dart';
import 'package:dashapp/Utileria/global_exports.dart';
import 'package:intl/intl.dart';
import 'manager/manage_global_progress_screen.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:dashapp/General/agregar_eventos.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class HomeScreen extends StatefulWidget {
  final String role;
  const HomeScreen({super.key, required this.role});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late PageController _pageController;
  Timer? _autoPageTimer;

  final currentUser = FirebaseAuth.instance.currentUser;
  bool _mostrarCursos = false;
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

  int _lastPageCount = 1;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.95);

    _autoPageTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_pageController.hasClients) {
        final nextPage = _pageController.page!.round() + 1;
        _pageController.animateToPage(
          (nextPage % (_lastPageCount == 0 ? 1 : _lastPageCount)) as int,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _autoPageTimer?.cancel();
    _pageController.dispose();
    super.dispose();
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

    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance
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
            body: Center(
              child: Text('No se encontraron permisos del usuario.'),
            ),
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
            stream:
                FirebaseFirestore.instance
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
                  MaterialPageRoute(builder: (_) => const UserCardexScreen()),
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
                  themeNotifier.value == ThemeMode.dark
                      ? ThemeMode.light
                      : ThemeMode.dark;
              setState(() {});
            },
          ),
        ],
      ),
      drawer:
          role == 'admin'
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

    if (_mostrarCursos) {
      return _buildCursosBody();
    } else {
      return _buildVistaIntranet();
    }
  }

  Widget _buildCursosBody() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
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
          if (area != null) uniqueAreas.add(area);
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

  Widget _seccionTitulo(String texto) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildVistaIntranet() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 55, bottom: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 2000),
                  child:
                      isWide
                          ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.center,
                                  children: [
                                    _seccionTitulo('📰 Anuncios'),
                                    SizedBox(
                                      height: 400,
                                      child: _buildCarruselAnuncios(),
                                    ),
                                    const SizedBox(height: 80),
                                    _seccionTitulo('📅 Próximos eventos'),
                                    _buildEventos(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              // Columna derecha: Cumpleaños
                              Expanded(
                                flex: 1,
                                child: Column(
                                  children: [
                                    Align(
                                      alignment: Alignment.center,
                                      child: Text(
                                        '🎂 Cumpleaños del mes',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      constraints: const BoxConstraints(minHeight: 400),
                                      child: _buildCumpleanios(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                          : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _seccionTitulo('📰 Anuncios'),
                              SizedBox(
                                height: 400,
                                child: _buildCarruselAnuncios(),
                              ),
                              const SizedBox(height: 24),
                              _seccionTitulo('🎂 Cumpleaños del mes'),
                              _buildCumpleanios(),
                              const SizedBox(height: 24),
                              _seccionTitulo('📅 Próximos eventos'),
                              _buildEventos(),
                            ],
                          ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCumpleanios() {
    final hoy = DateTime.now();
    final mesActual = hoy.month;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('Usuarios').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final cumpleanieros = snapshot.data?.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final cumpleStr = data['fechaIng'] ?? '';
          if (cumpleStr.isEmpty) return false;

          try {
            final cumple = DateFormat("d MMMM yyyy", "es_MX").parseLoose(cumpleStr);
            return cumple.month == mesActual;
          } catch (e) {
            return false;
          }
        }).toList();

        if (cumpleanieros == null || cumpleanieros.isEmpty) {
          return const Center(child: Text('No hay cumpleaños este mes.'));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cumpleanieros.length,
          itemBuilder: (context, index) {
            final doc = cumpleanieros[index];
            final data = doc.data() as Map<String, dynamic>;
            final nombre = data['nombre'] ?? 'Sin nombre';
            final cumpleStr = data['fechaIng'] ?? '';

            String fechaStr = 'Sin fecha';
            try {
              final cumple = DateFormat("d MMMM yyyy", "es_MX").parseLoose(cumpleStr);
              fechaStr = DateFormat('dd MMMM', 'es_MX').format(cumple);
            } catch (_) {}

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade100, Colors.blue.shade300],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.shade400,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(12),
                      child: const Icon(
                        Icons.cake,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nombre,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '🎉 Cumple el $fechaStr',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCarruselAnuncios() {
    return Center(
      child: SizedBox(
        width: double.infinity,
        height: 400,
        child: StreamBuilder<QuerySnapshot>(
          stream:
              FirebaseFirestore.instance
                  .collection('noticias')
                  .orderBy('timestamp', descending: true)
                  .limit(10)
                  .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'No hay noticias disponibles',
                    style: TextStyle(color: Colors.grey, fontSize: 18),
                  ),
                ),
              );
            }

            _lastPageCount = docs.length;

            return CarouselSlider.builder(
              itemCount: docs.length,
              options: CarouselOptions(
                enlargeFactor: 0.6,
                pageSnapping: true,
                height: 400,
                autoPlay: true,
                enlargeCenterPage: true,
                viewportFraction: 0.95,
                autoPlayInterval: const Duration(seconds: 6),
                enableInfiniteScroll: true,
                scrollPhysics: const BouncingScrollPhysics(),
              ),
              itemBuilder: (context, index, realIndex) {
                final data = docs[index].data() as Map<String, dynamic>;
                final imagenUrl = data['imagenUrl'] as String?;
                final titulo = data['titulo'] ?? 'Sin título';
                final contenido = data['contenido'] ?? '';
                final fecha = DateFormat(
                  'dd MMM yyyy • hh:mm a',
                  'es_MX',
                ).format((data['timestamp'] as Timestamp).toDate());

                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Imagen de fondo
                        if (imagenUrl != null)
                          Image.network(
                            imagenUrl,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.fill,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value:
                                      progress.expectedTotalBytes != null
                                          ? progress.cumulativeBytesLoaded /
                                              progress.expectedTotalBytes!
                                          : null,
                                ),
                              );
                            },
                            errorBuilder:
                                (_, __, ___) => Container(
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      size: 50,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                          )
                        else
                          Container(color: Colors.grey[300]),

                        // Capa oscura
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.7),
                              ],
                              stops: const [0.5, 1.0],
                            ),
                          ),
                        ),

                        // Contenido
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            margin: const EdgeInsets.all(20),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  titulo,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    height: 1.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  contenido,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 16,
                                    height: 1.4,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  fecha,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
    );
  }

  Widget _buildEventos() {
    final hoy = DateTime.now();
    final hoyDesdeCero = DateTime(hoy.year, hoy.month, hoy.day);


    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('eventos')
          .where('fecha', isGreaterThanOrEqualTo: hoyDesdeCero)
          .orderBy('fecha')
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final eventos = snapshot.data?.docs ?? [];

        if (eventos.isEmpty) {
          return const Center(child: Text('No hay eventos próximos.'));
        }

        return SizedBox(
          height: 220,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              scrollbars: true,
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
              },
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: eventos.length,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemBuilder: (context, index) {
                final doc = eventos[index];
                final data = doc.data() as Map<String, dynamic>;
                final titulo = data['titulo'] ?? 'Evento';
                final descripcion = data['descripcion'] ?? '';
                final fecha = (data['fecha'] as Timestamp).toDate();
                final fechaStr = DateFormat('dd MMM yyyy', 'es_MX').format(fecha);

                return Container(
                  width: 280,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  child: Card(
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.grey.shade500, Colors.grey.shade300],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade700,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(10),
                            child: const Icon(
                              Icons.event,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fechaStr,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  titulo,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  descripcion,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
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
          const Divider(),
          _buildDrawerItem(Icons.home, 'Inicio', () {
            setState(() {
              _mostrarCursos = false;
            });
            Navigator.pop(context);
          }, drawerTextColor),
          _buildDrawerItem(Icons.post_add, 'Agregar anuncio', () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AgregarNoticiaScreen()),
            );
          }, drawerTextColor),
          if (kIsWeb)
            _buildDrawerItem(Icons.person_add, 'Agregar foto de usuario', () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdministrarFotosUsuariosScreen(),
                ),
              );
            }, drawerTextColor),
          _buildDrawerItem(Icons.post_add, 'Agregar eventos', () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AgregarEventoScreen(),
              ),
            );
          }, drawerTextColor),
          const Divider(),

          _buildDrawerItem(Icons.school, 'Capacitaciones', () {
            setState(() {
              _mostrarCursos = true;
            });
            Navigator.pop(context); // cierra el drawer
          }, drawerTextColor),

          const Divider(),

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
                    MaterialPageRoute(
                      builder: (_) => const ConfiguracionSubidasScreen(),
                    ),
                  );
                },
                drawerTextColor,
              ),
              _buildDrawerItem(
                Icons.history,
                'Registros de Checadas',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ResumenChecadasScreen(),
                  ),
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
              backgroundImage:
                  currentUser?.photoURL != null
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
