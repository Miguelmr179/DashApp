import 'dart:async';
import 'dart:convert';
import 'package:dashapp/Huellas/Utileria/Usuarios_Local_Singleton.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Controlador/controladorChecadas.dart';
import 'registrosPendientes.dart';

class RelojCOM extends StatefulWidget {
  const RelojCOM({Key? key}) : super(key: key);

  @override
  State<RelojCOM> createState() => _RelojCOMState();
}

class _RelojCOMState extends State<RelojCOM> {

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

    _focusNode.requestFocus();
    _cargarUsuariosLocales();
    UsuariosLocalesService().notificador.addListener(_cargarUsuariosLocales);
    _escucharCambiosCarrusel();

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
    _checkinService.iniciarSubidaAutomatica();
  }

  @override
  void dispose() {
    _timer.cancel();
    _desbloqueoTimer?.cancel();
    _numberController.dispose();
    _focusNode.dispose();
    _connectivitySubscription.cancel();
    super.dispose();
    _carruselSubscription.cancel();
    UsuariosLocalesService().notificador.removeListener(_cargarUsuariosLocales);
  }


  bool _esHorarioValido() {
    final now = DateTime.now();
    final dia = now.weekday; // lunes = 1, domingo = 7
    final hora = now.hour;

    final enPeriodoSoloPlanta =
        (dia == 5 && hora >= 19) || // viernes después de 7 p.m.
            (dia == 6) || // sábado completo
            (dia == 7) || // domingo completo
            (dia == 1 && hora < 4); // lunes antes de 4 a.m.

    if (enPeriodoSoloPlanta) {
      // Para los fines de semana y viernes después de las 7 p.m.
      return (hora >= 6 && hora < 8) || (hora >= 16 && hora < 20);
    }

    if (dia == 5) {
      // Viernes: salida de 6:00 a.m a 8:00 a.m y de 4:00 p.m. a 7:00 p.m. únicamente este dia
      return (hora >= 16 && hora < 19) || (hora >= 10 && hora < 16) ||
          (hora >= 6 || hora < 8);
    }
      //De lunes a jueves
    if (dia >= 1 && dia <= 4) {
      return (hora >= 6 && hora < 8) ||
          (hora >= 18 && hora < 20) ||
          (hora >= 10 && hora < 16) ||
          (hora >= 22 || hora < 4);
    }

    return false;
  }

  String _obtenerTipoSalida() {
    if (_tipoForzado != null) return _tipoForzado!;
    final hora = DateTime.now().hour;

    if ((hora >= 6 && hora < 8) || (hora >= 16 && hora < 20)) {
      return 'salida_planta';
    } else {
      return 'salida_comedor';
    }
  }

  Future<void> _cargarUsuariosLocales() async {
    final prefs = await SharedPreferences.getInstance();
    final usuariosSnapshot =
        await FirebaseFirestore.instance.collection('UsuariosDcc').get();

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
            title: const Text('Selecciona el tipo de salida'),
            content: const Text(
              'Estás fuera del horario permitido. ¿Qué tipo deseas registrar?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 'salida_planta'),
                child: const Text('Salida Planta'),
              ),
            ],
          ),
    );

    if (tipo != null) {
      setState(() {
        _tipoForzado = tipo;
        _campoBloqueado = false;
        _focusNode.requestFocus();
      });

      _desbloqueoTimer?.cancel();
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

  Future<bool> _tieneSalidaComedorReciente(String tarjeta) async {
    final prefs = await SharedPreferences.getInstance();
    final registrosRaw = prefs.getStringList('checadas_pendientes') ?? [];
    final ahora = DateTime.now();

    for (final raw in registrosRaw) {
      final registro = jsonDecode(raw);
      if (registro['tarjeta'] == tarjeta &&
          registro['tipo'] == 'salida_comedor') {
        final fechaHora = DateTime.tryParse(
          '${registro['fecha']} ${registro['hora']}',
        );
        if (fechaHora != null && ahora.difference(fechaHora).inMinutes < 60) {
          return true;
        }
      }
    }
    return false;
  }

  Future<void> _registrarSalida(String tarjeta) async {
    final tipo = _obtenerTipoSalida();

    if (tipo == 'salida_comedor') {
      final yaTiene = await _tieneSalidaComedorReciente(tarjeta);
      if (yaTiene) {
        _mostrarAlertaDuplicado();
        return;
      }
    }

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

  void _actualizarFechaHora() {
    final now = DateTime.now();
    setState(() {
      _horaActual = DateFormat('hh:mm:ss a').format(now);
      _fechaActual = DateFormat('dd MMMM yyyy', 'es_MX').format(now);
      _campoBloqueado = !_esHorarioValido() && _tipoForzado == null;
    });
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

  void _mostrarAlertaDuplicado() {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
        title: const Text('Registro duplicado'),
        content: const Text(
          'Ya se registró una salida de comedor recientemente.\n'
              'Debes esperar al menos 1 hora entre registros de este tipo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
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
          colors: [
            Color(0xFFFF0000), // rojo oscuro
            Color(0xFFFF0000), // rojo fuego
            Color(0xFFE50D0D),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: const Color(0xFFFF0000),
          elevation: 4,
          centerTitle: true,
          title: const Text(
            'Salidas (Planta / Comedor)',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          actions: [
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
                const SizedBox(height: 16),
                Text(
                  'Salida de: ${_obtenerTipoSalida() == 'salida_planta' ? 'Planta' : 'Comedor'}',
                  style: const TextStyle(fontSize: 40, color: Colors.white),
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
                      backgroundColor: Colors.orange.shade800,
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
                                      onFieldSubmitted: _registrarSalida,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 20),
                                      decoration: InputDecoration(
                                        hintText: '000123',
                                        hintStyle: const TextStyle(
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
                                  ],
                                ),
                              ),
                            ],
                          ),
                ),

                Container(
                  width: double.infinity,
                  color: const Color(0xFF640000),
                  padding: const EdgeInsets.all(8),
                  child: const Text(
                    'Sistema de checadas GDM - Beta 1.0.0',
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
                  color: Colors.red.shade800,
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
