import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class GaleriaEventoScreen extends StatelessWidget {
  final DateTime fechaEvento;
  final String eventoId;

  const GaleriaEventoScreen({
    super.key,
    required this.fechaEvento,
    required this.eventoId,
  });

  @override
  Widget build(BuildContext context) {
    final fechaStr = DateFormat('dd MMM yyyy', 'es_MX').format(fechaEvento);

    return Scaffold(
      appBar: AppBar(
        title: Text('Galería del $fechaStr'),
        backgroundColor: Colors.indigo,
      ),
      body: Center(
        child: Text('Aquí se mostrarán las fotos del evento "$eventoId"'),
        // Aquí puedes cargar desde Firebase Storage o Firestore las fotos del evento
      ),
    );
  }
}
