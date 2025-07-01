import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AgregarEventoScreen extends StatefulWidget {
  const AgregarEventoScreen({super.key});

  @override
  State<AgregarEventoScreen> createState() => _AgregarEventoScreenState();
}

class _AgregarEventoScreenState extends State<AgregarEventoScreen> {

  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();
  final Color _primaryColor = Colors.indigo;

  DateTime? _fechaSeleccionada;

  String? _idEventoEditando;

  Future<void> _guardarOActualizarEvento() async {
    if (!_formKey.currentState!.validate() || _fechaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos')),
      );
      return;
    }

    final data = {
      'titulo': _tituloController.text.trim(),
      'descripcion': _descripcionController.text.trim(),
      'fecha': Timestamp.fromDate(_fechaSeleccionada!),
    };

    try {
      if (_idEventoEditando != null) {
        await FirebaseFirestore.instance
            .collection('eventos')
            .doc(_idEventoEditando)
            .update(data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evento actualizado')),
        );
      } else {
        await FirebaseFirestore.instance.collection('eventos').add(data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evento creado')),
        );
      }

      _limpiarFormulario();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _eliminarEvento(String id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar evento'),
        content: const Text('¿Estás seguro de que deseas eliminar este evento?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await FirebaseFirestore.instance.collection('eventos').doc(id).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evento eliminado')),
        );
        if (_idEventoEditando == id) _limpiarFormulario();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
        );
      }
    }
  }

  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('es', 'MX'),
    );

    if (fecha != null) {
      setState(() {
        _fechaSeleccionada = fecha;
      });
    }
  }

  void _limpiarFormulario() {
    _formKey.currentState?.reset();
    _tituloController.clear();
    _descripcionController.clear();
    setState(() {
      _fechaSeleccionada = null;
      _idEventoEditando = null;
    });
  }

  void _cargarEventoParaEditar(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    setState(() {
      _tituloController.text = data['titulo'] ?? '';
      _descripcionController.text = data['descripcion'] ?? '';
      _fechaSeleccionada = (data['fecha'] as Timestamp).toDate();
      _idEventoEditando = doc.id;
    });
  }

  Widget _buildFormulario() {
    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 32),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _idEventoEditando == null ? 'Crear nuevo evento' : 'Editar evento',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _tituloController,
                decoration: const InputDecoration(
                  labelText: 'Título',
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
                      ? DateFormat('dd MMM yyyy', 'es_MX').format(_fechaSeleccionada!)
                      : 'Seleccionar fecha',
                ),
                onTap: _seleccionarFecha,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _guardarOActualizarEvento,
                      icon: Icon(
                          _idEventoEditando == null ? Icons.save : Icons.update),
                      label: Text(_idEventoEditando == null
                          ? 'Guardar evento'
                          : 'Actualizar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  if (_idEventoEditando != null) ...[
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: _limpiarFormulario,
                      child: const Text('Cancelar'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListaEventos() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('eventos')
          .orderBy('fecha')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(top: 20),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final eventos = snapshot.data?.docs ?? [];

        if (eventos.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 20),
            child: Text('No hay eventos registrados.'),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: eventos.length,
          itemBuilder: (context, index) {
            final doc = eventos[index];
            final data = doc.data() as Map<String, dynamic>;
            final fecha = (data['fecha'] as Timestamp).toDate();
            final fechaFormateada =
            DateFormat('dd MMM yyyy', 'es_MX').format(fecha);

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                title: Text(
                  data['titulo'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('${data['descripcion']}\n📅 $fechaFormateada'),
                isThreeLine: true,
                trailing: Wrap(
                  spacing: 0,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blueAccent),
                      onPressed: () => _cargarEventoParaEditar(doc),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () => _eliminarEvento(doc.id),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Gestión de Eventos'),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // Fondo degradado corporativo
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF3E4EB8), // Azul institucional
                  Color(0xFF4F5D75), // Gris azulado
                ],
              ),
            ),
          ),

          // Cuerpo principal
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildFormulario(),
                    const SizedBox(height: 10),
                    Container(
                      alignment: Alignment.centerLeft,
                      child: const Text(
                        '📅 Eventos registrados',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildListaEventos(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

}
