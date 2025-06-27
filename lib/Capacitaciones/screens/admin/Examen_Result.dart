// ignore_for_file: unused_local_variable
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ExamResultsScreen extends StatefulWidget {
  const ExamResultsScreen({Key? key}) : super(key: key);

  @override
  State<ExamResultsScreen> createState() => _ExamResultsScreenState();
}

class _ExamResultsScreenState extends State<ExamResultsScreen> {

  String _searchEmail = '';
  String? _selectedCourse;
  String? _selectedArea;

  DateTime? _startDate;
  DateTime? _endDate;

  final TextEditingController _searchController = TextEditingController();

  bool _matchesFilters(
      Map<String, dynamic> data,
      String uid,
      Map<String, Map<String, String>> userDetails,
      ) {
    final userInfo = userDetails[uid] ?? {'email': 'Desconocido', 'fullName': 'Sin nombre', 'nomina': 'Sin nómina'};
    final email = userInfo['email']?.toLowerCase() ?? '';
    final fullName = userInfo['fullName']?.toLowerCase() ?? '';
    if (_selectedCourse != null && data['category'] != _selectedCourse)
      return false;
    if (_selectedArea != null && data['area'] != _selectedArea) return false;
    if (_startDate != null &&
        (data['timestamp'] as Timestamp).toDate().isBefore(_startDate!))
      return false;
    if (_endDate != null &&
        (data['timestamp'] as Timestamp).toDate().isAfter(_endDate!))
      return false;
    return true;
  }

  Future<Map<String, Map<String, String>>> _getUserDetails() async {
    final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
    return {
      for (var doc in usersSnapshot.docs)
        doc.id: {
          'email': doc.data()['email'] ?? 'Desconocido',
          'fullName': doc.data()['fullName'] ?? 'Sin nombre',
          'nomina': doc.data()['nomina'] ?? 'Sin nómina',
        },
    };
  }

  Future<List<String>> _getCourses() async {
    final snapshot = await FirebaseFirestore.instance.collection('courses').get();
    return snapshot.docs.map((doc) => doc['title'].toString()).toList();
  }

