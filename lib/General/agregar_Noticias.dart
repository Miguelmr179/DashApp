/*
Version WEB

* import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';

class AgregarNoticiaScreen extends StatefulWidget {
  const AgregarNoticiaScreen({super.key});

  @override
  State<AgregarNoticiaScreen> createState() => _AgregarNoticiaScreenState();
}

class _AgregarNoticiaScreenState extends State<AgregarNoticiaScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _contenidoController = TextEditingController();

  Uint8List? _imagenBytes;
  String? _imagenNombre;
  String? _urlImagenActual;
  String? _idNoticiaEditando;
  bool _subiendo = false;

  Future<void> _seleccionarImagen() async {
    final input = html.FileUploadInputElement()..accept = 'image/*';
    input.click();

    input.onChange.listen((event) {
      final file = input.files!.first;
      final reader = html.FileReader();

      reader.readAsArrayBuffer(file);
      reader.onLoadEnd.listen((event) {
        setState(() {
          _imagenBytes = reader.result as Uint8List;
          _imagenNombre = file.name;
        });
      });
    });
  }

  Future<String?> _subirImagen() async {
    if (_imagenBytes == null || _imagenNombre == null) return _urlImagenActual;

    final storageRef = FirebaseStorage.instance
        .ref()
        .child('noticias_imagenes')
        .child('${DateTime.now().millisecondsSinceEpoch}_$_imagenNombre');

    final uploadTask = await storageRef.putData(_imagenBytes!);
    return await uploadTask.ref.getDownloadURL();
  }

  Future<void> _guardarOActualizarNoticia() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _subiendo = true);

    try {
      String? urlImagen = await _subirImagen();

      final noticiaData = {
        'titulo': _tituloController.text.trim(),
        'contenido': _contenidoController.text.trim(),
        'timestamp': Timestamp.now(),
        'autor': 'Administrador',
        'imagenUrl': urlImagen,
      };

      if (_idNoticiaEditando != null) {
        await FirebaseFirestore.instance
            .collection('noticias')
            .doc(_idNoticiaEditando)
            .update(noticiaData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Noticia actualizada')),
        );
      } else {
        await FirebaseFirestore.instance.collection('noticias').add(noticiaData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Noticia publicada')),
        );
      }

      _resetFormulario();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e')),
      );
    } finally {
      setState(() => _subiendo = false);
    }
  }

  void _resetFormulario() {
    _formKey.currentState?.reset();
    _tituloController.clear();
    _contenidoController.clear();
    setState(() {
      _imagenBytes = null;
      _imagenNombre = null;
      _urlImagenActual = null;
      _idNoticiaEditando = null;
    });
  }

  void _cargarNoticiaParaEditar(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    setState(() {
      _tituloController.text = data['titulo'] ?? '';
      _contenidoController.text = data['contenido'] ?? '';
      _urlImagenActual = data['imagenUrl'];
      _idNoticiaEditando = doc.id;
      _imagenBytes = null;
      _imagenNombre = null;
    });
  }

  Future<void> _eliminarNoticia(String id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar noticia'),
        content: const Text('¿Estás seguro de que deseas eliminar esta noticia?'),
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
        await FirebaseFirestore.instance.collection('noticias').doc(id).delete();
        if (_idNoticiaEditando == id) _resetFormulario();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Noticia eliminada')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
        );
      }
    }
  }

  Widget _buildFormulario() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 32),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Publicar nueva noticia',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _tituloController,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                value == null || value.trim().isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _contenidoController,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Contenido',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                value == null || value.trim().isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.image),
                label: const Text('Seleccionar imagen'),
                onPressed: _seleccionarImagen,
              ),
              if (_imagenBytes != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(_imagenBytes!, height: 200, fit: BoxFit.cover),
                  ),
                )
              else if (_urlImagenActual != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(_urlImagenActual!, height: 200, fit: BoxFit.cover),
                  ),
                ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(
                          _idNoticiaEditando == null ? Icons.save : Icons.update),
                      label: Text(
                          _idNoticiaEditando == null ? 'Guardar Noticia' : 'Actualizar'),
                      onPressed:
                      _subiendo ? null : _guardarOActualizarNoticia,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  if (_idNoticiaEditando != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: OutlinedButton(
                        onPressed: _resetFormulario,
                        child: const Text('Cancelar'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListaNoticias() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('noticias')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(top: 20),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final noticias = snapshot.data?.docs ?? [];

        if (noticias.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 20),
            child: Text('No hay noticias publicadas.'),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: noticias.length,
          itemBuilder: (context, index) {
            final doc = noticias[index];
            final data = doc.data() as Map<String, dynamic>;
            final fecha = (data['timestamp'] as Timestamp).toDate();
            final fechaStr = DateFormat('dd MMM yyyy, HH:mm', 'es_MX').format(fecha);

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (data['imagenUrl'] != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          data['imagenUrl'],
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    const SizedBox(height: 10),
                    Text(
                      data['titulo'] ?? '',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(data['contenido'] ?? ''),
                    const SizedBox(height: 8),
                    Text('🕒 $fechaStr • ✍️ ${data['autor'] ?? 'Administrador'}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blueAccent),
                            onPressed: () => _cargarNoticiaParaEditar(doc),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                            onPressed: () => _eliminarNoticia(doc.id),
                          ),
                        ],
                      ),
                    )
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
        title: const Text('Noticias'),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3E4EB8), Color(0xFF4F5D75)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildFormulario(),
                    Container(
                      alignment: Alignment.centerLeft,
                      child: const Text(
                        '📰 Noticias publicadas',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildListaNoticias(),
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
*/ */


