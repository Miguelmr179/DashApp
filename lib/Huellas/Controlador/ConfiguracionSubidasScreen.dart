import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'controladorChecadas.dart';

class ConfiguracionSubidasScreen extends StatefulWidget {
  const ConfiguracionSubidasScreen({Key? key}) : super(key: key);

  @override
  State<ConfiguracionSubidasScreen> createState() => _ConfiguracionSubidasScreenState();
}

class _ConfiguracionSubidasScreenState extends State<ConfiguracionSubidasScreen> {
  List<String> _horasChecadas = [];
  List<String> _horasComedor = [];

  List<Map<String, dynamic>> _checadasPendientes = [];
  List<Map<String, dynamic>> _comidasPendientes = [];

  @override
  void initState() {
    super.initState();
    _cargarHorarios();
    _cargarPendientes();
  }

  Future<void> _cargarHorarios() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _horasChecadas = prefs.getStringList('horasSubidaChecadas') ?? [];
      _horasComedor = prefs.getStringList('horasSubidaComedor') ?? [];
    });
  }

  Future<void> _guardarHoras(String key, List<String> horas) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, horas);
  }

  Future<void> _cargarPendientes() async {
    final prefs = await SharedPreferences.getInstance();
    final cRaw = prefs.getStringList('checadas_locales_checkins_offline') ?? [];
    final mRaw = prefs.getStringList('checadas_locales_comidas_offline') ?? [];

    setState(() {
      _checadasPendientes = cRaw.map((e) => jsonDecode(e)).toList().cast<Map<String, dynamic>>();
      _comidasPendientes = mRaw.map((e) => jsonDecode(e)).toList().cast<Map<String, dynamic>>();
    });
  }

  Future<void> _eliminarRegistroPendiente(String tipo, int index) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'checadas_locales_$tipo';
    final registrosRaw = prefs.getStringList(key) ?? [];

    if (index >= 0 && index < registrosRaw.length) {
      registrosRaw.removeAt(index);
      await prefs.setStringList(key, registrosRaw);
      await _cargarPendientes(); // Recarga la vista
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registro eliminado de $tipo')),
      );
    }
  }

  Future<void> _subir(String tipo) async {
    final service = CheckinService();
    await service.subirChecadasPendientes(tipoRegistro: tipo);
    await _cargarPendientes();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Subido correctamente: $tipo')));
  }

  Widget _buildHorarioConfig(String titulo, String key, List<String> horas, Function(List<String>) onUpdate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
          trailing: IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final seleccion = await showTimePicker(context: context, initialTime: TimeOfDay.now());
              if (seleccion != null) {
                final nuevaHora = '${seleccion.hour.toString().padLeft(2, '0')}:${seleccion.minute.toString().padLeft(2, '0')}';
                final nuevasHoras = [...horas, nuevaHora]..sort();
                await _guardarHoras(key, nuevasHoras);
                onUpdate(nuevasHoras);
              }
            },
          ),
        ),
        Wrap(
          spacing: 8,
          children: horas.map((hora) {
            return Chip(
              label: Text(hora),
              deleteIcon: const Icon(Icons.close),
              onDeleted: () async {
                final nuevasHoras = horas.where((h) => h != hora).toList();
                await _guardarHoras(key, nuevasHoras);
                onUpdate(nuevasHoras);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildRegistroList(String titulo, List<Map<String, dynamic>> registros, String tipo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: Text('$titulo (${registros.length})'),
          trailing: ElevatedButton(
            onPressed: registros.isEmpty ? null : () => _subir(tipo),
            child: const Text('Subir'),
          ),
        ),
        ...registros.asMap().entries.map((entry) {
          final i = entry.key;
          final r = entry.value;
          return ListTile(
            title: Text('${r['Title']}'),
            subtitle: Text(r['Reg_FechaHoraRegistro']),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _eliminarRegistroPendiente(tipo, i),
            ),
          );
        }),
        const Divider(),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F6),
      appBar: AppBar(
        title: const Text(
          'Configuración de Subidas',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF023859),
        centerTitle: true,
        elevation: 4,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.schedule, color: Color(0xFF023859)),
                      SizedBox(width: 8),
                      Text(
                        'Horarios automáticos',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildHorarioConfig(
                    '⏱ Checadas',
                    'horasSubidaChecadas',
                    _horasChecadas,
                        (nuevas) => setState(() => _horasChecadas = nuevas),
                  ),
                  const SizedBox(height: 12),
                  _buildHorarioConfig(
                    '🍽 Comedor',
                    'horasSubidaComedor',
                    _horasComedor,
                        (nuevas) => setState(() => _horasComedor = nuevas),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.list_alt, color: Color(0xFF023859)),
                      SizedBox(width: 8),
                      Text(
                        'Registros pendientes',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildRegistroList('📝 Checadas', _checadasPendientes, 'checkins_offline'),
                  const SizedBox(height: 12),
                  _buildRegistroList('🥘 Comidas', _comidasPendientes, 'comidas_offline'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