  Future<List<String>> _getAreas() async {
    final snapshot = await FirebaseFirestore.instance.collection('areas').get();
    return snapshot.docs.map((doc) => doc['name'].toString()).toList();
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2022),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _startDate = DateTime(
          picked.start.year,
          picked.start.month,
          picked.start.day,
          0,
          0,
          0,
        );
        _endDate = DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
        );
      });
    }
  }

  Future<void> _exportToPDF(
      Map<String, Map<String, String>> userDetails,
      List<QueryDocumentSnapshot> docs, {
        bool includePassed = true,
        bool includeAttempts = true,
      }) async {
    final pdf = pw.Document();
    final now = DateTime.now();

    final attempts = docs.where((doc) => (doc['percentage'] ?? 0) < 80).toList();
    final passed = docs.where((doc) => (doc['percentage'] ?? 0) >= 80).toList();

    final filters = [
      'Curso: ${_selectedCourse ?? 'Todos'}',
      'Área: ${_selectedArea ?? 'Todas'}',
      if (_startDate != null && _endDate != null)
        'Fechas: ${DateFormat('dd/MM/yyyy').format(_startDate!)} - ${DateFormat('dd/MM/yyyy').format(_endDate!)}',
      'Exportado: ${DateFormat('dd/MM/yyyy HH:mm').format(now)}',
    ];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Reporte de Resultados de Exámenes',
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Text(
            filters.join('   •   '),
            style: pw.TextStyle(fontSize: 11, color: PdfColors.grey800),
          ),
          pw.SizedBox(height: 12),

          if (includeAttempts && attempts.isNotEmpty) ...[
            pw.Text(
              'Intentos sin acreditar:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            _styledPdfTableFromDocs(attempts, userDetails),
          ],

          if (includePassed && passed.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text(
              'Exámenes acreditados:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            _styledPdfTableFromDocs(passed, userDetails),
          ],

          pw.SizedBox(height: 24),
          pw.Divider(),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Archivo generado automáticamente el ${DateFormat('dd/MM/yyyy HH:mm').format(now)}',
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey700,
              ),
            ),
          ),
        ],
      ),
    );

    final bytes = await pdf.save();

    if (!kIsWeb) {
      await Printing.layoutPdf(onLayout: (format) async => bytes);
    }
  }

  Future<String?> _selectExportOption(BuildContext context) async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Qué deseas exportar?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            ListTile(
              title: Text('Solo intentos no acreditados'),
              leading: Icon(Icons.warning_amber),
            ),
            ListTile(
              title: Text('Solo exámenes acreditados'),
              leading: Icon(Icons.check_circle),
            ),
            ListTile(title: Text('Ambos'), leading: Icon(Icons.all_inbox)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'attempts'),
            child: const Text('Intentos'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'passed'),
            child: const Text('Acreditados'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'both'),
            child: const Text('Ambos'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportSingleExamPDF(
      QueryDocumentSnapshot doc,
      Map<String, Map<String, String>> userDetails,
      ) async {
    final data = doc.data() as Map<String, dynamic>;
    final userInfo = userDetails[data['uid']] ?? {'fullName': 'Desconocido', 'nomina': 'Sin nómina'};
    final respuestas = List<Map<String, dynamic>>.from(data['respuestas'] ?? []);
    final now = DateTime.now();

    final pdf = pw.Document();

    final ByteData bytes = await rootBundle.load('assets/ds.png');
    final Uint8List logoBytes = bytes.buffer.asUint8List();
    final logo = pw.MemoryImage(logoBytes);

    final score = data['score'] ?? 0;
    final total = data['total'] ?? 0;
    final percentage = (data['percentage'] ?? 0).toStringAsFixed(1);
    final category = data['category']?.toString() ?? 'Sin curso';
    final lesson = data['lesson']?.toString() ?? 'Sin lección';
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
    final fecha = timestamp != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(timestamp)
        : 'Fecha desconocida';

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(margin: const pw.EdgeInsets.all(40)),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Generado el ${DateFormat('dd/MM/yyyy HH:mm').format(now)}',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Reporte de Examen Completado',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text('Nombre: ${userInfo['fullName']}'),
                    pw.Text('Nómina: ${userInfo['nomina']}'),
                    pw.Text('Curso: $category'),
                    pw.Text('Lección: $lesson'),
                    pw.Text('Fecha de aplicación: $fecha'),
                    pw.Text(
                      'Resultado: $score / $total  ($percentage%)',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),
              pw.Container(
                height: 60,
                width: 60,
                child: pw.Image(logo),
              ),
            ],
          ),
          pw.Divider(height: 30, thickness: 1),

          pw.Text(
            'Desglose de preguntas:',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),

          ...respuestas.asMap().entries.map((entry) {
            final i = entry.key + 1;
            final r = entry.value;
            final pregunta = r['pregunta']?.toString() ?? 'Sin pregunta';
            final respuestaUsuario =
                r['respuestaUsuario']?.toString() ?? 'No respondida';
            final respuestaCorrecta =
                r['respuestaCorrecta']?.toString() ?? 'Desconocida';
            final esCorrecta = r['esCorrecta'] == true;

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Pregunta $i',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text('Enunciado: $pregunta'),
                pw.Text('Tu respuesta: $respuestaUsuario'),
                pw.Text('Respuesta correcta: $respuestaCorrecta'),
                pw.Text(
                  'Resultado: ${esCorrecta ? 'Correcta' : 'Incorrecta'}',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: esCorrecta ? PdfColors.green : PdfColors.red,
                  ),
                ),
                pw.Divider(height: 18, thickness: 0.5),
              ],
            );
          }),

          pw.SizedBox(height: 30),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Firma del responsable:',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  pw.SizedBox(height: 25),
                  pw.Container(
                    width: 150,
                    height: 0.8,
                    color: PdfColors.grey600,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    final bytesFinal = await pdf.save();

    final sanitizedName = userInfo['fullName']?.split('@').first.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_') ?? 'usuario';
    final sanitizedCourse = category
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    final fechaArchivo = timestamp != null
        ? DateFormat('yyyyMMdd_HHmm').format(timestamp)
        : DateFormat('yyyyMMdd_HHmm').format(now);

    final nombreArchivo = 'examen_${sanitizedName}_$sanitizedCourse$fechaArchivo.pdf';

    await Printing.sharePdf(bytes: bytesFinal, filename: nombreArchivo);
  }

  Future<void> _exportUserHistoryPDF(
      String email,
      List<QueryDocumentSnapshot> attempts,
      Map<String, Map<String, String>> userDetails,
      ) async {
    final pdf = pw.Document();
    final now = DateTime.now();

    // Obtener información del usuario
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    // Determinar el nombre a mostrar: fullName si existe, sino el email
    String displayName = email;
    String nomina = 'Sin nómina';
    String userInfo = 'Correo: $email';

    if (userDoc.docs.isNotEmpty) {
      final data = userDoc.docs.first.data();
      if (data.containsKey('fullName') && data['fullName'] != null && data['fullName'].toString().isNotEmpty) {
        displayName = data['fullName'];
        nomina = data['nomina']?.toString() ?? 'Sin nómina';
        userInfo = 'Nombre: $displayName\nNómina: $nomina\nCorreo: $email';
      }
    }

    if (attempts.isEmpty) {
      debugPrint('⚠️ No hay intentos para el usuario $email');
      return;
    }

    final ByteData bytes = await rootBundle.load('assets/ds.png');
    final Uint8List logoBytes = bytes.buffer.asUint8List();
    final logo = pw.MemoryImage(logoBytes);

    for (int index = 0; index < attempts.length; index++) {
      final doc = attempts[index];
      final data = doc.data() as Map<String, dynamic>;

      final category = data['category']?.toString() ?? 'Sin curso';
      final area = data['area']?.toString() ?? 'Sin área';
      final lesson = data['lesson']?.toString() ?? 'Sin lección';
      final timestampRaw = data['timestamp'];
      final timestamp = timestampRaw is Timestamp ? timestampRaw.toDate() : null;
      final fecha = timestamp != null
          ? DateFormat('dd/MM/yyyy HH:mm').format(timestamp)
          : 'Fecha desconocida';

      final score = data['score'] ?? 0;
      final total = data['total'] ?? 0;
      final percentage = (data['percentage'] ?? 0).toStringAsFixed(1);

      final respuestasRaw = data['respuestas'];
      final respuestas = (respuestasRaw is List)
          ? respuestasRaw
          .whereType<Map>()
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .toList()
          : <Map<String, dynamic>>[];

      pdf.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(margin: const pw.EdgeInsets.all(40)),
          footer: (context) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Generado el ${DateFormat('dd/MM/yyyy HH:mm').format(now)}',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ),
          build: (context) => [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Reporte de Examen Completado',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text('Nombre: $displayName'),
                    pw.Text('Nómina: $nomina'),
                    pw.Text('Correo: $email'),
                    pw.Text('Curso: $category'),
                    pw.Text('Área: $area'),
                    pw.Text('Lección: $lesson'),
                    pw.Text('Fecha de aplicación: $fecha'),
                    pw.Text(
                      'Resultado: $score / $total  ($percentage%)',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
                pw.Container(height: 60, width: 60, child: pw.Image(logo)),
              ],
            ),
            pw.Divider(height: 30, thickness: 1),

            pw.Text(
              'Desglose de preguntas:',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),

            ...respuestas.asMap().entries.map((entry) {
              final i = entry.key + 1;
              final r = entry.value;
              final pregunta = r['pregunta']?.toString() ?? 'Sin pregunta';
              final respuestaUsuario =
                  r['respuestaUsuario']?.toString() ?? 'No respondida';
              final respuestaCorrecta =
                  r['respuestaCorrecta']?.toString() ?? 'Desconocida';
              final esCorrecta = r['esCorrecta'] == true;

              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Pregunta $i',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text('Enunciado: $pregunta'),
                  pw.Text('Tu respuesta: $respuestaUsuario'),
                  pw.Text('Respuesta correcta: $respuestaCorrecta'),
                  pw.Text(
                    'Resultado: ${esCorrecta ? 'Correcta' : 'Incorrecta'}',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey800,
                    ),
                  ),
                  pw.Divider(height: 18, thickness: 0.5),
                ],
              );
            }),

            pw.Container(
              padding: const pw.EdgeInsets.only(top: 20),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Firma del responsable:',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      pw.SizedBox(height: 25),
                      pw.Container(
                        width: 150,
                        height: 0.8,
                        color: PdfColors.grey600,
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

    try {
      final bytes = await pdf.save();
      final sanitized = displayName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final nombreArchivo =
          'historial_examenes_${sanitized}_${DateFormat('yyyyMMdd_HHmm').format(now)}.pdf';

      await Printing.sharePdf(bytes: bytes, filename: nombreArchivo);
    } catch (e) {
      debugPrint('❌ Error al generar o compartir el PDF: $e');
    }
  }

  pw.Widget _styledPdfTableFromDocs(
      List<QueryDocumentSnapshot> docs,
      Map<String, Map<String, String>> userDetails,
      ) {
    return pw.Table.fromTextArray(
      border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey),
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      cellAlignment: pw.Alignment.centerLeft,
      cellStyle: const pw.TextStyle(fontSize: 10),
      headers: ['Nombre', 'Nómina', 'Curso', 'Lección', 'Score', 'Total', '%', 'Fecha'],
      data: docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final userInfo = userDetails[data['uid']] ?? {'fullName': 'Desconocido', 'nomina': 'Sin nómina'};
        final timestamp = (data['timestamp'] as Timestamp).toDate();
        return [
          userInfo['fullName'] ?? 'Desconocido',
          userInfo['nomina'] ?? 'Sin nómina',
          data['category'] ?? '',
          data['lesson'] ?? '',
          data['score'].toString(),
          data['total'].toString(),
          '${(data['percentage'] as num).toStringAsFixed(1)}%',
          DateFormat('dd/MM/yyyy').format(timestamp),
        ];
      }).toList(),
    );
  }

  Widget _buildDataTable(
      List<QueryDocumentSnapshot> docs,
      Map<String, Map<String, String>> userDetails,
      ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              columnSpacing: 16,
              columns: const [
                DataColumn(label: Text('Nombre')),
                DataColumn(label: Text('Nómina')),
                DataColumn(label: Text('Curso')),
                DataColumn(label: Text('Lección')),
                DataColumn(label: Text('Score')),
                DataColumn(label: Text('Total')),
                DataColumn(label: Text('%')),
                DataColumn(label: Text('Fecha')),
                DataColumn(label: Text('Acciones')),
              ],
              rows: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final userInfo = userDetails[data['uid']] ?? {'fullName': 'Desconocido', 'nomina': 'Sin nómina'};
                final timestamp = (data['timestamp'] as Timestamp).toDate();
                final porcentaje = (data['percentage'] as num).toStringAsFixed(1);

                return DataRow(
                  cells: [
                    DataCell(Text(userInfo['fullName'] ?? 'Desconocido')),
                    DataCell(Text(userInfo['nomina'] ?? 'Sin nómina')),
                    DataCell(Text(data['category'] ?? '')),
                    DataCell(Text(data['lesson'] ?? '')),
                    DataCell(Text('${data['score']}')),
                    DataCell(Text('${data['total']}')),
                    DataCell(Text('$porcentaje%')),
                    DataCell(Text(DateFormat('dd/MM/yyyy').format(timestamp))),
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf),
                        tooltip: 'Descargar intento',
                        onPressed: () => _exportSingleExamPDF(doc, userDetails),
                        color: Colors.deepPurpleAccent,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final backgroundGradient = const LinearGradient(
      colors: [Color(0xFF0F2027), Color(0xFF2C5364)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Historial de Exámenes'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Exportar PDF',
            onPressed: () async {
              final userDetails = await _getUserDetails();
              final snapshot = await FirebaseFirestore.instance
                  .collection('exam_results')
                  .orderBy('timestamp', descending: true)
                  .get();
              final filtered = snapshot.docs
                  .where((doc) => _matchesFilters(doc.data(), doc['uid'], userDetails))
                  .toList();

              final option = await _selectExportOption(context);
              if (option == null) return;

              final attempts =
              filtered.where((doc) => (doc['percentage'] ?? 0) < 80).toList();
              final passed =
              filtered.where((doc) => (doc['percentage'] ?? 0) >= 80).toList();

              await _exportToPDF(
                userDetails,
                (option == 'attempts'
                    ? attempts
                    : option == 'passed'
                    ? passed
                    : filtered) as List<QueryDocumentSnapshot<Object?>>,
                includePassed: option != 'attempts',
                includeAttempts: option != 'passed',
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: FutureBuilder<Map<String, Map<String, String>>>(
          future: _getUserDetails(),
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            final userDetails = userSnapshot.data!;

            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 80, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Buscar por correo...',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onChanged: (val) => setState(() => _searchEmail = val.toLowerCase()),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.date_range, color: Colors.white),
                        onPressed: _pickDateRange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<List<String>>(
                    future: _getCourses(),
                    builder: (context, snapshot) {
                      return DropdownButton<String>(
                        hint: const Text('Filtrar por curso'),
                        value: _selectedCourse,
                        isExpanded: true,
                        onChanged: (val) => setState(() => _selectedCourse = val),
                        items: snapshot.data
                            ?.map((course) => DropdownMenuItem(
                          value: course,
                          child: Text(course),
                        ))
                            .toList() ??
                            [],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<List<String>>(
                    future: _getAreas(),
                    builder: (context, snapshot) {
                      return DropdownButton<String>(
                        hint: const Text('Filtrar por área'),
                        value: _selectedArea,
                        isExpanded: true,
                        onChanged: (val) => setState(() => _selectedArea = val),
                        items: snapshot.data
                            ?.map((area) => DropdownMenuItem(
                          value: area,
                          child: Text(area),
                        ))
                            .toList() ??
                            [],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Intentos de Examen',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('exam_results')
                          .orderBy('timestamp', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final docs = snapshot.data!.docs;

                        final filtered = docs.where((doc) {
                          return _matchesFilters(
                            doc.data() as Map<String, dynamic>,
                            doc['uid'],
                            userDetails,
                          );
                        }).toList();

                        final Map<String, List<QueryDocumentSnapshot>>
                        groupedByUser = {};
                        for (var doc in filtered) {
                          final data = doc.data() as Map<String, dynamic>;
                          final uid = data['uid'] as String;
                          groupedByUser.putIfAbsent(uid, () => []).add(doc);
                        }

                        if (groupedByUser.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Text(
                                'No se encontraron resultados con los filtros aplicados.',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          );
                        }

                        return SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          child: Column(
                            children: groupedByUser.entries.map((entry) {
                              final uid = entry.key;
                              final userDocs = entry.value;
                              final userInfo = userDetails[uid] ?? {'fullName': 'Desconocido', 'nomina': 'Sin nómina'};
                              final email = userInfo['email'] ?? 'Desconocido';

                              final attempts = userDocs.where((doc) {
                                final data =
                                doc.data() as Map<String, dynamic>;
                                return (data['percentage'] ?? 0) < 80;
                              }).toList();

                              final passed = userDocs.where((doc) {
                                final data =
                                doc.data() as Map<String, dynamic>;
                                return (data['percentage'] ?? 0) >= 80;
                              }).toList();

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: StatefulBuilder(
                                  builder: (context, setLocalState) {
                                    bool showAllAttempts = false;
                                    bool showAllPassed = false;

                                    final attemptsToShow = showAllAttempts
                                        ? attempts
                                        : attempts.take(10).toList();

                                    final passedToShow = showAllPassed
                                        ? passed
                                        : passed.take(10).toList();

                                    return ExpansionTile(
                                      backgroundColor: const Color(0xFF1E2A38),
                                      collapsedBackgroundColor:
                                      const Color(0xFF16202B),
                                      collapsedIconColor: Colors.white70,
                                      iconColor: Colors.white,
                                      textColor: Colors.white,
                                      title: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            userInfo['fullName'] ?? 'Desconocido',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            'Nómina: ${userInfo['nomina'] ?? 'Sin nómina'}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ),
                                      children: [
                                        if (attempts.isNotEmpty) ...[
                                          const Padding(
                                            padding: EdgeInsets.all(8),
                                            child: Text(
                                              '🟡 Intentos sin acreditar',
                                              style: TextStyle(
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            height: 200,
                                            child: SingleChildScrollView(
                                              scrollDirection: Axis.vertical,
                                              child: _buildDataTable(
                                                attemptsToShow,
                                                userDetails,
                                              ),
                                            ),
                                          ),
                                          if (attempts.length > 10)
                                            TextButton(
                                              onPressed: () => setLocalState(() {
                                                showAllAttempts =
                                                !showAllAttempts;
                                              }),
                                              child: Text(
                                                showAllAttempts
                                                    ? 'Ver menos'
                                                    : 'Ver más',
                                                style: const TextStyle(
                                                  color: Colors.orangeAccent,
                                                ),
                                              ),
                                            ),
                                          const SizedBox(height: 12),
                                        ],
                                        if (passed.isNotEmpty) ...[
                                          const Padding(
                                            padding: EdgeInsets.all(8),
                                            child: Text(
                                              '🟢 Exámenes acreditados',
                                              style: TextStyle(
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            child: ElevatedButton.icon(
                                              onPressed: () async {
                                                print(
                                                    '📤 Exportando historial para $email...');
                                                await _exportUserHistoryPDF(
                                                  email,
                                                  passed,
                                                  userDetails,
                                                );
                                              },
                                              icon: const Icon(Icons.archive),
                                              label: const Text(
                                                  'Descargar historial de exámenes'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                  BorderRadius.circular(10),
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            height: 200,
                                            child: SingleChildScrollView(
                                              scrollDirection: Axis.vertical,
                                              child: _buildDataTable(
                                                passedToShow,
                                                userDetails,
                                              ),
                                            ),
                                          ),
                                          if (passed.length > 10)
                                            TextButton(
                                              onPressed: () => setLocalState(() {
                                                showAllPassed = !showAllPassed;
                                              }),
                                              child: Text(
                                                showAllPassed
                                                    ? 'Ver menos'
                                                    : 'Ver más',
                                                style: const TextStyle(
                                                  color: Colors.lightGreenAccent,
                                                ),
                                              ),
                                            ),
                                          const SizedBox(height: 12),
                                        ],
                                      ],
                                    );
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}