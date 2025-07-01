import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dashapp/Huellas/Modelo/usuarios.dart';
import 'package:dashapp/Utileria/global_exports.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UsuariosLocalesService {
  static final UsuariosLocalesService _instance = UsuariosLocalesService._internal();
  factory UsuariosLocalesService() => _instance;

  StreamSubscription<QuerySnapshot>? _firestoreSub;
  final ValueNotifier<bool> notificador = ValueNotifier(false);
  List<UsuarioLocal> _usuarios = [];

  UsuariosLocalesService._internal();

  void iniciar() {
    _firestoreSub ??= FirebaseFirestore.instance
        .collection('UsuariosDcc')
        .snapshots()
        .listen((snapshot) async {
      await _actualizarUsuariosLocales(snapshot);
      notificador.value = !notificador.value;
    });
  }

  Future<void> _actualizarUsuariosLocales(QuerySnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    final listaJson = <String>[];

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final usuario = UsuarioLocal.fromMap(data);
      listaJson.add(jsonEncode(usuario.toMap()));
    }

    await prefs.setStringList('usuarios_locales', listaJson);
  }

  void detener() {
    _firestoreSub?.cancel();
    _firestoreSub = null;
  }
}
