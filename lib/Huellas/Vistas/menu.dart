import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dashapp/Huellas/Vistas/reloj_Entradas.dart';
import 'package:dashapp/Huellas/Vistas/reloj_Salidas.dart';
import 'package:dashapp/Huellas/Vistas/resumenChecadas.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../Controlador/ConfiguracionSubidasScreen.dart';
import '../Controlador/controladorChecadas.dart';
import '../Modelo/usuarios.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  final CheckinService _checkinService = CheckinService();
  bool _cargandoUsuarios = false;

  @override
  void initState() {
    super.initState();
    _checkinService.iniciarSubidaAutomatica();
  }

  Future<String?> _descargarYGuardarImagen(String uid, String url) async {
    try {
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode == 200) {
        final bytes = await consolidateHttpClientResponseBytes(response);
        final dir = await getApplicationDocumentsDirectory();
        final filePath = '${dir.path}/$uid.jpg';
        final file = File(filePath);
        await file.writeAsBytes(bytes);
        return filePath;
      }
    } catch (e) {
      debugPrint('Error descargando imagen de $uid: $e');
    }
    return null;
  }

  Future<void> cargarUsuariosLocales() async {
    setState(() => _cargandoUsuarios = true);

    final prefs = await SharedPreferences.getInstance();
    final snapshot = await FirebaseFirestore.instance.collection('Usuarios').get();

    final listaRaw = prefs.getStringList('usuarios_locales') ?? [];
    final listaLocal = listaRaw.map((e) => jsonDecode(e)).whereType<Map<String, dynamic>>().toList();
    final usuariosFirebase = snapshot.docs.map((doc) => Usuario.fromMap(doc.data())).toList();

    final listaJson = <String>[];

    for (var usuario in usuariosFirebase) {
      final uid = usuario.titulo;
      final url = usuario.foto;

      final local = listaLocal.firstWhere(
            (u) => u['titulo'] == uid,
        orElse: () => {},
      );

      if (local.isNotEmpty && local['foto_local'] != null && File(local['foto_local']).existsSync()) {
        usuario.fotoLocal = local['foto_local'];
      } else if (url != null && url.isNotEmpty) {
        final localPath = await _descargarYGuardarImagen(uid, url);
        if (localPath != null) {
          usuario.fotoLocal = localPath;
        }
      }

      listaJson.add(jsonEncode(usuario.toJson()));
    }

    await prefs.setStringList('usuarios_locales', listaJson);

    setState(() => _cargandoUsuarios = false);
  }

  Future<bool> _solicitarContrasena(BuildContext context) async {
    final TextEditingController _controller = TextEditingController();
    bool acceso = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('Acceso restringido'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Ingresa la contraseña para continuar:'),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: 'Contraseña',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_controller.text.trim() == 'Dcc2025') {
                  acceso = true;
                }
                Navigator.pop(context);
              },
              child: const Text('Aceptar'),
            ),
          ],
        );
      },
    );

    return acceso;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0487D9),
            Color(0xFF023859),
            Color(0xFF0487D9),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'Menú Principal',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              tooltip: 'Actualizar usuarios',
              icon: const Icon(Icons.sync),
              onPressed: _cargandoUsuarios ? null : cargarUsuariosLocales,
            ),
          ],
        ),
        body: _cargandoUsuarios
            ? const Center(child: CircularProgressIndicator())
            : Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildMenuCard(
                  context,
                  icon: Icons.login_rounded,
                  label: 'Reloj de Entradas',
                  color: Colors.greenAccent.shade700,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RelojES()),
                    );
                  },
                ),
                const SizedBox(height: 25),
                _buildMenuCard(
                  context,
                  icon: Icons.logout_rounded,
                  label: 'Reloj Salidas',
                  color: Colors.redAccent.shade700,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RelojCOM()),
                    );
                  },
                ),
                const SizedBox(height: 25),

                const SizedBox(height: 25),
                _buildMenuCard(
                  context,
                  icon: Icons.settings,
                  label: 'Configuración',
                  color: Colors.deepPurpleAccent,
                  onTap: () async {
                    final accesoPermitido = await _solicitarContrasena(context);
                    if (accesoPermitido) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SubmenuConfiguracion()),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Contraseña incorrecta')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context,
      {required IconData icon,
        required String label,
        required Color color,
        required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              radius: 28,
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color.withOpacity(0.8)),
          ],
        ),
      ),
    );
  }


  ButtonStyle _buttonStyle() {
    return ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      elevation: 5,
    );
  }
}
class SubmenuConfiguracion extends StatelessWidget {
  const SubmenuConfiguracion({super.key});

  @override
  Widget build(BuildContext context) {
    final List<_OpcionSubmenu> opciones = [
      _OpcionSubmenu(
        titulo: 'Control de Checadas',
        icono: Icons.settings,
        color: Colors.indigo,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ConfiguracionSubidasScreen(),
            ),
          );
        },
      ),
      _OpcionSubmenu(
        titulo: 'Registros de Checadas',
        icono: Icons.history,
        color: Colors.teal,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ResumenChecadasScreen(),
            ),
          );
        },
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        backgroundColor: Colors.indigo,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: opciones.length,
        itemBuilder: (context, index) {
          final opcion = opciones[index];
          return Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            margin: const EdgeInsets.symmetric(vertical: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: opcion.onTap,
              splashColor: opcion.color.withOpacity(0.3),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: opcion.color.withOpacity(0.2),
                      child: Icon(opcion.icono, color: opcion.color, size: 30),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Text(
                        opcion.titulo,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 28, color: Colors.grey),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OpcionSubmenu {
  final String titulo;
  final IconData icono;
  final Color color;
  final VoidCallback onTap;

  _OpcionSubmenu({
    required this.titulo,
    required this.icono,
    required this.color,
    required this.onTap,
  });
}
