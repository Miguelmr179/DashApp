import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Controlador/controladorChecadas.dart';
import 'registrosPendientes.dart';

class RelojES extends StatefulWidget {
  const RelojES({Key? key}) : super(key: key);

  @override
  _RelojUSState createState() => _RelojUSState();
}

class _RelojUSState extends State<RelojES> {

  final TextEditingController _numberController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final CheckinService _checkinService = CheckinService();

  late String _horaActual;
  late String _fechaActual;
  late Timer _timer;
  late StreamSubscription _connectivitySubscription;
  late StreamSubscription<QuerySnapshot> _carruselSubscription;

  bool _cargandoCarrusel = true;
  bool _offline = false;
  bool _campoBloqueado = false;
  String? _tipoForzado;

  Timer? _desbloqueoTimer;

  List<String> _carouselImagesFirebase = [];


  @override
  void initState() {
    super.initState();
    _actualizarFechaHora();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _actualizarFechaHora(),
    );
    _cargarUsuariosLocales();
    _escucharCambiosCarrusel();
    _focusNode.requestFocus();

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      result,
    ) {
      final isOffline = result == ConnectivityResult.none;
      if (_offline && !isOffline) {
        _checkinService.subirChecadasPendientes(
          tipoRegistro: 'checkins_offline',
        );
      }
      setState(() => _offline = isOffline);
    });

    Connectivity().checkConnectivity().then(
      (result) => setState(() => _offline = result == ConnectivityResult.none),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    _numberController.dispose();
    _desbloqueoTimer?.cancel();
    _focusNode.dispose();
    _connectivitySubscription.cancel();
    super.dispose();
    _carruselSubscription.cancel();
  }

  void _escucharCambiosCarrusel() {
    _carruselSubscription = FirebaseFirestore.instance
        .collection('carrusel_comedor')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _carouselImagesFirebase = snapshot.docs
            .map((doc) => doc['imagenUrl'] as String)
            .toList();
        _cargandoCarrusel = false;
      });
    });
  }

  void _actualizarFechaHora() {
    final now = DateTime.now();
    setState(() {
      _horaActual = DateFormat('hh:mm:ss a').format(now);
      _fechaActual = DateFormat('dd MMMM yyyy', 'es_MX').format(now);
      _campoBloqueado = !_esHorarioValido() && _tipoForzado == null;
    });
  }

  Future<void> _cargarUsuariosLocales() async {
    final prefs = await SharedPreferences.getInstance();
    final usuariosSnapshot =
    await FirebaseFirestore.instance.collection('Usuarios').get();

    final listaActualRaw = prefs.getStringList('usuarios_locales') ?? [];
    final listaActual =
    listaActualRaw
        .map((e) => jsonDecode(e))
        .whereType<Map<String, dynamic>>()
        .toList();

    final nuevaLista = <Map<String, dynamic>>[];

    for (final doc in usuariosSnapshot.docs) {
      final titulo = doc['Título'];
      final nombre = doc['nombre'] ?? '';

      // Busca si ya estaba antes
      final existente = listaActual.firstWhere(
            (u) => u['titulo'] == titulo,
        orElse: () => {},
      );

      nuevaLista.add({
        'titulo': titulo,
        'nombre': nombre,
        'foto': existente['foto'],
        'foto_local': existente['foto_local'],
      });
    }

    final jsonList = nuevaLista.map(jsonEncode).toList();
    await prefs.setStringList('usuarios_locales', jsonList);
  }

  Future<void> _desbloquearManual() async {
    final tipo = await showDialog<String>(
      context: context,
      builder:
          (_) => AlertDialog(
        title: const Text('Desbloqueo Manual'),
        content: const Text(
          'Estás fuera del horario permitido.\nSe registrará como "Entrada Planta".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'entrada_planta'),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );

    if (tipo != null && tipo == 'entrada_planta') {
      setState(() {
        _tipoForzado = tipo;
        _campoBloqueado = false;
        _focusNode.requestFocus();
      });

      _desbloqueoTimer?.cancel(); // cancelar temporizador anterior si existe
      _desbloqueoTimer = Timer(const Duration(seconds: 30), () {
        if (mounted) {
          setState(() {
            _tipoForzado = null;
            _campoBloqueado = true;
          });
        }
      });
    }
  }

  Future<void> _registrarEntrada(String tarjeta) async {
    final tipo = _obtenerTipoEntrada();
    await _checkinService.procesarChecadaLocal(
      tarjeta,
      context,
      tipoRegistro: 'checkins_offline',
      tipoPersonalizado: tipo,
    );

    setState(() {
      _numberController.clear();
      _tipoForzado = null;
      _campoBloqueado = !_esHorarioValido();
      _focusNode.requestFocus();
    });
  }

  bool _esHorarioValido() {
    final now = DateTime.now();
    final dia = now.weekday; // lunes = 1, domingo = 7
    final horaActual = TimeOfDay.fromDateTime(now);

    final esFinSemanaRestringido =
        (dia == 5 && now.hour >= 18) ||
            (dia == 6) ||
            (dia == 7) ||
            (dia == 1 && now.hour < 5);
    if (esFinSemanaRestringido) {
      // Solo se permiten horarios de planta (5:00–10:00 y 17:00–18:00)
      return _isTimeInRange(horaActual, const TimeOfDay(hour: 5, minute: 0), const TimeOfDay(hour: 9, minute: 59)) ||
          _isTimeInRange(horaActual, const TimeOfDay(hour: 17, minute: 0), const TimeOfDay(hour: 17, minute: 59));
    } else {
      // Horarios normales:
      return _isTimeInRange(horaActual, const TimeOfDay(hour: 5, minute: 0), const TimeOfDay(hour: 9, minute: 59)) ||
          _isTimeInRange(horaActual, const TimeOfDay(hour: 17, minute: 0), const TimeOfDay(hour: 17, minute: 59)) ||
          _isTimeInRange(horaActual, const TimeOfDay(hour: 10, minute: 0), const TimeOfDay(hour: 15, minute: 14)) ||
          _isTimeInRange(horaActual, const TimeOfDay(hour: 22, minute: 0), const TimeOfDay(hour: 3, minute: 14));
    }
  }

  bool _esHorarioComedor() {
    final now = DateTime.now();
    final horaActual = TimeOfDay.fromDateTime(now);

    final horarioComedorDia = _isTimeInRange(
      horaActual,
      const TimeOfDay(hour: 10, minute: 0),
      const TimeOfDay(hour: 15, minute: 15),
    );

    final horarioComedorNoche = _isTimeInRange(
      horaActual,
      const TimeOfDay(hour: 22, minute: 0),
      const TimeOfDay(hour: 3, minute: 15),
    );

    return horarioComedorDia || horarioComedorNoche;
  }

  bool _isTimeInRange(TimeOfDay actual, TimeOfDay inicio, TimeOfDay fin) {
    final actualMins = actual.hour * 60 + actual.minute;
    final inicioMins = inicio.hour * 60 + inicio.minute;
    final finMins = fin.hour * 60 + fin.minute;

    if (inicioMins <= finMins) {
      return actualMins >= inicioMins && actualMins <= finMins;
    } else {
      return actualMins >= inicioMins || actualMins <= finMins;
    }
  }

  String _obtenerTipoEntrada() {
    if (_tipoForzado != null) return _tipoForzado!;
    final hora = DateTime.now().hour;
    if ((hora >= 5 && hora < 10) || (hora >= 17 && hora < 18)) {
      return 'entrada_planta';
    } else {
      return 'entrada_comedor';
    }
  }

  Widget _buildCarruselComedor() {
    if (_carouselImagesFirebase.isEmpty) {
      return const Center(
        child: Text(
          'No hay imágenes disponibles',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    if (_carouselImagesFirebase.length == 1) {
      // Solo una imagen: mostrar estática
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          _carouselImagesFirebase.first,
          fit: BoxFit.fill,
          width: double.infinity,
          height: 600,
        ),
      );
    }

    // Múltiples imágenes: usar carrusel
    return CarouselSlider.builder(
      itemCount: _carouselImagesFirebase.length,
      itemBuilder: (context, index, realIndex) {
        final url = _carouselImagesFirebase[index];
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            url,
            fit: BoxFit.fill,
            width: double.infinity,
          ),
        );
      },
      options: CarouselOptions(
        height: 600,
        autoPlay: true,
        enlargeCenterPage: true,
        viewportFraction: 0.9,
        autoPlayInterval: const Duration(seconds: 6),
        scrollPhysics: const BouncingScrollPhysics(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF056AA4), Color(0xFF0A78BD), Color(0xFF056AA4)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: const Color(0xFF16699B),
          elevation: 4,
          centerTitle: true,
          title: const Text(
            'Entradas (Planta / Comedor)',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          actions: [
            if (_esHorarioComedor())
              IconButton(
                onPressed: () {
                  setState(() {
                    _tipoForzado = 'entrada_planta';
                    _campoBloqueado = false;
                    _focusNode.requestFocus();
                  });

                  _desbloqueoTimer?.cancel();
                  _desbloqueoTimer = Timer(const Duration(seconds: 15), () {
                    if (mounted) {
                      setState(() {
                        _tipoForzado = null;
                        _campoBloqueado = true;
                      });
                    }
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Se registrara como entrada a planta.',
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Colors.deepPurple,
                      duration: Duration(seconds: 3),
                    ),
                  );
                },
                icon: const Icon(Icons.factory),
                tooltip: 'Registrar entrada a planta',
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF023859),
                  foregroundColor: Colors.white,
                ),
              ),
            IconButton(
              icon: const Icon(Icons.history, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => const RegistrosPendientesScreen(
                          tipoRegistro: 'checkins_offline',
                        ),
                  ),
                );
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Text(
                  'Entrada a: ${_obtenerTipoEntrada() == 'entrada_planta' ? 'Planta' : 'Comedor'}',
                  style: const TextStyle(
                    fontSize: 45,
                    color: Color(0xFFFFFFFF),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _fechaActual,
                  style: const TextStyle(fontSize: 45, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  _horaActual,
                  style: const TextStyle(
                    fontSize: 50,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 40),

                if (_campoBloqueado) ...[
                  if (_cargandoCarrusel)
                    const CircularProgressIndicator()
                  else if (_carouselImagesFirebase.isEmpty)
                    const Text(
                      'No hay imágenes disponibles.',
                      style: TextStyle(color: Colors.white),
                    )
                  else
                    _buildCarruselComedor(),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _desbloquearManual,
                    icon: const Icon(Icons.lock_open),
                    label: const Text('Desbloquear Manualmente'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],

                Expanded(
                  child:
                      _campoBloqueado
                          ? const SizedBox()
                          : Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32.0,
                                  vertical: 10,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Ingrese su número de tarjeta:',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _numberController,
                                      focusNode: _focusNode,
                                      autofocus: true,
                                      keyboardType: TextInputType.number,
                                      onFieldSubmitted: _registrarEntrada,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 20),
                                      decoration: InputDecoration(
                                        hintText: '000123',
                                        hintStyle: TextStyle(
                                          color: Colors.grey,
                                        ),
                                        fillColor: Colors.white,
                                        filled: true,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                ),
                              ),
                            ],
                          ),
                ),

                Container(
                  width: double.infinity,
                  color: const Color(0xFF0B68A6),
                  padding: const EdgeInsets.all(8),
                  child: const Text(
                    'Sistema de checadas GDM - Beta 1.0.1',
                    style: TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            if (_offline)
              Positioned(
                bottom: 70,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.red.shade700,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.cloud_off, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Sin conexión a Internet',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
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
  }
}
