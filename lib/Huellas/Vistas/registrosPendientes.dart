import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class RegistrosPendientesScreen extends StatefulWidget {
  final String tipoRegistro; // 'checkins_offline' o 'comidas_offline'
  const RegistrosPendientesScreen({super.key, required this.tipoRegistro});

  @override
  State<RegistrosPendientesScreen> createState() => _RegistrosPendientesScreenState();
}

class _RegistrosPendientesScreenState extends State<RegistrosPendientesScreen> {
  List<Map<String, dynamic>> registros = [];

  @override
  void initState() {
    super.initState();
    _cargarRegistros();
  }

  Future<void> _cargarRegistros() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('checadas_locales_${widget.tipoRegistro}') ?? [];
    setState(() {
      registros = data.map((e) {
        final json = jsonDecode(e) as Map<String, dynamic>;
        debugPrint('Registro cargado: $json');
        return json;
      }).toList();
    });

  }

  String _formatearFecha(String iso) {
    final fecha = DateTime.tryParse(iso);
    if (fecha == null) return iso;
    return DateFormat('dd/MM/yyyy hh:mm a', 'es_MX').format(fecha);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('Registros Pendientes', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: registros.isEmpty
            ? const Center(
          child: Text(
            'No hay registros pendientes.',
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
        )
            : ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 100, horizontal: 20),
          itemCount: registros.length,
          itemBuilder: (context, index) {
            final r = registros[index];
            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 6,
              margin: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.white,
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text(
                  r['Title'] ?? r['nombre'] ?? 'Desconocido',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    if (r.containsKey('tarjeta') || r.containsKey('Reg_no'))
                      Text('Tarjeta: ${r['tarjeta'] ?? r['Reg_no']}'),
                    if (r.containsKey('hora') && r.containsKey('fecha'))
                      Text('Hora: ${r['fecha']} ${r['hora']}')
                    else if (r.containsKey('Reg_FechaHoraRegistro'))
                      Text('Hora: ${_formatearFecha(r['Reg_FechaHoraRegistro'])}'),
                    if (r.containsKey('tipo'))
                      Text('Tipo: ${r['tipo']}'),
                    ...r.entries.where((e) =>
                    !['Title', 'nombre', 'tarjeta', 'Reg_no', 'fecha', 'hora', 'tipo', 'area', 'Reg_FechaHoraRegistro']
                        .contains(e.key)).map((e) =>
                        Text('${e.key}: ${e.value}')),
                  ],
                ),
                leading: const Icon(Icons.schedule, color: Colors.blueAccent, size: 30),
              ),
            );
          },
        ),
      ),
    );
  }
}
