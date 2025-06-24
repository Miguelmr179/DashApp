import 'dart:convert';
import 'dart:io';

import 'package:dashapp/Huellas/Modelo/usuarios.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UsuariosLocalesScreen extends StatefulWidget {
  const UsuariosLocalesScreen({super.key});

  @override
  State<UsuariosLocalesScreen> createState() => _UsuariosLocalesScreenState();
}

class _UsuariosLocalesScreenState extends State<UsuariosLocalesScreen> {
  List<Usuario> _usuarios = [];

  @override
  void initState() {
    super.initState();
    _cargarUsuarios();
  }

  Future<void> _cargarUsuarios() async {
    final prefs = await SharedPreferences.getInstance();
    final listaRaw = prefs.getStringList('usuarios_locales') ?? [];
    final total = listaRaw.length;

    final usuarios = listaRaw
        .map((e) => jsonDecode(e))
        .whereType<Map<String, dynamic>>()
        .map((mapa) => Usuario.fromMap(mapa))
        .toList();

    setState(() => _usuarios = usuarios);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios Guardados Localmente'),
        backgroundColor: Colors.blueGrey,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar lista',
            onPressed: _cargarUsuarios,
          ),
        ],
      ),
      body: _usuarios.isEmpty
          ? const Center(child: Text('No hay usuarios guardados.'))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _usuarios.length,
        itemBuilder: (context, index) {
          final usuario = _usuarios[index];
          return Card(
            elevation: 4,
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: usuario.fotoLocal != null && File(usuario.fotoLocal!).existsSync()
                  ? CircleAvatar(backgroundImage: FileImage(File(usuario.fotoLocal!)))
                  : const CircleAvatar(child: Icon(Icons.person)),
              title: Text(usuario.nombre),
              subtitle: Text('ID: ${usuario.titulo}'),
            ),
          );
        },
      ),
      //Mostrar el total de ususarios
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'Total de usuarios guardados: ${_usuarios.length}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
