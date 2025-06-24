/*
Version WEB

import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdministrarFotosUsuariosScreen extends StatefulWidget {
  const AdministrarFotosUsuariosScreen({super.key});

  @override
  State<AdministrarFotosUsuariosScreen> createState() => _AdministrarFotosUsuariosScreenState();
}

class _AdministrarFotosUsuariosScreenState extends State<AdministrarFotosUsuariosScreen> {
  final Map<String, Uint8List> _fotosTemporal = {};
  final Map<String, String> _nombresFotos = {};
  final Map<String, bool> _subiendo = {};

  Future<void> _seleccionarFoto(String uid) async {
    final input = html.FileUploadInputElement()..accept = 'image/*';
    input.click();

    input.onChange.listen((event) {
      final file = input.files!.first;
      final reader = html.FileReader();

      reader.readAsArrayBuffer(file);
      reader.onLoadEnd.listen((_) {
        setState(() {
          _fotosTemporal[uid] = reader.result as Uint8List;
          _nombresFotos[uid] = file.name;
        });
      });
    });
  }

  Future<void> _subirFotoParaUsuario(String uid) async {
    final foto = _fotosTemporal[uid];
    final nombre = _nombresFotos[uid];
    if (foto == null || nombre == null) return;

    setState(() {
      _subiendo[uid] = true;
    });

    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('usuarios_fotos')
          .child('$uid-${DateTime.now().millisecondsSinceEpoch}_$nombre');

      final uploadTask = await storageRef.putData(foto);
      final url = await uploadTask.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('Usuarios').doc(uid).update({
        'foto': url,
      });

      setState(() {
        _fotosTemporal.remove(uid);
        _nombresFotos.remove(uid);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Foto actualizada para $uid')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error al subir foto de $uid: $e')),
      );
    } finally {
      setState(() {
        _subiendo[uid] = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Administrar Fotos de Usuarios')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('Usuarios').orderBy('nombre').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final usuarios = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: usuarios.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final usuario = usuarios[index];
              final uid = usuario.id;
              final data = usuario.data() as Map<String, dynamic>;
              final nombre = data['nombre'] ?? 'Sin nombre';
              final nominal = data['no'] ?? 'Sin nómina';
              final fotoUrl = data['foto'] as String?;

              final fotoTemporal = _fotosTemporal[uid];
              final subiendo = _subiendo[uid] ?? false;

              return Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      if (fotoTemporal != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(fotoTemporal, width: 80, height: 80, fit: BoxFit.cover),
                        )
                      else if (fotoUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(fotoUrl, width: 80, height: 80, fit: BoxFit.cover),
                        )
                      else
                        const Icon(Icons.account_circle, size: 80, color: Colors.grey),

                      const SizedBox(width: 16),

                      // Nombre y botones
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(nombre, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('Nómina: $nominal', style: const TextStyle(fontSize: 16, color: Colors.grey)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.photo),
                                  label: const Text('Seleccionar'),
                                  onPressed: () => _seleccionarFoto(uid),
                                ),
                                const SizedBox(width: 8),
                                if (fotoTemporal != null)
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.upload),
                                    label: Text(subiendo ? 'Subiendo...' : 'Subir'),
                                    onPressed: subiendo ? null : () => _subirFotoParaUsuario(uid),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                                  ),
                              ],
                            )
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
      ),
    );
  }
}


*/*/


import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class AdministrarFotosUsuariosScreen extends StatefulWidget {
  const AdministrarFotosUsuariosScreen({super.key});

  @override
  State<AdministrarFotosUsuariosScreen> createState() => _AdministrarFotosUsuariosScreenState();
}

class _AdministrarFotosUsuariosScreenState extends State<AdministrarFotosUsuariosScreen> {
  final Map<String, File> _fotosTemporal = {};
  final Map<String, String> _nombresFotos = {};
  final Map<String, bool> _subiendo = {};

  Future<void> _seleccionarFoto(String uid) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _fotosTemporal[uid] = File(pickedFile.path);
        _nombresFotos[uid] = pickedFile.name;
      });
    }
  }

  Future<void> _subirFotoParaUsuario(String uid) async {
    final foto = _fotosTemporal[uid];
    final nombre = _nombresFotos[uid];
    if (foto == null || nombre == null) return;

    setState(() {
      _subiendo[uid] = true;
    });

    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('usuarios_fotos')
          .child('$uid-${DateTime.now().millisecondsSinceEpoch}_$nombre');

      final uploadTask = await storageRef.putFile(foto);
      final url = await uploadTask.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('Usuarios').doc(uid).update({
        'foto': url,
      });

      setState(() {
        _fotosTemporal.remove(uid);
        _nombresFotos.remove(uid);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Foto actualizada para $uid')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error al subir foto de $uid: $e')),
      );
    } finally {
      setState(() {
        _subiendo[uid] = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Administrar Fotos de Usuarios')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('Usuarios').orderBy('nombre').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final usuarios = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: usuarios.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final usuario = usuarios[index];
              final uid = usuario.id;
              final data = usuario.data() as Map<String, dynamic>;
              final nombre = data['nombre'] ?? 'Sin nombre';
              final nominal = data['no'] ?? 'Sin nómina';
              final fotoUrl = data['foto'] as String?;

              final fotoTemporal = _fotosTemporal[uid];
              final subiendo = _subiendo[uid] ?? false;

              return Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      if (fotoTemporal != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(fotoTemporal, width: 80, height: 80, fit: BoxFit.cover),
                        )
                      else if (fotoUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(fotoUrl, width: 80, height: 80, fit: BoxFit.cover),
                        )
                      else
                        const Icon(Icons.account_circle, size: 80, color: Colors.grey),

                      const SizedBox(width: 16),

                      // Nombre y botones
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(nombre, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('Nómina: $nominal', style: const TextStyle(fontSize: 16, color: Colors.grey)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.photo),
                                  label: const Text('Seleccionar'),
                                  onPressed: () => _seleccionarFoto(uid),
                                ),
                                const SizedBox(width: 8),
                                if (fotoTemporal != null)
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.upload),
                                    label: Text(subiendo ? 'Subiendo...' : 'Subir'),
                                    onPressed: subiendo ? null : () => _subirFotoParaUsuario(uid),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                                  ),
                              ],
                            )
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
      ),
    );
  }
}