import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class AgregarNoticiaScreen extends StatefulWidget {
  const AgregarNoticiaScreen({super.key});

  @override
  State<AgregarNoticiaScreen> createState() => _AgregarNoticiaScreenState();
}

class _AgregarNoticiaScreenState extends State<AgregarNoticiaScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _contenidoController = TextEditingController();

  File? _imagenFile;
  String? _urlImagenActual;
  String? _idNoticiaEditando;
  bool _subiendo = false;

  Future<void> _seleccionarImagen() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imagenFile = File(pickedFile.path);
      });
    }
  }

  Future<String?> _subirImagen() async {
    if (_imagenFile == null) return _urlImagenActual;

    final fileName = _imagenFile!.path.split('/').last;
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('noticias_imagenes')
        .child('${DateTime.now().millisecondsSinceEpoch}_$fileName');

    final uploadTask = await storageRef.putFile(_imagenFile!);
    return await uploadTask.ref.getDownloadURL();
  }

  Future<void> _guardarOActualizarNoticia() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _subiendo = true);

    try {
      String? urlImagen = await _subirImagen();

      final noticiaData = {
        'titulo': _tituloController.text.trim(),
        'contenido': _contenidoController.text.trim(),
        'timestamp': Timestamp.now(),
        'autor': 'Administrador',
        'imagenUrl': urlImagen,
      };

      if (_idNoticiaEditando != null) {
        await FirebaseFirestore.instance
            .collection('noticias')
            .doc(_idNoticiaEditando)
            .update(noticiaData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Noticia actualizada')),
        );
      } else {
        await FirebaseFirestore.instance.collection('noticias').add(noticiaData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Noticia publicada')),
        );
      }

      _resetFormulario();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e')),
      );
    } finally {
      setState(() => _subiendo = false);
    }
  }

  void _resetFormulario() {
    _formKey.currentState?.reset();
    _tituloController.clear();
    _contenidoController.clear();
    setState(() {
      _imagenFile = null;
      _urlImagenActual = null;
      _idNoticiaEditando = null;
    });
  }

  void _cargarNoticiaParaEditar(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    setState(() {
      _tituloController.text = data['titulo'] ?? '';
      _contenidoController.text = data['contenido'] ?? '';
      _urlImagenActual = data['imagenUrl'];
      _idNoticiaEditando = doc.id;
      _imagenFile = null;
    });
  }

  Future<void> _eliminarNoticia(String id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar noticia'),
        content: const Text('¿Estás seguro de que deseas eliminar esta noticia?'),
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
        await FirebaseFirestore.instance.collection('noticias').doc(id).delete();
        if (_idNoticiaEditando == id) _resetFormulario();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Noticia eliminada')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
        );
      }
    }
  }

  Widget _buildFormulario() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 32),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Publicar nueva noticia',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _tituloController,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                value == null || value.trim().isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _contenidoController,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Contenido',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                value == null || value.trim().isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.image),
                label: const Text('Seleccionar imagen'),
                onPressed: _seleccionarImagen,
              ),
              if (_imagenFile != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(_imagenFile!, height: 200, fit: BoxFit.cover),
                  ),
                )
              else if (_urlImagenActual != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(_urlImagenActual!, height: 200, fit: BoxFit.cover),
                  ),
                ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(
                          _idNoticiaEditando == null ? Icons.save : Icons.update),
                      label: Text(
                          _idNoticiaEditando == null ? 'Guardar Noticia' : 'Actualizar'),
                      onPressed: _subiendo ? null : _guardarOActualizarNoticia,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  if (_idNoticiaEditando != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: OutlinedButton(
                        onPressed: _resetFormulario,
                        child: const Text('Cancelar'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListaNoticias() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('noticias')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(top: 20),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final noticias = snapshot.data?.docs ?? [];

        if (noticias.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 20),
            child: Text('No hay noticias publicadas.'),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: noticias.length,
          itemBuilder: (context, index) {
            final doc = noticias[index];
            final data = doc.data() as Map<String, dynamic>;
            final fecha = (data['timestamp'] as Timestamp).toDate();
            final fechaStr = DateFormat('dd MMM yyyy, HH:mm', 'es_MX').format(fecha);

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (data['imagenUrl'] != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          data['imagenUrl'],
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    const SizedBox(height: 10),
                    Text(
                      data['titulo'] ?? '',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(data['contenido'] ?? ''),
                    const SizedBox(height: 8),
                    Text('🕒 $fechaStr • ✍️ ${data['autor'] ?? 'Administrador'}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blueAccent),
                            onPressed: () => _cargarNoticiaParaEditar(doc),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                            onPressed: () => _eliminarNoticia(doc.id),
                          ),
                        ],
                      ),
                    )
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
        title: const Text('Noticias'),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3E4EB8), Color(0xFF4F5D75)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildFormulario(),
                    Container(
                      alignment: Alignment.centerLeft,
                      child: const Text(
                        '📰 Noticias publicadas',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildListaNoticias(),
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
