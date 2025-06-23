import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:dashapp/Capacitaciones/services/theme_notifier.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show ByteData, Uint8List, rootBundle;

class UserCardexScreen extends StatefulWidget {
  const UserCardexScreen({super.key});

  @override
  State<UserCardexScreen> createState() => _UserCardexScreenState();
}

class _UserCardexScreenState extends State<UserCardexScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;
  late Future<Map<int, List<Map<String, dynamic>>>> _userCardex;
  Map<String, String> _userInfo = {'fullName': '', 'nomina': '', 'area': ''};
  int? _selectedYear;
  String _searchText = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _userCardex = _loadUserCardex();
    _loadUserInfo();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      _userInfo = {
        'fullName': data['fullName'] ?? 'Desconocido',
        'nomina': data['nomina'] ?? '---',
        'area': data['area'] ?? 'Sin área',
      };
    }
  }

  Future<Map<int, List<Map<String, dynamic>>>> _loadUserCardex() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('exam_results')
        .where('uid', isEqualTo: currentUser!.uid)
        .get();

    final temp = <int, Map<String, List<Map<String, dynamic>>>>{};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final score = (data['percentage'] ?? 0).toDouble();
      if (score < 80) continue;

      final course = data['category'] ?? 'Sin categoría';
      final lesson = data['lesson'] ?? 'Lección desconocida';
      final date = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
      final year = date.year;

      temp.putIfAbsent(year, () => {});
      temp[year]!.putIfAbsent(course, () => []);
      temp[year]![course]!.add({'score': score, 'date': date, 'lesson': lesson});
    }

    final result = <int, List<Map<String, dynamic>>>{};
    temp.forEach((year, courses) {
      result[year] = [];
      courses.forEach((course, registros) {
        final avg = registros.map((r) => r['score'] as double).reduce((a, b) => a + b) / registros.length;
        final latest = registros.map((r) => r['date'] as DateTime).reduce((a, b) => a.isAfter(b) ? a : b);
        final lessons = registros
            .map((r) => {
          'lesson': r['lesson'] as String,
          'score': r['score'] as double,
        })
            .toList()
          ..sort((a, b) => (a['lesson'] as String).compareTo(b['lesson'] as String));
        result[year]!.add({'course': course, 'score': avg, 'date': latest, 'lessons': lessons});
      });
    });

    return result;
  }

  void _exportToPDF(Map<int, List<Map<String, dynamic>>> cardex) async {
    final pdf = pw.Document();
    final sortedYears = cardex.keys.toList()..sort((a, b) => b.compareTo(a));
    final now = DateTime.now();
    final fecha = DateFormat('dd/MM/yyyy HH:mm').format(now);

    final ByteData bytes = await rootBundle.load('assets/Logodcc.png');
    final Uint8List logoBytes = bytes.buffer.asUint8List();
    final logo = pw.MemoryImage(logoBytes);

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Historial Académico - Producción',
                      style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 10),
                  pw.Text('Nombre: ${_userInfo['fullName']}', style: pw.TextStyle(fontSize: 12)),
                  pw.Text('Nómina: ${_userInfo['nomina']}', style: pw.TextStyle(fontSize: 12)),
                  pw.Text('Área: ${_userInfo['area']}', style: pw.TextStyle(fontSize: 12)),
                ],
              ),
              pw.Container(
                height: 80,
                width: 150,
                child: pw.Image(logo),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          for (var year in sortedYears) ...[
            pw.Text('$year', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
            pw.SizedBox(height: 10),
            for (var item in cardex[year]!) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                margin: const pw.EdgeInsets.only(bottom: 10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.grey400),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      flex: 1,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('${item['course']}',
                              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 4),
                          pw.Text('Promedio: ${(item['score'] as double).toStringAsFixed(1)}%',
                              style: const pw.TextStyle(fontSize: 11)),
                          pw.Text('Última fecha: ${DateFormat('dd-MM-yyyy').format(item['date'])}',
                              style: const pw.TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 20),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Lecciones acreditadas:',
                              style: pw.TextStyle(fontSize: 11, decoration: pw.TextDecoration.underline)),
                          pw.SizedBox(height: 4),
                          ...((item['lessons'] as List).map((l) => pw.Bullet(
                            text: '${l['lesson']} (${(l['score'] as double).toStringAsFixed(1)}%)',
                            style: const pw.TextStyle(fontSize: 10),
                          ))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
          pw.Divider(),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Documento generado automáticamente el $fecha',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.value == ThemeMode.dark;
    final bgGradient = isDark
        ? const LinearGradient(colors: [Color(0xFF1C1C1E), Color(0xFF2C2C2E)], begin: Alignment.topCenter, end: Alignment.bottomCenter)
        : const LinearGradient(colors: [Color(0xFFE8EDF2), Color(0xFFF8FAFB)], begin: Alignment.topCenter, end: Alignment.bottomCenter);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Historial Anual'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Exportar PDF',
            onPressed: () async {
              final data = await _userCardex;
              _exportToPDF(data);
            },
          )
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: bgGradient),
        child: FutureBuilder<Map<int, List<Map<String, dynamic>>>>(
          future: _userCardex,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('Aún no has acreditado cursos.', style: TextStyle(fontSize: 16)));
            }

            final cardex = snapshot.data!;
            final allYears = cardex.keys.toList()..sort((a, b) => b.compareTo(a));
            final filteredCardex = <int, List<Map<String, dynamic>>>{};

            for (var year in allYears) {
              if (_selectedYear != null && _selectedYear != year) continue;
              final filtered = cardex[year]!.where((data) {
                final course = data['course'].toString().toLowerCase();
                final lessons = (data['lessons'] as List)
                    .map((l) => l['lesson'].toString().toLowerCase())
                    .join(' ');
                return course.contains(_searchText.toLowerCase()) || lessons.contains(_searchText.toLowerCase());
              }).toList();
              if (filtered.isNotEmpty) {
                filteredCardex[year] = filtered;
              }
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Buscar por curso o lección',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => _searchText = value),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: _selectedYear,
                  decoration: const InputDecoration(labelText: 'Filtrar por año'),
                  items: allYears
                      .map((year) => DropdownMenuItem(value: year, child: Text('$year')))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedYear = value),
                ),
                const SizedBox(height: 20),
                ...filteredCardex.entries.map((entry) {
                  final year = entry.key;
                  final registros = entry.value;

                  return Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$year', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.cyan[200] : Colors.blueGrey[800])),
                          const SizedBox(height: 12),
                          ...registros.map((data) {
                            final score = data['score'] as double;
                            final course = data['course'] as String;
                            final date = DateFormat('dd-MM-yyyy').format(data['date']);
                            final lessons = (data['lessons'] as List).cast<Map<String, dynamic>>();
                            final color = score >= 80 ? Colors.green : Colors.red;

                            return ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: Row(
                                children: [
                                  const Icon(Icons.school, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(course, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                                  ),
                                  Icon(Icons.check_circle, color: color),
                                ],
                              ),
                              subtitle: Text('Promedio: ${score.toStringAsFixed(1)} - $date', style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.grey[700])),
                              children: [
                                const SizedBox(height: 8),
                                Text('Lecciones acreditadas:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.grey[800])),
                                ...lessons.map((lessonData) {
                                  final String lesson = lessonData['lesson'];
                                  final double lessonScore = lessonData['score'];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              const Text('• ', style: TextStyle(fontSize: 12)),
                                              Expanded(
                                                child: Text(
                                                  lesson,
                                                  style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[300] : Colors.grey[700]),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '${lessonScore.toStringAsFixed(1)}%',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: lessonScore >= 80 ? Colors.green[600] : Colors.red),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                const SizedBox(height: 8),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                })
              ],
            );
          },
        ),
      ),
    );
  }
}
