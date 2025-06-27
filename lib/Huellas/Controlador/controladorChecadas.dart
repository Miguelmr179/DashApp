import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CheckinService {

  Timer? _timer;
  String _ultimaHoraEjecutada = '';

  Future<void> procesarChecadaLocal(
      String tarjeta,
      BuildContext context, {
        required String tipoRegistro,
        String? tipoPersonalizado,
      }) async {
    final prefs = await SharedPreferences.getInstance();
    final usuariosRaw = prefs.getStringList('usuarios_locales') ?? [];
    final registrosRaw = prefs.getStringList('checadas_locales_$tipoRegistro') ?? [];

    final usuarios = usuariosRaw
        .map((e) => jsonDecode(e))
        .where((u) => u['titulo'] == tarjeta)
        .toList();

    if (usuarios.isEmpty) {
      _showPopup(context, 'Tarjeta no registrada.');
      return;
    }

    final usuario = usuarios.first;
    final ahora = DateTime.now();

    final registros = registrosRaw
        .map((e) => jsonDecode(e))
        .map((r) => {
      'titulo': r['Reg_no'],
      'nombre': r['Title'],
      'hora': DateTime.parse(r['Reg_FechaHoraRegistro']),
    })
        .toList();

    final ultimos = registros
        .where((r) => r['titulo'] == tarjeta)
        .map((r) => r['hora'] as DateTime)
        .toList();

    if ((tipoPersonalizado?.contains('entrada_planta') ?? false) && ultimos.isNotEmpty) {
      final ultimaHora = ultimos.reduce((a, b) => a.isAfter(b) ? a : b);
      if (ahora.difference(ultimaHora).inMinutes < 10) {
        _showPopup(context, '👌 Registro realizado ^_^.');
        return;
      }
    }
    if ((tipoPersonalizado?.contains('entrada_comedor') ?? false) && ultimos.isNotEmpty) {
      final ultimaHora = ultimos.reduce((a, b) => a.isAfter(b) ? a : b);
      if (ahora.difference(ultimaHora).inMinutes < 10) {
        _showPopup(context, '👌 Registro realizado ^_^.');
        return;
      }
    }
    if ((tipoPersonalizado?.contains('salida_comedor') ?? false) && ultimos.isNotEmpty) {
      final ultimaHora = ultimos.reduce((a, b) => a.isAfter(b) ? a : b);
      if (ahora.difference(ultimaHora).inMinutes < 10) {
        _showPopup(context, '👌 Registro realizado ^_^.');
        return;
      }
    }
    if ((tipoPersonalizado?.contains('salida_planta') ?? false) && ultimos.isNotEmpty) {
      final ultimaHora = ultimos.reduce((a, b) => a.isAfter(b) ? a : b);
      if (ahora.difference(ultimaHora).inMinutes < 10) {
        _showPopup(context, '👌 Registro realizado ^_^.');
        return;
      }
    }

    // Ajuste especial para salida_planta entre 5:00 y 6:59 a.m.
    final fechaAjustada = (tipoPersonalizado == 'salida_planta' &&
        ahora.hour >= 5 &&
        ahora.hour < 7)
        ? ahora.subtract(const Duration(days: 1))
        : ahora;

    final nuevoRegistro = {
      'Title': usuario['nombre'],
      'Reg_no': tarjeta,
      'tipo': tipoPersonalizado ?? 'desconocido',
      'Reg_FechaHoraRegistro': ahora.toIso8601String(),
      'fecha': DateFormat('yyyy-MM-dd').format(fechaAjustada),
      'hora': DateFormat('HH:mm:ss').format(ahora),
      'timestamp': ahora.toIso8601String(),
    };

    registrosRaw.add(jsonEncode(nuevoRegistro));
    await prefs.setStringList('checadas_locales_$tipoRegistro', registrosRaw);

    final horaFormateada = DateFormat('HH:mm:ss').format(ahora);
    _showPopupBonito(
      context,
      nombre: usuario['nombre'],
      tarjeta: tarjeta,
      hora: horaFormateada,
    );
  }

  void _showPopupBonito(BuildContext context,
      {required String nombre, required String tarjeta, required String hora}) async {
    final prefs = await SharedPreferences.getInstance();
    final usuariosRaw = prefs.getStringList('usuarios_locales') ?? [];

    // Buscar al usuario por tarjeta
    final usuario = usuariosRaw
        .map((e) => jsonDecode(e))
        .firstWhere((u) => u['titulo'] == tarjeta, orElse: () => null);

    final fotoLocal = usuario != null ? usuario['foto_local'] as String? : null;
    final hayImagen = fotoLocal != null && File(fotoLocal).existsSync();

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Registro exitoso',
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (_, animation, __, ___) {
        return Transform.scale(
          scale: Curves.easeOutBack.transform(animation.value),
          child: Opacity(
            opacity: animation.value,
            child: Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 15,
              backgroundColor: Colors.white,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 25),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hayImagen)
                      CircleAvatar(
                        radius: 45,
                        backgroundImage: FileImage(File(fotoLocal)),
                      )
                    else
                      const CircleAvatar(
                        radius: 45,
                        child: Icon(Icons.person, size: 50),
                      ),
                    const SizedBox(height: 20),
                    const Text(
                      '¡Registro Exitoso!',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 25),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.black87,
                          height: 1.6,
                        ),
                        children: [
                          const TextSpan(
                              text: '👤 Nombre: ',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          TextSpan(text: '$nombre\n'),
                          const TextSpan(
                              text: '🪪 Tarjeta: ',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          TextSpan(text: '$tarjeta\n'),
                          const TextSpan(
                              text: '⏰ Hora: ',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          TextSpan(text: '$hora'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    Future.delayed(const Duration(milliseconds: 1750), () {
      Navigator.of(context, rootNavigator: true).pop();
    });
  }

  void _showPopup(BuildContext context, String msg) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Mensaje',
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (_, animation, __, ___) {
        return Transform.scale(
          scale: Curves.easeOutBack.transform(animation.value),
          child: Opacity(
            opacity: animation.value,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 20,
              backgroundColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 30, horizontal: 25),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.blueAccent, size: 50),
                  const SizedBox(height: 20),
                  Text(
                    msg,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    Future.delayed(const Duration(milliseconds: 1850), () {
      Navigator.of(context, rootNavigator: true).pop();
    });
  }

  Future<void> subirChecadasPendientes({required String tipoRegistro}) async {
    final prefs = await SharedPreferences.getInstance();
    final registrosRaw = prefs.getStringList('checadas_locales_$tipoRegistro') ?? [];

    for (final raw in registrosRaw) {
      final data = jsonDecode(raw);
      await FirebaseFirestore.instance.collection('checadas').add({
        ...data,
        'Reg_FechaHoraRegistro': Timestamp.fromDate(DateTime.parse(data['Reg_FechaHoraRegistro'])),
        'Reg_Fecha': DateTime.parse(data['Reg_FechaHoraRegistro']).toLocal(),
      });
    }

    await prefs.remove('checadas_locales_$tipoRegistro');
  }

  void iniciarSubidaAutomatica() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) async {
      final now = TimeOfDay.now();
      final horaActual = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      if (_ultimaHoraEjecutada == horaActual) return;
      _ultimaHoraEjecutada = horaActual;

      final prefs = await SharedPreferences.getInstance();
      final horasChecadas = prefs.getStringList('horasSubidaChecadas') ?? [];
      final horasComedor = prefs.getStringList('horasSubidaComedor') ?? [];

      if (horasChecadas.contains(horaActual)) {
        await subirChecadasPendientes(tipoRegistro: 'checkins_offline');
        debugPrint('Subida automática ejecutada para checadas a las $horaActual');
      }

      if (horasComedor.contains(horaActual)) {
        await subirChecadasPendientes(tipoRegistro: 'comidas_offline');
        debugPrint('Subida automática ejecutada para comedor a las $horaActual');
      }
    });
  }

  void detenerSubidaAutomatica() {
    _timer?.cancel();
    _timer = null;
  }
}
