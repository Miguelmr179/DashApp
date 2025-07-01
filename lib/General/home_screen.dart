import 'dart:async';
import 'package:dashapp/Utileria/global_exports.dart';

import 'package:intl/intl.dart';


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

  int _lastPageCount = 1;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.95);

    _autoPageTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_pageController.hasClients) {
        final nextPage = _pageController.page!.round() + 1;
        _pageController.animateToPage(
          (nextPage % (_lastPageCount == 0 ? 1 : _lastPageCount)),
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

      appBar: AppBar(
        backgroundColor: Colors.blueAccent.shade400,
        elevation: 0,
        automaticallyImplyLeading: true,
        title: const Text(
          'Bienvenido',
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
              : role == 'nominas'
              ? _buildnominasDrawer()
              : role == 'incidencias'
              ? _buildIncidenciasDrawer()
              : role == 'capacitaciones'
              ? _buildCapacitacionesDrawer()
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

  Widget _seccionCumpleaniosDelDia() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('UsuariosDcc').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox();
        }

        final hoy = DateTime.now();

        final cumpleanierosHoy = snapshot.data?.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final cumpleStr = data['fechaNac'] ?? '';
          if (cumpleStr.isEmpty) return false;

          try {
            final cumple = DateFormat("yyyy-MM-dd", "es_MX").parseStrict(cumpleStr);
            return cumple.day == hoy.day && cumple.month == hoy.month;
          } catch (_) {
            return false;
          }
        }).toList();

        if (cumpleanierosHoy == null || cumpleanierosHoy.isEmpty) {
          return const SizedBox(); // no renderiza nada
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              '🎂 Cumpleaños de hoy',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            _buildCarruselCumpleaniosHoy(cumpleanierosHoy),
          ],
        );
      },
    );
  }

  Widget _buildCarruselCumpleaniosHoy(List<QueryDocumentSnapshot> cumpleanierosHoy) {
    return CarouselSlider.builder(
      itemCount: cumpleanierosHoy.length,
      options: CarouselOptions(
        height: 280,
        enlargeCenterPage: true,
        enableInfiniteScroll: cumpleanierosHoy.length > 1,
        autoPlay: cumpleanierosHoy.length > 1,
        autoPlayInterval: const Duration(seconds: 5),
      ),
      itemBuilder: (context, index, realIndex) {
        final doc = cumpleanierosHoy[index];
        final data = doc.data() as Map<String, dynamic>;
        final nombre = data['nombre'] ?? 'Sin nombre';
        final foto = data['foto'] ?? '';

        return Container(
          width: 240,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFF8EC5FC), Color(0xFFE0C3FC)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.white,
                backgroundImage: (foto != null && foto.toString().isNotEmpty)
                    ? NetworkImage(foto)
                    : null,
                child: (foto == null || foto.toString().isEmpty)
                    ? const Icon(Icons.person, color: Colors.grey, size: 40)
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                nombre,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '🎉 ¡Feliz cumpleaños!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCumpleaniosDelDia() {
    final hoy = DateTime.now();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('UsuariosDcc').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final cumpleanierosHoy =
            snapshot.data?.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final cumpleStr = data['fechaNac'] ?? '';
              if (cumpleStr.isEmpty) return false;

              try {
                final cumple = DateFormat(
                  "yyyy-MM-dd",
                  "es_MX",
                ).parseStrict(cumpleStr);
                return cumple.day == hoy.day && cumple.month == hoy.month;
              } catch (_) {
                return false;
              }
            }).toList();

        if (cumpleanierosHoy == null || cumpleanierosHoy.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Text(
                '🎂 Hoy no hay cumpleaños',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
            ),
          );
        }

        return CarouselSlider.builder(
          itemCount: cumpleanierosHoy.length,
          options: CarouselOptions(
            height: 280,
            enlargeCenterPage: true,
            enableInfiniteScroll: cumpleanierosHoy.length > 1,
            autoPlay: cumpleanierosHoy.length > 1,
            autoPlayInterval: const Duration(seconds: 5),
          ),
          itemBuilder: (context, index, realIndex) {
            final doc = cumpleanierosHoy[index];
            final data = doc.data() as Map<String, dynamic>;
            final nombre = data['nombre'] ?? 'Sin nombre';
            final foto = data['foto'] ?? '';

            return Container(
              width: 240,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFF8EC5FC), Color(0xFFE0C3FC)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    backgroundImage:
                        (foto != null && foto.toString().isNotEmpty)
                            ? NetworkImage(foto)
                            : null,
                    child:
                        (foto == null || foto.toString().isEmpty)
                            ? const Icon(
                              Icons.person,
                              color: Colors.grey,
                              size: 40,
                            )
                            : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    nombre,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '🎉 ¡Feliz cumpleaños!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCumpleaniosMes() {
    final hoy = DateTime.now();
    final mesActual = hoy.month;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('UsuariosDcc').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final cumpleanieros = snapshot.data?.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final cumpleStr = data['fechaNac'] ?? '';
          if (cumpleStr.isEmpty) return false;

          try {
            final cumple = DateFormat("yyyy-MM-dd", "es_MX").parseStrict(cumpleStr);
            return cumple.month == mesActual;
          } catch (_) {
            return false;
          }
        }).toList();

        if (cumpleanieros == null || cumpleanieros.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('No hay cumpleaños este mes.')),
          );
        }

        // Ordenar por día del mes
        cumpleanieros.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          try {
            final fechaA = DateFormat("yyyy-MM-dd", "es_MX").parseStrict(dataA['fechaNac']);
            final fechaB = DateFormat("yyyy-MM-dd", "es_MX").parseStrict(dataB['fechaNac']);
            return fechaA.day.compareTo(fechaB.day);
          } catch (_) {
            return 0;
          }
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: List.generate(cumpleanieros.length, (index) {
            final doc = cumpleanieros[index];
            final data = doc.data() as Map<String, dynamic>;
            final nombre = data['nombre'] ?? 'Sin nombre';
            final cumpleStr = data['fechaNac'] ?? '';

            String fechaStr = 'Sin fecha';
            try {
              final cumple = DateFormat("yyyy-MM-dd", "es_MX").parseStrict(cumpleStr);
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
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        image: DecorationImage(
                          image: NetworkImage(data['foto'] ?? ''),
                          fit: BoxFit.cover,
                          onError: (exception, stackTrace) {},
                        ),
                        color: Colors.grey.shade300,
                      ),
                      child: data['foto'] == null || data['foto'].toString().isEmpty
                          ? const Icon(Icons.person, color: Colors.white, size: 28)
                          : null,
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
          }),
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

            if (docs.length == 1) {
              final data = docs.first.data() as Map<String, dynamic>;
              final imagenUrl = data['imagenUrl'] as String?;
              return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 400,
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

                    ],
                  ),
                ),
              );
            }

            return CarouselSlider.builder(
              itemCount: docs.length,
              options: CarouselOptions(
                enlargeFactor: 0.6,
                pageSnapping: true,
                height: 400,
                autoPlay: true,
                enlargeCenterPage: true,
                viewportFraction: 0.95,
                autoPlayInterval: const Duration(seconds: 10),
                enableInfiniteScroll: true,
                scrollPhysics: const BouncingScrollPhysics(),
              ),
              itemBuilder: (context, index, realIndex) {
                final data = docs[index].data() as Map<String, dynamic>;
                final imagenUrl = data['imagenUrl'] as String?;

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
                          crossAxisAlignment: CrossAxisAlignment.center,
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
                                '🎂 Cumpleaños de hoy',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              constraints: const BoxConstraints(
                              ),
                              child: _buildCumpleaniosDelDia(),
                            ),
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
                            const SizedBox(height: 10),
                            Container(
                              child: _buildCumpleaniosMes(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                      : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      _seccionTitulo('📰 Anuncios'),
                      SizedBox(
                        height: 400,
                        child: _buildCarruselAnuncios(),
                      ),
                      const SizedBox(height: 24),
                      _seccionCumpleaniosDelDia(),
                      const SizedBox(height: 24),
                      _seccionTitulo('🎂 Cumpleaños del mes'),
                      _buildCumpleaniosMes(),
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

  Widget _buildEventos() {
    final hoy = DateTime.now();
    final inicioMes = DateTime(hoy.year, hoy.month, 1);
    final hoyDesdeCero = DateTime(hoy.year, hoy.month, hoy.day);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('eventos')
              .where('fecha', isGreaterThanOrEqualTo: inicioMes)
              .orderBy('fecha')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final todos = snapshot.data?.docs ?? [];

            // Separar eventos pasados del mes actual y futuros
            final pasadosDelMes = todos.where((doc) {
              final fecha = (doc['fecha'] as Timestamp).toDate();
              final soloFecha = DateTime(fecha.year, fecha.month, fecha.day);
              return soloFecha.isBefore(hoyDesdeCero);
            }).toList();

            final futuros = todos.where((doc) {
              final fecha = (doc['fecha'] as Timestamp).toDate();
              final soloFecha = DateTime(fecha.year, fecha.month, fecha.day);
              return !soloFecha.isBefore(hoyDesdeCero); // hoy o futuros
            }).toList();

            // Unir: primero pasados del mes, luego futuros
            final eventos = [...pasadosDelMes, ...futuros];

            if (eventos.isEmpty) {
              return const Center(child: Text('No hay eventos disponibles.'));
            }

            if (isWide) {
              return SizedBox(
                height: 320,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: eventos.length,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemBuilder: (context, index) =>
                      _buildTarjetaEvento(context, eventos[index], hoyDesdeCero),
                ),
              );
            } else {
              return SizedBox(
                height: 300,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: eventos
                        .map((doc) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _buildTarjetaEvento(context, doc, hoyDesdeCero),
                    ))
                        .toList(),
                  ),
                ),
              );


            }
          },
        );
      },
    );
  }

  Widget _buildTarjetaEvento(BuildContext context, DocumentSnapshot doc, DateTime hoyDesdeCero) {
    final data = doc.data() as Map<String, dynamic>;
    final titulo = data['titulo'] ?? 'Evento';
    final descripcion = data['descripcion'] ?? '';
    final fecha = (data['fecha'] as Timestamp).toDate();
    final fechaStr = DateFormat('dd MMM yyyy', 'es_MX').format(fecha);
    final fechaEvento = DateTime(fecha.year, fecha.month, fecha.day);
    final eventoPasado = fechaEvento.isBefore(hoyDesdeCero);

    return Container(
      width: 300,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Card(
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.shade200,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(10),
                    child: const Icon(Icons.event, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      fechaStr,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 16,
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
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
              if (eventoPasado) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GaleriaEventoScreen(
                            fechaEvento: fecha,
                            eventoId: doc.id,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.photo_library),
                    label: const Text("Ver galería"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade200,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Drawer _buildAdminDrawer() {
    final isDarkMode = themeNotifier.value == ThemeMode.dark;
    final drawerBackground = isDarkMode ? Colors.black : Colors.white;
    final drawerTextColor = isDarkMode ? Colors.white : Colors.black87;

    return Drawer(
      backgroundColor: drawerBackground,
      child: Column(
        children: [
          Expanded(
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
                                : const AssetImage('assets/ds.png')
                                    as ImageProvider,
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
                          Navigator.pop(context);
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
                const Divider(),
                _buildDrawerItem(Icons.school, 'Capacitaciones', () {
                  setState(() {
                    _mostrarCursos = true;
                  });
                  Navigator.pop(context);
                }, drawerTextColor),
                const Divider(),
                _buildDrawerItem(
                  Icons.history,
                  'Registros E/S',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ResumenChecadasScreen(),
                    ),
                  ),
                  drawerTextColor,
                ),
                const Divider(),
              ],
            ),
          ),

          const Divider(),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExpansionTile(
                  leading: Icon(Icons.settings, color: drawerTextColor),
                  title: Text(
                    'Configuración',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: drawerTextColor,
                    ),
                  ),
                  collapsedIconColor: drawerTextColor,
                  iconColor: drawerTextColor,
                  children: [
                    _buildDrawerItem(
                      Icons.accessibility_new_outlined,
                      'Colaboradores',
                          () => _navigate(const empleadosScreen()),
                      drawerTextColor,
                    ),
                    ExpansionTile(
                      leading: Icon(Icons.home, color: drawerTextColor),
                      title: Text(
                        'Configuración inicio',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: drawerTextColor,
                        ),
                      ),
                      collapsedIconColor: drawerTextColor,
                      iconColor: drawerTextColor,
                      children: [
                        _buildDrawerItem(
                          Icons.post_add,
                          'Agregar anuncio',
                              () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AgregarNoticiaScreen()),
                            );
                          },
                          drawerTextColor,
                        ),
                        if (kIsWeb)
                          _buildDrawerItem(
                            Icons.person_add,
                            'Agregar foto de usuario',
                                () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AdministrarFotosUsuariosScreen(),
                                ),
                              );
                            },
                            drawerTextColor,
                          ),
                        _buildDrawerItem(
                          Icons.post_add,
                          'Agregar eventos',
                              () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AgregarEventoScreen()),
                            );
                          },
                          drawerTextColor,
                        ),
                        _buildDrawerItem(
                          Icons.photo_library,
                          'Configurar carrusel de vigilancia',
                              () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const EditarCarruselComedorScreen()),
                            );
                          },
                          drawerTextColor,
                        ),

                      ],
                    ),
                    const Divider(),
                    ExpansionTile(
                      leading: Icon(Icons.school, color: drawerTextColor),
                      title: Text(
                        'Configuración de Capacitaciones',
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
                          'Administrar áreas',
                              () => _navigate(const ManageAreasAndCoursesScreen()),
                          drawerTextColor,
                        ),
                        _buildDrawerItem(
                          Icons.video_collection,
                          'Contenido de cursos',
                              () => _navigate(const AdminResourcesScreen()),
                          drawerTextColor,
                        ),
                        _buildDrawerItem(
                          Icons.settings_accessibility,
                          'Acceso a cursos',
                              () => _navigate(const ManageCourseAccessScreen()),
                          drawerTextColor,
                        ),
                        _buildDrawerItem(
                          Icons.edit_document,
                          'Administrar exámenes',
                              () => _navigate(const AdminExamManagerScreen()),
                          drawerTextColor,
                        ),
                        _buildDrawerItem(
                          Icons.assignment,
                          'Resultados de exámenes',
                              () => _navigate(const ExamResultsScreen()),
                          drawerTextColor,
                        ),
                        _buildDrawerItem(
                          Icons.group,
                          'Progreso general',
                              () => _navigate(const GlobalProgressScreen()),
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
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Stack(
                  children: [
                    UserAccountsDrawerHeader(
                      accountName: Text(
                        currentUser?.displayName ?? 'Jefe de área',
                      ),
                      accountEmail: Text(currentUser?.email ?? ''),
                      currentAccountPicture: CircleAvatar(
                        backgroundImage:
                        currentUser?.photoURL != null
                            ? NetworkImage(currentUser!.photoURL!)
                            : const AssetImage('assets/ds.png')
                        as ImageProvider,
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
                          Navigator.pop(context);
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
                const Divider(),
                _buildDrawerItem(Icons.school, 'Capacitaciones', () {
                  setState(() {
                    _mostrarCursos = true;
                  });
                  Navigator.pop(context);
                }, drawerTextColor),
                const Divider(),
                _buildDrawerItem(
                  Icons.history,
                  'Registros E/S del equipo',
                      () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ResumenChecadasScreen(),
                    ),
                  ),
                  drawerTextColor,
                ),
                const Divider(),
              ],
            ),
          ),

          const Divider(),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(),
                _buildDrawerItem(
                  Icons.logout,
                  'Cerrar Sesión',
                  _logout,
                  drawerTextColor,
                ),
              ],
            ),
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
      child: Column(
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
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(Icons.home, 'Inicio', () {
                  setState(() {
                    _mostrarCursos = false;
                  });
                  Navigator.pop(context);
                }, drawerTextColor),
                const Divider(),
                _buildDrawerItem(Icons.school, 'Capacitaciones', () {
                  setState(() {
                    _mostrarCursos = true;
                  });
                  Navigator.pop(context);
                }, drawerTextColor),
              ],
            ),
          ),
          const Divider(),
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

  Drawer _buildnominasDrawer() {
    final isDarkMode = themeNotifier.value == ThemeMode.dark;
    final drawerBackground = isDarkMode ? Colors.black : Colors.white;
    final drawerTextColor = isDarkMode ? Colors.white : Colors.black87;

    return Drawer(
      backgroundColor: drawerBackground,
      child: Column(
        children: [
          Stack(
            children: [
              UserAccountsDrawerHeader(
                accountName: Text(
                  currentUser?.displayName ?? 'Área de nóminas 💰',
                ),
                accountEmail: Text(currentUser?.email ?? ''),
                currentAccountPicture: CircleAvatar(
                  backgroundImage:
                  currentUser?.photoURL != null
                      ? NetworkImage(currentUser!.photoURL!)
                      : const AssetImage('assets/ds.png')
                  as ImageProvider,
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
                    Navigator.pop(context);
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
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const Divider(),
                _buildDrawerItem(Icons.home, 'Inicio', () {
                  setState(() {
                    _mostrarCursos = false;
                  });
                  Navigator.pop(context);
                }, drawerTextColor),
                const Divider(),
                _buildDrawerItem(Icons.school, 'Capacitaciones', () {
                  setState(() {
                    _mostrarCursos = true;
                  });
                  Navigator.pop(context);
                }, drawerTextColor),
                const Divider(),
                _buildDrawerItem(
                  Icons.history,
                  'Registros E/S',
                      () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ResumenChecadasScreen(),
                    ),
                  ),
                  drawerTextColor,
                ),
                const Divider(),
              ],
            ),
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

  Drawer _buildIncidenciasDrawer() {
    final isDarkMode = themeNotifier.value == ThemeMode.dark;
    final drawerBackground = isDarkMode ? Colors.black : Colors.white;
    final drawerTextColor = isDarkMode ? Colors.white : Colors.black87;

    return Drawer(
      backgroundColor: drawerBackground,
      child: Column(
        children: [
          Stack(
            children: [
              UserAccountsDrawerHeader(
                accountName: Text(
                  currentUser?.displayName ?? 'Área de incidencias 👮‍♂️',
                ),
                accountEmail: Text(currentUser?.email ?? ''),
                currentAccountPicture: CircleAvatar(
                  backgroundImage:
                  currentUser?.photoURL != null
                      ? NetworkImage(currentUser!.photoURL!)
                      : const AssetImage('assets/ds.png')
                  as ImageProvider,
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
                    Navigator.pop(context);
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
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const Divider(),
                _buildDrawerItem(Icons.home, 'Inicio', () {
                  setState(() {
                    _mostrarCursos = false;
                  });
                  Navigator.pop(context);
                }, drawerTextColor),
                const Divider(),
                _buildDrawerItem(Icons.school, 'Capacitaciones', () {
                  setState(() {
                    _mostrarCursos = true;
                  });
                  Navigator.pop(context);
                }, drawerTextColor),
                const Divider(),
                _buildDrawerItem(
                  Icons.history,
                  'Registros E/S',
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
          ),
          const Divider(),
          _buildDrawerItem(
            Icons.accessibility_new_outlined,
            'Colaboradores',
                () => _navigate(const empleadosScreen()),
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

  Drawer _buildCapacitacionesDrawer() {
    final isDarkMode = themeNotifier.value == ThemeMode.dark;
    final drawerBackground = isDarkMode ? Colors.black : Colors.white;
    final drawerTextColor = isDarkMode ? Colors.white : Colors.black87;

    return Drawer(
      backgroundColor: drawerBackground,
      child: Column(
        children: [Stack(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(
                currentUser?.displayName ?? 'Área de capacitaciones 👨‍🏫',
              ),
              accountEmail: Text(currentUser?.email ?? ''),
              currentAccountPicture: CircleAvatar(
                backgroundImage:
                currentUser?.photoURL != null
                    ? NetworkImage(currentUser!.photoURL!)
                    : const AssetImage('assets/ds.png')
                as ImageProvider,
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
                  Navigator.pop(context);
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
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const Divider(),
                _buildDrawerItem(Icons.home, 'Inicio', () {
                  setState(() {
                    _mostrarCursos = false;
                  });
                  Navigator.pop(context);
                }, drawerTextColor),
                const Divider(),
                _buildDrawerItem(Icons.school, 'Capacitaciones', () {
                  setState(() {
                    _mostrarCursos = true;
                  });
                  Navigator.pop(context);
                }, drawerTextColor),
              ],
            ),
          ),
          const Divider(),
          ExpansionTile(
            leading: Icon(Icons.school, color: drawerTextColor),
            title: Text(
              'Configuración de Capacitaciones',
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
                'Administrar áreas',
                    () => _navigate(const ManageAreasAndCoursesScreen()),
                drawerTextColor,
              ),
              _buildDrawerItem(
                Icons.video_collection,
                'Contenido de cursos',
                    () => _navigate(const AdminResourcesScreen()),
                drawerTextColor,
              ),
              _buildDrawerItem(
                Icons.settings_accessibility,
                'Acceso a cursos',
                    () => _navigate(const ManageCourseAccessScreen()),
                drawerTextColor,
              ),
              _buildDrawerItem(
                Icons.edit_document,
                'Administrar exámenes',
                    () => _navigate(const AdminExamManagerScreen()),
                drawerTextColor,
              ),
              _buildDrawerItem(
                Icons.assignment,
                'Resultados de exámenes',
                    () => _navigate(const ExamResultsScreen()),
                drawerTextColor,
              ),
              _buildDrawerItem(
                Icons.group,
                'Progreso general',
                    () => _navigate(const GlobalProgressScreen()),
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
      title: Text(
        title,
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
      ),
      onTap: onTap,
    );
  }
}

