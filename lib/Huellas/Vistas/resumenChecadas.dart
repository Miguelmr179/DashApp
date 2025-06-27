import 'dart:async';
import 'dart:io' as io;
import 'package:dashapp/Huellas/Vistas/EditarRegistroScreen.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart' as html;

class ResumenChecadasScreen extends StatefulWidget {
  const ResumenChecadasScreen({super.key});

  @override
  State<ResumenChecadasScreen> createState() => _ResumenChecadasScreenState();
}

class _ResumenChecadasScreenState extends State<ResumenChecadasScreen> {

  bool _ordenAscendente = false;
  bool _cargando = false;
  bool _mostrarFiltros = true;

  int _paginaActual = 0;
  int get _totalPaginas =>
      (resumen.length / _elementosPorPagina).ceil().clamp(1, 999);

  List<MapEntry<String, Map<String, dynamic>>> get _fechasPaginadas {
    final lista = resumen.entries.toList();
    final inicio = _paginaActual * _elementosPorPagina;
    final fin = (inicio + _elementosPorPagina).clamp(0, lista.length);
    return lista.sublist(inicio, fin);
  }
  List<String> _usuariosSeleccionados = [];

  String _filtroNombre = '';
  String _filtroFalta = 'todos';
  String? _jefeSeleccionado;
  String _campoOrdenamiento = 'nomina';

  final int _elementosPorPagina = 1;
  final TextEditingController _minNominaController = TextEditingController();
  final TextEditingController _maxNominaController = TextEditingController();
  final List<String> tiposFalta = [
    'todos',
    'sin_entrada',
    'sin_salida',
    'falta_comedor',
    'completo',
  ];
  final List<String> _opcionesOrdenamiento = [
    'nomina',
    'entrada_planta',
    'salida_planta',
  ];
  final Map<String, String> _etiquetasOrdenamiento = {
    'nomina': 'Nómina',
    'entrada_planta': 'Entrada Planta',
    'salida_planta': 'Salida Planta',
  };
  final Map<String, String> mapaNombres = {}; // tarjeta → nombre completo
  final Map<String, String> mapaReporta = {};
  final Map<String, String> _mapaJefes = {};

  DateTime? _fechaInicio;
  DateTime? _fechaFin;

  Map<String, Map<String, dynamic>> resumen = {};
  Map<String, String> mapaTituloANomina = {};

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    _fechaInicio = hoy.subtract(const Duration(days: 1));
    _fechaFin = hoy;

