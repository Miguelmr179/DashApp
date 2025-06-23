import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';


import '../Controlador/GuardarRegistroEnCambios.dart';

class EditarRegistroScreen extends StatefulWidget {
  final String id;
  final Map<String, dynamic> datos;

  final String fechaResumen;
  final String tarjeta;

  const EditarRegistroScreen({
    Key? key,
    required this.id,
    required this.datos,
    required this.fechaResumen,
    required this.tarjeta
  }) : super(key: key);

  @override
  State<EditarRegistroScreen> createState() => _EditarRegistroScreenState();
}

class _EditarRegistroScreenState extends State<EditarRegistroScreen> {
  late final TextEditingController _nombreController;
  late final TextEditingController _nominaController;
  late final TextEditingController _observacionesController;

  late DateTime _fechaSeleccionada;

  TimeOfDay? _entradaPlanta;
  TimeOfDay? _salidaPlanta;
  TimeOfDay? _entradaComedor;
  TimeOfDay? _salidaComedor;

  @override
  void initState() {
    super.initState();
    final d = widget.datos;


    _nombreController = TextEditingController(text: d['nombre']?.toString() ?? d['Title']?.toString() ?? '');
    _nominaController = TextEditingController(text: d['nomina']?.toString() ?? d['Reg_no']?.toString() ?? '');
    _observacionesController = TextEditingController(text: d['observaciones']?.toString() ?? '');

    try {
      _fechaSeleccionada = DateFormat('yyyy-MM-dd').parseStrict(widget.fechaResumen);
    } catch (_) {
      _fechaSeleccionada = DateTime.now();
    }


    _entradaPlanta = _parseHora(d['entrada_planta']);
    _salidaPlanta = _parseHora(d['salida_planta']);
    _entradaComedor = _parseHora(d['entrada_comedor']);
    _salidaComedor = _parseHora(d['salida_comedor']);
  }

  TimeOfDay? _parseHora(dynamic horaStr) {
    if (horaStr == null || horaStr.toString().isEmpty) return null;
    try {
      final parts = horaStr.toString().split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return null;
    }
  }

  String _formatTimeOfDay(TimeOfDay? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('HH:mm:ss').format(dt);
  }

  Future<void> _seleccionarHora(String label, TimeOfDay? inicial, Function(TimeOfDay) onSelected) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: inicial ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        onSelected(picked);
      });
    }
  }

  Future<void> _seleccionarFecha(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime(2022),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('es', 'MX'),
    );
    if (picked != null) {
      setState(() {
        _fechaSeleccionada = picked;
      });
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _nominaController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String regNo = _nominaController.text.trim();
    final String title = _nombreController.text.trim().isEmpty ? 'Sin nombre' : _nombreController.text.trim();
    final String fecha = DateFormat('yyyy-MM-dd').format(_fechaSeleccionada);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Registro de Checadas'),
        backgroundColor: Colors.blue.shade800,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _campoTexto('Nombre', _nombreController),
              _campoTexto('Nómina', _nominaController),
              _campoFecha(context),
              const Divider(height: 24),
              _campoHora('Entrada Planta', _entradaPlanta, (val) => _entradaPlanta = val),
              _campoHora('Salida Planta', _salidaPlanta, (val) => _salidaPlanta = val),
              _campoHora('Entrada Comedor', _entradaComedor, (val) => _entradaComedor = val),
              _campoHora('Salida Comedor', _salidaComedor, (val) => _salidaComedor = val),
              const Divider(height: 24),
              _campoTexto('Observaciones', _observacionesController, maxLines: 3),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  if (regNo.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Error: Falta número de tarjeta')),
                    );
                    return;
                  }

                  final Timestamp now = Timestamp.now();

                  final Map<String, TimeOfDay?> checadas = {
                    'entrada_planta': _entradaPlanta,
                    'salida_planta': _salidaPlanta,
                    'entrada_comedor': _entradaComedor,
                    'salida_comedor': _salidaComedor,
                  };

                  for (final tipo in checadas.keys) {
                    final time = checadas[tipo];
                    if (time == null) continue;

                    final horaStr = _formatTimeOfDay(time);

                    final registro = {
                      'Reg_no': regNo,
                      'Title': title,
                      'fecha': fecha,
                      'hora': horaStr,
                      'tipo': tipo,
                      'timestamp': now,
                      'Reg_Fecha': now.toDate(),
                      'Reg_FechaHoraRegistro': now,
                      'observaciones': _observacionesController.text.trim(),
                    };

                    await guardarRegistroEnCambios(registro);
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Todos los registros fueron guardados.')),
                  );

                  Navigator.pop(context);
                },
                icon: const Icon(Icons.save),
                label: const Text('Guardar cambios'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _campoTexto(String label, TextEditingController controller, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _campoHora(String label, TimeOfDay? value, Function(TimeOfDay) onSelected) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: () => _seleccionarHora(label, value, onSelected),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.access_time),
          ),
          child: Text(
            value != null ? _formatTimeOfDay(value) : 'Seleccionar hora',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }

  Widget _campoFecha(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: () => _seleccionarFecha(context),
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Fecha',
            border: OutlineInputBorder(),
            suffixIcon: Icon(Icons.calendar_today),
          ),
          child: Text(
            DateFormat('yyyy-MM-dd').format(_fechaSeleccionada),
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
