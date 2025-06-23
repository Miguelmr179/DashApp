import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AgregarEventoScreen extends StatefulWidget {
  const AgregarEventoScreen({super.key});

  @override
  State<AgregarEventoScreen> createState() => _AgregarEventoScreenState();
}

class _AgregarEventoScreenState extends State<AgregarEventoScreen> {
  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();
  DateTime? _fechaSeleccionada;

  final _formKey = GlobalKey<FormState>();

  Future<void> _guardarEvento() async {
    if (!_formKey.currentState!.validate() || _fechaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('eventos').add({
        'titulo': _tituloController.text.trim(),
        'descripcion': _descripcionController.text.trim(),
        'fecha': Timestamp.fromDate(_fechaSeleccionada!),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Evento guardado correctamente')),
      );

      Navigator.pop(context); // Regresa al menú anterior
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    }
  }

  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      locale: const Locale('es', 'MX'),
    );

    if (fecha != null) {
      setState(() {
        _fechaSeleccionada = fecha;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Evento'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _tituloController,
                decoration: const InputDecoration(
                  labelText: 'Título del evento',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                value == null || value.isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _descripcionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                value == null || value.isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text(
                  _fechaSeleccionada != null
                      ? DateFormat('dd MMM yyyy', 'es_MX')
                      .format(_fechaSeleccionada!)
                      : 'Seleccionar fecha',
                ),
                onTap: _seleccionarFecha,
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _guardarEvento,
                icon: const Icon(Icons.save),
                label: const Text('Guardar evento'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