    _cargarResumen();
  }

  void _cambiarOrden() {
    setState(() => _ordenAscendente = !_ordenAscendente);
  }

  bool _cumpleFiltroFalta(Map<String, dynamic> d) {
    switch (_filtroFalta) {
      case 'sin_entrada':
        return d['entrada_planta'] == '';
      case 'sin_salida':
        return d['salida_planta'] == '';
      case 'falta_comedor':
        return d['entrada_comedor'] == '' || d['salida_comedor'] == '';
      case 'completo':
        return d['entrada_planta'] != '' &&
            d['entrada_comedor'] != '' &&
            d['salida_comedor'] != '' &&
            d['salida_planta'] != '';
      default:
        return true;
    }
  }

  Future<void> _cargarResumen() async {
    setState(() => _cargando = true);

    if (_fechaInicio == null || _fechaFin == null) return;

    // Convertimos las fechas a formato yyyy-MM-dd para comparación de tipo String
    final fechaInicioStr = DateFormat("yyyy-MM-dd").format(_fechaInicio!);
    final fechaFinStr = DateFormat("yyyy-MM-dd").format(_fechaFin!);

    mapaTituloANomina.clear();

    // Cargar usuarios
    final usuariosSnap = await FirebaseFirestore.instance.collection('Usuarios').get();

    for (final doc in usuariosSnap.docs) {
      final data = doc.data();

      if (data.containsKey('Título') && data.containsKey('no')) {
        final tarjeta = data['Título']?.toString().trim() ?? '';
        final nomina = data['no']?.toString().trim() ?? '';

        if (tarjeta.isNotEmpty && nomina.isNotEmpty) {
          mapaTituloANomina[tarjeta] = nomina;

          if (!mapaNombres.containsKey(tarjeta)) {
            mapaNombres[tarjeta] =
                '${data['nombre'] ?? ''} ${data['apellidos'] ?? ''}'.trim();
          }

          if (data['reporta'] != null) {
            mapaReporta[nomina] = data['reporta'].toString();
          }

          if ((data['jefe']?.toString() ?? '') == "1") {
            final nombreCompleto =
            '${data['nombre']?.toString().trim() ?? ''} ${data['apellidos']?.toString().trim() ?? ''}'.trim();
            if (nombreCompleto.isNotEmpty) {
              _mapaJefes[nombreCompleto] = nomina;
            }
          }
        }
      }
    }

    debugPrint('Total jefes encontrados: ${_mapaJefes.length}');

    // 🔍 Filtro confiable basado en campo 'fecha' que ya viene ajustado
    final snapshot = await FirebaseFirestore.instance
        .collection('checadas')
        .where('fecha', isGreaterThanOrEqualTo: fechaInicioStr)
        .where('fecha', isLessThanOrEqualTo: fechaFinStr)
        .get();

    final registros = snapshot.docs.map((doc) => doc.data()).toList();
    final Map<String, Map<String, Map<String, dynamic>>> agrupado = {};

    const tiposValidos = [
      'entrada_planta',
      'entrada_comedor',
      'salida_comedor',
      'salida_planta',
    ];

    for (final r in registros) {
      final fechaStr = r['fecha']; // Ya está ajustada y filtrada
      final tipo = r['tipo'];
      final fechaHora = (r['Reg_FechaHoraRegistro'] as Timestamp).toDate();
      final tarjeta = r['Reg_no'];
      final nombre = r['Title'];
      final nomina = mapaTituloANomina[tarjeta] ?? '';
      final hora = DateFormat('HH:mm:ss').format(fechaHora);

      if (!tiposValidos.contains(tipo)) continue;

      agrupado[fechaStr] ??= {};
      agrupado[fechaStr]![tarjeta] ??= {
        'nombre': nombre,
        'tarjeta': tarjeta,
        'nomina': nomina,
        'entrada_planta': '',
        'entrada_comedor': '',
        'salida_comedor': '',
        'salida_planta': '',
        'reporta': mapaReporta[nomina] ?? '',
      };

      if (r.containsKey('observaciones') &&
          r['observaciones'] != null &&
          r['observaciones'].toString().trim().isNotEmpty) {
        agrupado[fechaStr]![tarjeta]!['observaciones'] ??= r['observaciones'];
      }

      if (agrupado[fechaStr]![tarjeta]![tipo] == '') {
        agrupado[fechaStr]![tarjeta]![tipo] = hora;
      }
    }

    // Asegurar que todos los días del rango estén presentes aunque no tengan registros
    final dias = <String>[];
    DateTime fecha = _fechaInicio!;
    while (!fecha.isAfter(_fechaFin!)) {
      dias.add(DateFormat('yyyy-MM-dd').format(fecha));
      fecha = fecha.add(const Duration(days: 1));
    }

    for (final dia in dias) {
      agrupado[dia] ??= {};
      for (final entry in mapaTituloANomina.entries) {
        final tarjeta = entry.key;
        final nomina = entry.value;

        agrupado[dia]![tarjeta] ??= {
          'nombre': mapaNombres[tarjeta] ?? '',
          'tarjeta': tarjeta,
          'nomina': nomina,
          'entrada_planta': '',
          'entrada_comedor': '',
          'salida_comedor': '',
          'salida_planta': '',
          'reporta': mapaReporta[nomina] ?? '',
        };
      }
    }

    setState(() {
      resumen = agrupado.map((k, v) => MapEntry(k, v));
      _cargando = false;
    });
  }

  Future<void> _seleccionarRangoFechas() async {
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1),
      lastDate: DateTime.now().add(const Duration(days: 7)),
      initialDateRange:
          _fechaInicio != null && _fechaFin != null
              ? DateTimeRange(start: _fechaInicio!, end: _fechaFin!)
              : null,
    );

    if (rango != null) {
      setState(() {
        _fechaInicio = rango.start;
        _fechaFin = rango.end;
      });
      _cargarResumen();
    }
  }

  Future<void> _mostrarDialogoUsuarios() async {
    final TextEditingController _busquedaController = TextEditingController();
    String filtroBusqueda = '';

    final List<Map<String, String>> listaUsuarios = [];
    for (final fecha in resumen.values) {
      for (final usuario in fecha.values) {
        final nombre = usuario['nombre'] ?? '';
        final nomina = usuario['nomina'] ?? '';
        if (!listaUsuarios.any(
          (u) => u['nombre'] == nombre && u['nomina'] == nomina,
        )) {
          listaUsuarios.add({'nombre': nombre, 'nomina': nomina});
        }
      }
    }

    await showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final filtrados =
                listaUsuarios.where((usuario) {
                  final nombre = usuario['nombre']!.toLowerCase();
                  final nomina = usuario['nomina']!;
                  final filtro = filtroBusqueda.toLowerCase();
                  return nombre.contains(filtro) || nomina.contains(filtro);
                }).toList();

            return AlertDialog(
              title: const Text('Seleccionar usuarios'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _busquedaController,
                    decoration: const InputDecoration(
                      labelText: 'Buscar por nombre o nómina',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setStateDialog(() => filtroBusqueda = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 320,
                    width: 400,
                    child: Scrollbar(
                      child: ListView(
                        children:
                            filtrados.map((usuario) {
                              final nombre = usuario['nombre']!;
                              final nomina = usuario['nomina']!;
                              final display = '$nombre ($nomina)';
                              final seleccionado = _usuariosSeleccionados
                                  .contains(nombre);

                              return CheckboxListTile(
                                title: Text(display),
                                value: seleccionado,
                                onChanged: (bool? valor) {
                                  setState(() {
                                    if (valor == true) {
                                      _usuariosSeleccionados.add(nombre);
                                    } else {
                                      _usuariosSeleccionados.remove(nombre);
                                    }
                                  });
                                  setStateDialog(() {});
                                },
                              );
                            }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
              ],
            );
          },
        );
      },
    );
  }


  Future<void> _exportarAExcel() async {
    final excel = Excel.createExcel();
    final Sheet sheet = excel['Checadas'];

    final filtroNombreActivo = _filtroNombre.isNotEmpty ? _filtroNombre : 'Todos';
    final filtroFaltaActivo = _filtroFalta.replaceAll('_', ' ').toUpperCase();
    final nomMin = _minNominaController.text.isNotEmpty ? _minNominaController.text : 'Sin mínimo';
    final nomMax = _maxNominaController.text.isNotEmpty ? _maxNominaController.text : 'Sin máximo';
    final jefe = _jefeSeleccionado ?? 'Todos';

    CellStyle headerStyle = CellStyle(
      bold: true,
      fontSize: 12,
      horizontalAlign: HorizontalAlign.Center,
    );

    CellStyle titleStyle = CellStyle(
      bold: true,
      fontSize: 14,
      horizontalAlign: HorizontalAlign.Left,
    );

    // Título y filtros
    sheet.appendRow([TextCellValue('Resumen de Checadas')]);
    sheet.row(sheet.maxRows - 1).forEach((cell) => cell?.cellStyle = titleStyle);

    sheet.appendRow([]);
    sheet.appendRow([TextCellValue('Filtros aplicados:')]);
    sheet.appendRow([TextCellValue('Nombre/Nómina:'), TextCellValue(filtroNombreActivo)]);
    sheet.appendRow([TextCellValue('Tipo de Falta:'), TextCellValue(filtroFaltaActivo)]);
    sheet.appendRow([TextCellValue('Nómina mínima:'), TextCellValue(nomMin)]);
    sheet.appendRow([TextCellValue('Nómina máxima:'), TextCellValue(nomMax)]);
    sheet.appendRow([TextCellValue('Jefe seleccionado:'), TextCellValue(jefe)]);
    sheet.appendRow([]);

    // Encabezado de tabla
    final headers = ['Fecha', 'Nombre', 'Nómina', 'Entrada Planta', 'Salida Planta'];
    final headerCells = headers.map((e) => TextCellValue(e)).toList();
    sheet.appendRow(headerCells);
    sheet.row(sheet.maxRows - 1).forEach((cell) => cell?.cellStyle = headerStyle);

    // Datos filtrados
    for (final fechaEntry in _fechasPaginadas) {
      final fecha = fechaEntry.key;
      final personas = fechaEntry.value;

      final personasOrdenadas = personas.entries.toList()
        ..sort((a, b) {
          dynamic valorA = a.value[_campoOrdenamiento];
          dynamic valorB = b.value[_campoOrdenamiento];
          if (_campoOrdenamiento == 'nomina') {
            final intA = int.tryParse(valorA ?? '') ?? 0;
            final intB = int.tryParse(valorB ?? '') ?? 0;
            return _ordenAscendente ? intA.compareTo(intB) : intB.compareTo(intA);
          } else if (_campoOrdenamiento == 'entrada_planta' || _campoOrdenamiento == 'salida_planta') {
            final horaA = (valorA != null && valorA != '') ? valorA : '99:99:99';
            final horaB = (valorB != null && valorB != '') ? valorB : '99:99:99';
            return _ordenAscendente ? horaA.compareTo(horaB) : horaB.compareTo(horaA);
          }
          return 0;
        });

      final filtradas = personasOrdenadas.where((p) {
        final d = p.value;
        final coincideNombre = _filtroNombre.isEmpty ||
            d['nombre'].toString().toLowerCase().contains(_filtroNombre) ||
            d['nomina'].toString().toLowerCase().contains(_filtroNombre);

        final cumpleFalta = _cumpleFiltroFalta(d);
        final nomina = int.tryParse(d['nomina'].toString()) ?? 0;
        final minNom = int.tryParse(_minNominaController.text);
        final maxNom = int.tryParse(_maxNominaController.text);
        final enRango = (minNom == null || nomina >= minNom) && (maxNom == null || nomina <= maxNom);

        final seleccionado = _usuariosSeleccionados.isEmpty || _usuariosSeleccionados.contains(d['nombre']);
        final jefeNominaSeleccionado = _jefeSeleccionado != null ? _mapaJefes[_jefeSeleccionado] : null;
        final perteneceAlJefe = jefeNominaSeleccionado == null ||
            d['nomina'] == jefeNominaSeleccionado ||
            d['reporta'] == jefeNominaSeleccionado;

        return coincideNombre && cumpleFalta && enRango && seleccionado && perteneceAlJefe;
      });

      for (final p in filtradas) {
        final d = p.value;
        sheet.appendRow([
          TextCellValue(fecha),
          TextCellValue(d['nombre'] ?? ''),
          TextCellValue(d['nomina'] ?? ''),
          TextCellValue(d['entrada_planta'] ?? ''),
          TextCellValue(d['salida_planta'] ?? ''),
        ]);
      }
    }

    final List<int>? bytes = excel.encode();
    if (bytes == null) return;

    final fileName = 'Resumen_Checadas.xlsx';

    if (kIsWeb) {
      final blob = html.Blob([Uint8List.fromList(bytes)], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = io.File(filePath);
      await file.writeAsBytes(bytes, flush: true);

      await Share.shareXFiles([XFile(filePath)], text: 'Resumen de checadas generado desde la app');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF023859),
        elevation: 3,
        centerTitle: true,
        title: const Text(
          'Resumen de Checadas',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range, color: Colors.white),
            onPressed: _seleccionarRangoFechas,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _cargarResumen,
          ),
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: _exportarAExcel,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 3,
              color: Colors.white,
              child: StatefulBuilder(
                builder: (context, setInnerState) {
                  return Column(
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          icon: Icon(
                            _mostrarFiltros
                                ? Icons.expand_less
                                : Icons.expand_more,
                          ),
                          label: Text(
                            _mostrarFiltros
                                ? 'Ocultar filtros'
                                : 'Mostrar filtros',
                          ),
                          onPressed: () {
                            setInnerState(
                              () => _mostrarFiltros = !_mostrarFiltros,
                            );
                          },
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        alignment: Alignment.topCenter,
                        child:
                            _mostrarFiltros
                                ? Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '🔍 Filtros de búsqueda',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF023859),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: TextField(
                                              decoration: const InputDecoration(
                                                labelText:
                                                    'Buscar por nombre o nómina',
                                                prefixIcon: Icon(Icons.search),
                                                border: OutlineInputBorder(),
                                              ),
                                              onChanged: (value) {
                                                setState(
                                                  () =>
                                                      _filtroNombre =
                                                          value
                                                              .toLowerCase()
                                                              .trim(),
                                                );
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            flex: 2,
                                            child: DropdownButtonFormField<
                                              String
                                            >(
                                              value: _filtroFalta,
                                              decoration: const InputDecoration(
                                                labelText: 'Tipo de Falta',
                                                border: OutlineInputBorder(),
                                              ),
                                              items:
                                                  tiposFalta.map((tipo) {
                                                    return DropdownMenuItem(
                                                      value: tipo,
                                                      child: Text(
                                                        tipo
                                                            .replaceAll(
                                                              '_',
                                                              ' ',
                                                            )
                                                            .toUpperCase(),
                                                      ),
                                                    );
                                                  }).toList(),
                                              onChanged:
                                                  (value) => setState(
                                                    () =>
                                                        _filtroFalta =
                                                            value ?? 'todos',
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      DropdownButtonFormField<String>(
                                        value: _jefeSeleccionado,
                                        isExpanded: true,
                                        decoration: const InputDecoration(
                                          labelText: 'Filtrar por Jefe',
                                          border: OutlineInputBorder(),
                                          prefixIcon: Icon(Icons.person_pin),
                                        ),
                                        items: [
                                          const DropdownMenuItem(
                                            value: null,
                                            child: Text('Todos los jefes'),
                                          ),
                                          ..._mapaJefes.keys.map((nombre) {
                                            return DropdownMenuItem(
                                              value: nombre,
                                              child: Text(nombre),
                                            );
                                          }).toList(),
                                        ],
                                        onChanged:
                                            (value) => setState(
                                              () => _jefeSeleccionado = value,
                                            ),
                                      ),

                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: _minNominaController,
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: const InputDecoration(
                                                labelText: 'Nómina mínima',
                                                border: OutlineInputBorder(),
                                                prefixIcon: Icon(
                                                  Icons.keyboard_arrow_down,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: TextField(
                                              controller: _maxNominaController,
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: const InputDecoration(
                                                labelText: 'Nómina máxima',
                                                border: OutlineInputBorder(),
                                                prefixIcon: Icon(
                                                  Icons.keyboard_arrow_up,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          IconButton(
                                            icon:
                                                _cargando
                                                    ? const SizedBox(
                                                      height: 22,
                                                      width: 22,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color: Color(
                                                              0xFF023859,
                                                            ),
                                                          ),
                                                    )
                                                    : const Icon(
                                                      Icons.filter_list,
                                                      color: Color(0xFF023859),
                                                    ),
                                            onPressed:
                                                _cargando
                                                    ? null
                                                    : () {
                                                      setState(
                                                        () => _cargando = true,
                                                      );
                                                      Future.delayed(
                                                        const Duration(
                                                          milliseconds: 300,
                                                        ),
                                                        () {
                                                          setState(() {
                                                            _filtroNombre =
                                                                _filtroNombre
                                                                    .trim();
                                                            _minNominaController
                                                                    .text =
                                                                _minNominaController
                                                                    .text
                                                                    .trim();
                                                            _maxNominaController
                                                                    .text =
                                                                _maxNominaController
                                                                    .text
                                                                    .trim();
                                                            _cargando = false;
                                                          });
                                                        },
                                                      );
                                                    },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          ElevatedButton.icon(
                                            icon: const Icon(Icons.group),
                                            label: const Text(
                                              "Seleccionar usuarios",
                                            ),
                                            onPressed: _mostrarDialogoUsuarios,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFF0A78BD,
                                              ),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                          TextButton.icon(
                                            icon: const Icon(Icons.clear),
                                            label: const Text(
                                              "Eliminar filtros",
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _filtroNombre = '';
                                                _filtroFalta = 'todos';
                                                _minNominaController.clear();
                                                _maxNominaController.clear();
                                                _usuariosSeleccionados.clear();
                                              });
                                            },
                                            style: TextButton.styleFrom(
                                              foregroundColor: Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                )
                                : const SizedBox.shrink(),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          Expanded(
            child:
                resumen.isEmpty
                    ? const Center(
                      child: Text(
                        'No hay registros para el rango seleccionado.',
                      ),
                    )
                    : Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.only(bottom: 16),
                            itemCount: _fechasPaginadas.length,
                            itemBuilder: (context, index) {
                              final fechaEntry = _fechasPaginadas[index];
                              final fecha = fechaEntry.key;
                              final personas = fechaEntry.value;

                              final personasOrdenadas =
                                  personas.entries.toList()..sort((a, b) {
                                    dynamic valorA =
                                        a.value[_campoOrdenamiento];
                                    dynamic valorB =
                                        b.value[_campoOrdenamiento];

                                    if (_campoOrdenamiento == 'nomina') {
                                      final intA =
                                          int.tryParse(valorA ?? '') ?? 0;
                                      final intB =
                                          int.tryParse(valorB ?? '') ?? 0;
                                      return _ordenAscendente
                                          ? intA.compareTo(intB)
                                          : intB.compareTo(intA);
                                    } else if (_campoOrdenamiento ==
                                            'entrada_planta' ||
                                        _campoOrdenamiento == 'salida_planta') {
                                      final horaA =
                                          (valorA != null && valorA != '')
                                              ? valorA
                                              : '99:99:99';
                                      final horaB =
                                          (valorB != null && valorB != '')
                                              ? valorB
                                              : '99:99:99';
                                      return _ordenAscendente
                                          ? horaA.compareTo(horaB)
                                          : horaB.compareTo(horaA);
                                    }

                                    return 0;
                                  });

                              final filtradas =
                                  personasOrdenadas.where((p) {
                                    final d = p.value;

                                    final coincideNombre =
                                        _filtroNombre.isEmpty ||
                                        d['nombre']
                                            .toString()
                                            .toLowerCase()
                                            .contains(_filtroNombre) ||
                                        d['nomina']
                                            .toString()
                                            .toLowerCase()
                                            .contains(_filtroNombre);

                                    final cumpleFalta = _cumpleFiltroFalta(d);

                                    final nomina =
                                        int.tryParse(d['nomina'].toString()) ??
                                        0;
                                    final minNom = int.tryParse(
                                      _minNominaController.text,
                                    );
                                    final maxNom = int.tryParse(
                                      _maxNominaController.text,
                                    );

                                    final enRango =
                                        (minNom == null || nomina >= minNom) &&
                                        (maxNom == null || nomina <= maxNom);

                                    final seleccionado =
                                        _usuariosSeleccionados.isEmpty ||
                                        _usuariosSeleccionados.contains(
                                          d['nombre'],
                                        );

                                    // 🔍 Nuevo: filtro por jefe seleccionado
                                    final jefeNominaSeleccionado =
                                        _jefeSeleccionado != null
                                            ? _mapaJefes[_jefeSeleccionado]
                                            : null;

                                    final perteneceAlJefe =
                                        jefeNominaSeleccionado == null ||
                                        d['nomina'] ==
                                            jefeNominaSeleccionado || // El jefe mismo
                                        d['reporta'] ==
                                            jefeNominaSeleccionado; // Subordinados

                                    return coincideNombre &&
                                        cumpleFalta &&
                                        enRango &&
                                        seleccionado &&
                                        perteneceAlJefe;
                                  }).toList();

                              if (filtradas.isEmpty) return const SizedBox();

                              return Padding(
                                padding: const EdgeInsets.all(8),
                                child: Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.calendar_today,
                                              color: Color(0xFF023859),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '📅 $fecha',
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF023859),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              DropdownButton<String>(
                                                value: _campoOrdenamiento,
                                                items:
                                                    _opcionesOrdenamiento.map((
                                                      campo,
                                                    ) {
                                                      return DropdownMenuItem(
                                                        value: campo,
                                                        child: Text(
                                                          'Ordenar por ${_etiquetasOrdenamiento[campo]}',
                                                        ),
                                                      );
                                                    }).toList(),

                                                onChanged: (value) {
                                                  if (value != null) {
                                                    setState(
                                                      () =>
                                                          _campoOrdenamiento =
                                                              value,
                                                    );
                                                  }
                                                },
                                              ),
                                              IconButton(
                                                icon: Icon(
                                                  _ordenAscendente
                                                      ? Icons.arrow_upward
                                                      : Icons.arrow_downward,
                                                  color: const Color(
                                                    0xFF023859,
                                                  ),
                                                ),
                                                tooltip: 'Cambiar orden',
                                                onPressed: _cambiarOrden,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        LayoutBuilder(
                                          builder: (context, constraints) {
                                            return SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              child: ConstrainedBox(
                                                constraints: BoxConstraints(
                                                  minWidth:
                                                      constraints.maxWidth,
                                                ),
                                                child: DataTable(
                                                  showBottomBorder: true,
                                                  columnSpacing: 15,
                                                  headingRowColor:
                                                      MaterialStateProperty.all(
                                                        Colors.blue.shade100,
                                                      ),
                                                  columns: const [
                                                    DataColumn(
                                                      label: Text(
                                                        'Nombre',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    DataColumn(
                                                      label: Text(
                                                        'Nómina',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    DataColumn(
                                                      label: Text(
                                                        'Entrada Planta',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    DataColumn(
                                                      label: Text(
                                                        'Entrada Comedor',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    DataColumn(
                                                      label: Text(
                                                        'Salida Comedor',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    DataColumn(
                                                      label: Text(
                                                        'Salida Planta',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    DataColumn(
                                                      label: Text(
                                                        'Falta',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    DataColumn(
                                                      label: Text(
                                                        'Observaciones',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    DataColumn(
                                                      label: Text(
                                                        'Editar',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                  rows:
                                                      filtradas.map((p) {
                                                        final id = p.key;
                                                        final d = p.value;
                                                        final falta =
                                                            (d['entrada_planta'] ==
                                                                    '' ||
                                                                d['entrada_planta'] ==
                                                                    null) &&
                                                            (d['salida_planta'] ==
                                                                    '' ||
                                                                d['salida_planta'] ==
                                                                    null);
                                                        final faltaEntrada =
                                                            d['entrada_planta'] ==
                                                                '' ||
                                                            d['entrada_planta'] ==
                                                                null;
                                                        final faltaSalida =
                                                            d['salida_planta'] ==
                                                                '' ||
                                                            d['salida_planta'] ==
                                                                null;
                                                        final rowColor =
                                                            falta
                                                                ? Colors
                                                                    .red
                                                                    .shade50
                                                                : null;

                                                        return DataRow(
                                                          color:
                                                              MaterialStateProperty.all(
                                                                rowColor,
                                                              ),
                                                          cells: [
                                                            DataCell(
                                                              Text(
                                                                '${d['nombre'] ?? ''}${falta ? ' ⚠️' : ''}',
                                                                style:
                                                                    falta
                                                                        ? const TextStyle(
                                                                          color:
                                                                              Colors.red,
                                                                        )
                                                                        : null,
                                                              ),
                                                            ),
                                                            DataCell(
                                                              Text(
                                                                d['nomina'] ??
                                                                    '-',
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                              ),
                                                            ),
                                                            DataCell(
                                                              Text(
                                                                d['entrada_planta'] ??
                                                                    '-',
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                              ),
                                                            ),
                                                            DataCell(
                                                              Text(
                                                                d['entrada_comedor'] ??
                                                                    '-',
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                              ),
                                                            ),
                                                            DataCell(
                                                              Text(
                                                                d['salida_comedor'] ??
                                                                    '-',
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                              ),
                                                            ),
                                                            DataCell(
                                                              Text(
                                                                d['salida_planta'] ??
                                                                    '-',
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                              ),
                                                            ),
                                                            DataCell(
                                                              Text(
                                                                (faltaEntrada &&
                                                                        faltaSalida)
                                                                    ? 'Falta'
                                                                    : (faltaEntrada
                                                                        ? 'Omisión Entrada'
                                                                        : (faltaSalida
                                                                            ? 'Omisión Salida'
                                                                            : 'Completo')),
                                                                style: TextStyle(
                                                                  color:
                                                                      faltaEntrada ||
                                                                              faltaSalida
                                                                          ? Colors
                                                                              .red
                                                                          : Colors
                                                                              .green,
                                                                ),
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                              ),
                                                            ),
                                                            DataCell(
                                                              Text(
                                                                d['observaciones'] ??
                                                                    '-',
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                              ),
                                                            ),
                                                            DataCell(
                                                              IconButton(
                                                                icon: const Icon(
                                                                  Icons.edit,
                                                                  color:
                                                                      Colors
                                                                          .blueAccent,
                                                                ),
                                                                tooltip:
                                                                    'Editar fila',
                                                                onPressed: () {
                                                                  Navigator.push(
                                                                    context,
                                                                    MaterialPageRoute(
                                                                      builder:
                                                                          (
                                                                            _,
                                                                          ) => EditarRegistroScreen(
                                                                            id:
                                                                                id,
                                                                            datos:
                                                                                d,
                                                                            fechaResumen:
                                                                                fecha,
                                                                            tarjeta:
                                                                                d['tarjeta'] ??
                                                                                '',
                                                                          ),
                                                                    ),
                                                                  );
                                                                },
                                                              ),
                                                            ),
                                                          ],
                                                        );
                                                      }).toList(),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton.icon(
                              onPressed:
                                  _paginaActual > 0
                                      ? () => setState(() => _paginaActual--)
                                      : null,
                              icon: const Icon(Icons.chevron_left),
                              label: const Text('Anterior'),
                            ),
                            Text(
                              'Página ${_paginaActual + 1} de $_totalPaginas',
                            ),
                            TextButton.icon(
                              onPressed:
                                  _paginaActual < _totalPaginas - 1
                                      ? () => setState(() => _paginaActual++)
                                      : null,
                              icon: const Icon(Icons.chevron_right),
                              label: const Text('Siguiente'),
                            ),
                          ],
                        ),
                      ],
                    ),
          ),
        ],
      ),
    );
  }
}