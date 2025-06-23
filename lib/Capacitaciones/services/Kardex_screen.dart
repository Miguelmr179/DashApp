
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dashapp/Capacitaciones/services/theme_notifier.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle, ByteData, Uint8List;

class CardexScreen extends StatefulWidget {
  const CardexScreen({super.key});

  @override
  State<CardexScreen> createState() => _CardexScreenState();
}

class _CardexScreenState extends State<CardexScreen> {
  final Map<String, Map<String, String>> _userInfo = {};
  String _searchText = '';
  String? _selectedYear;
  String? _selectedArea;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1600), () {
      setState(() {
        _searchText = value.toLowerCase();
      });
    });
  }

  Future<Map<String, Map<int, List<Map<String, dynamic>>>>> _buildCardexFromSnapshot(QuerySnapshot snapshot) async {
    final Map<String, Map<int, Map<String, List<Map<String, dynamic>>>>> tempData = {};

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final uid = data['uid'];
      final category = data['category'] ?? 'Sin categoría';
      final score = (data['percentage'] ?? 0).toDouble();
      final timestamp = data['timestamp'];
      final completedAt = timestamp is Timestamp ? timestamp.toDate() : DateTime.now();
      final year = completedAt.year;

      if (score >= 80) {
        tempData.putIfAbsent(uid, () => {});
        tempData[uid]!.putIfAbsent(year, () => {});
        tempData[uid]![year]!.putIfAbsent(category, () => []);
        tempData[uid]![year]![category]!.add({
          'score': score,
          'date': completedAt,
          'lesson': data['lesson'] ?? 'Sin nombre',
        });
      }
    }

    final Map<String, Map<int, List<Map<String, dynamic>>>> cardex = {};

    for (final uid in tempData.keys) {
      cardex[uid] = {};
      tempData[uid]!.forEach((year, courseMap) {
        cardex[uid]![year] = [];
        courseMap.forEach((course, registros) {
          final avg = registros.map((e) => e['score'] as double).reduce((a, b) => a + b) / registros.length;
          final latestDate = registros.map((e) => e['date'] as DateTime).reduce((a, b) => a.isAfter(b) ? a : b);
          cardex[uid]![year]!.add({
            'course': course,
            'score': avg,
            'date': latestDate,
            'lessons': registros.map((e) => {
              'lesson': e['lesson'] ?? 'Lección desconocida',
              'score': e['score'] as double,
            }).toList()
          });

        });
      });

      if (!_userInfo.containsKey(uid)) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (userDoc.exists) {
          final data = userDoc.data()!;
          final fullName = data['fullName']?.toString().trim() ?? 'Usuario desconocido';
          final nomina = data['nomina']?.toString().trim() ?? '---';
          final area = data['area']?.toString().trim() ?? 'Sin área';
          _userInfo[uid] = {'fullName': fullName, 'nomina': nomina, 'area': area};
        } else {
          _userInfo[uid] = {'fullName': 'Usuario desconocido', 'nomina': '---', 'area': 'Sin área'};
        }
      }
    }

    return cardex;
  }

  Future<void> _exportSingleUserToPDF(String uid, Map<int, List<Map<String, dynamic>>> cardex) async {
    final pdf = pw.Document();
    final sortedYears = cardex.keys.toList()..sort((a, b) => b.compareTo(a));
    final now = DateTime.now();
    final fecha = DateFormat('dd/MM/yyyy HH:mm').format(now);
    final user = _userInfo[uid] ?? {'fullName': 'Usuario', 'nomina': '---', 'area': '---'};

    final ByteData bytes = await rootBundle.load('assets/Logodcc.png');
    final Uint8List logoBytes = bytes.buffer.asUint8List();
    final logo = pw.MemoryImage(logoBytes);

    double totalSum = 0;
    int totalCourses = 0;

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          final content = <pw.Widget>[
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Historial Académico - Producción', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 10),
                    pw.Text('Nombre: ${user['fullName']}', style: pw.TextStyle(fontSize: 12)),
                    pw.Text('Nómina: ${user['nomina']}', style: pw.TextStyle(fontSize: 12)),

                  ],
                ),
                pw.Container(height: 80, width: 150, child: pw.Image(logo)),
              ],
            ),
            pw.SizedBox(height: 20),
          ];

          for (var year in sortedYears) {
            content.add(pw.Text('$year', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)));
            content.add(pw.SizedBox(height: 10));

            for (var item in cardex[year]!) {
              final score = item['score'] as double;
              totalSum += score;
              totalCourses += 1;

              content.add(
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
                    children: [
                      pw.Expanded(
                        flex: 1,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('${item['course']}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 4),
                            pw.Text('Promedio: ${score.toStringAsFixed(1)}%', style: pw.TextStyle(fontSize: 11)),
                            pw.Text('Fecha: ${DateFormat('dd-MM-yyyy').format(item['date'])}', style: pw.TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 20),
                      pw.Expanded(
                        flex: 1,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Lecciones acreditadas:', style: pw.TextStyle(fontSize: 11, decoration: pw.TextDecoration.underline)),
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
              );
            }
          }

          final promedioFinal = totalCourses > 0 ? (totalSum / totalCourses) : 0.0;

          content.add(pw.SizedBox(height: 20));
          content.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.grey500),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    'Promedio general de cursos: ${promedioFinal.toStringAsFixed(2)}%',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ),
          );

          content.add(pw.Divider());
          content.add(
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Documento generado el $fecha', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            ),
          );

          return content;
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }


  Future<void> _exportAllUsersToPDF(Map<String, Map<int, List<Map<String, dynamic>>>> allCardex) async {
    final pdf = pw.Document();
    final ByteData bytes = await rootBundle.load('assets/Logodcc.png');
    final Uint8List logoBytes = bytes.buffer.asUint8List();
    final logo = pw.MemoryImage(logoBytes);
    final now = DateTime.now();
    final fecha = DateFormat('dd/MM/yyyy HH:mm').format(now);

    for (final entry in allCardex.entries) {
      final uid = entry.key;
      final cardex = entry.value;
      final user = _userInfo[uid] ?? {'fullName': 'Usuario', 'nomina': '---', 'area': '---'};
      final sortedYears = cardex.keys.toList()..sort((a, b) => b.compareTo(a));

      double totalSum = 0;
      int totalCourses = 0;

      pdf.addPage(
        pw.MultiPage(
          margin: const pw.EdgeInsets.all(32),
          build: (context) {
            final content = <pw.Widget>[
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Historial Académico - Producción', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 10),
                      pw.Text('Nombre: ${user['fullName']}', style: pw.TextStyle(fontSize: 12)),
                      pw.Text('Nómina: ${user['nomina']}', style: pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                  pw.Container(height: 80, width: 150, child: pw.Image(logo)),
                ],
              ),
              pw.SizedBox(height: 20),
            ];

            for (var year in sortedYears) {
              content.add(pw.Text('$year', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)));
              content.add(pw.SizedBox(height: 10));

              for (var item in cardex[year]!) {
                final score = item['score'] as double;
                totalSum += score;
                totalCourses += 1;

                content.add(
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
                      children: [
                        pw.Expanded(
                          flex: 1,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('${item['course']}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                              pw.SizedBox(height: 4),
                              pw.Text('Promedio: ${score.toStringAsFixed(1)}%', style: pw.TextStyle(fontSize: 11)),
                              pw.Text('Última fecha: ${DateFormat('dd-MM-yyyy').format(item['date'])}', style: pw.TextStyle(fontSize: 11)),
                            ],
                          ),
                        ),
                        pw.SizedBox(width: 20),
                        pw.Expanded(
                          flex: 1,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Lecciones acreditadas:', style: pw.TextStyle(fontSize: 11, decoration: pw.TextDecoration.underline)),
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
                );
              }
            }

            final promedioFinal = totalCourses > 0 ? (totalSum / totalCourses) : 0.0;

            content.add(pw.SizedBox(height: 20));
            content.add(
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.grey500),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Promedio general de cursos: ${promedioFinal.toStringAsFixed(2)}%',
                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),
            );

            content.add(pw.Divider());
            content.add(
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text('Documento generado el $fecha', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              ),
            );

            return content;
          },
        ),
      );
    }

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }



  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.value == ThemeMode.dark;
    final bgGradient = isDark
        ? const LinearGradient(colors: [Color(0xFF232526), Color(0xFF414345)], begin: Alignment.topCenter, end: Alignment.bottomCenter)
        : const LinearGradient(colors: [Color(0xFFF5F7FA), Color(0xFFE4E7ED)], begin: Alignment.topCenter, end: Alignment.bottomCenter);

    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        title: const Text('Cardex Anual'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () {
              setState(() {
                _searchText = '';
                _searchController.clear();
                _selectedYear = null;
                _selectedArea = null;
              });
            },
            tooltip: 'Limpiar filtros',
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Exportar todo en PDF',
            onPressed: () async {
              final snapshot = await FirebaseFirestore.instance.collection('exam_results').get();
              final data = await _buildCardexFromSnapshot(snapshot);
              await _exportAllUsersToPDF(data);
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Exportar usuario por usuario',
            onPressed: () async {
              final snapshot = await FirebaseFirestore.instance.collection('exam_results').get();
              final data = await _buildCardexFromSnapshot(snapshot);
              for (final uid in data.keys) {
                await _exportSingleUserToPDF(uid, data[uid]!);
              }
            },
          ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.only(top: kToolbarHeight - 20),
        decoration: BoxDecoration(gradient: bgGradient),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('exam_results').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('No hay datos de exámenes.'));
            }

            return FutureBuilder<Map<String, Map<int, List<Map<String, dynamic>>>>>(
              future: _buildCardexFromSnapshot(snapshot.data!),
              builder: (context, futureSnapshot) {
                if (!futureSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final cardex = futureSnapshot.data!;
                final allYears = cardex.values.expand((e) => e.keys).toSet().toList()..sort();

                final filteredCardex = cardex.entries.where((entry) {
                  final uid = entry.key;
                  final user = _userInfo[uid];
                  final nameMatch = user?['fullName']?.toLowerCase().contains(_searchText) ?? false;
                  final nominaMatch = user?['nomina']?.toLowerCase().contains(_searchText) ?? false;
                  final areaMatch = _selectedArea == null || user?['area'] == _selectedArea;
                  final yearMatch = _selectedYear == null || entry.value.keys.any((year) => year.toString() == _selectedYear);
                  return (nameMatch || nominaMatch) && areaMatch && yearMatch;
                }).toList();

                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Column(
                      children: [
                        TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            labelText: 'Buscar por nombre o nómina',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: _onSearchChanged,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedYear,
                                hint: const Text('Filtrar por año'),
                                items: allYears.map((year) => DropdownMenuItem(
                                  value: year.toString(),
                                  child: Text(year.toString()),
                                )).toList(),
                                onChanged: (value) => setState(() => _selectedYear = value),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ...filteredCardex.map((entry) {
                      final uid = entry.key;
                      final years = entry.value;
                      final fullName = _userInfo[uid]?['fullName'] ?? 'Usuario';
                      final nomina = _userInfo[uid]?['nomina'] ?? '---';

                      return Card(
                        elevation: 6,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fullName,
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                              ),
                              Text(
                                'Nómina: $nomina',
                                style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[300] : Colors.grey[800]),
                              ),
                              const SizedBox(height: 12),
                              ...years.entries.map((yearEntry) {
                                final year = yearEntry.key;
                                final courses = yearEntry.value;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$year',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.cyan[200] : Colors.blueGrey[800]),
                                    ),
                                    const SizedBox(height: 8),
                                    ...courses.map((courseData) {
                                      final score = courseData['score'];
                                      final color = score >= 80 ? Colors.green : Colors.redAccent;
                                      final dateFormatted = DateFormat('dd-MM-yyyy').format(courseData['date']);

                                      return Container(
                                        margin: const EdgeInsets.symmetric(vertical: 6),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF9F9F9),
                                          border: Border(left: BorderSide(width: 4, color: color)),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.school, size: 20),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    courseData['course'] ?? '',
                                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                                                  ),
                                                  Text(
                                                    'Promedio: ${score.toStringAsFixed(1)} - $dateFormatted',
                                                    style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.grey[700]),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Icon(Icons.check_circle, color: color),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  fullName,
                                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.picture_as_pdf),
                                                  tooltip: 'Exportar PDF individual',
                                                  onPressed: () async {
                                                    await _exportSingleUserToPDF(uid, years);
                                                  },
                                                )
                                              ],
                                            ),

                                          ],
                                        ),
                                      );
                                    })
                                  ],
                                );
                              })
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}