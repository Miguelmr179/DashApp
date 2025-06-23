import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> guardarRegistroEnCambios(Map<String, dynamic> datos) async {
  final String regNo = datos['Reg_no'] ?? '';
  final String fecha = datos['fecha'] ?? '';
  final String tipo = datos['tipo'] ?? '';
  final String hora = datos['hora'] ?? '';
  final Timestamp timestamp = datos['timestamp'] ?? Timestamp.now();

  if (regNo.isEmpty || fecha.isEmpty || tipo.isEmpty || hora.isEmpty) {
    throw Exception('Faltan datos esenciales para guardar el registro.');
  }

  final query = await FirebaseFirestore.instance
      .collection('Cambios')
      .where('Reg_no', isEqualTo: regNo)
      .where('fecha', isEqualTo: fecha)
      .where('tipo', isEqualTo: tipo)
      .limit(1)
      .get();

  final Map<String, dynamic> datosFinales = {
    'Reg_no': regNo,
    'Title': datos['Title'] ?? '',
    'fecha': fecha,
    'hora': hora,
    'tipo': tipo,
    'timestamp': timestamp,
    'Reg_Fecha': timestamp.toDate(),
    'Reg_FechaHoraRegistro': Timestamp.now(),
    'observaciones': datos['observaciones'] ?? '',
  };

  if (query.docs.isNotEmpty) {
    await query.docs.first.reference.update(datosFinales);
  } else {
    await FirebaseFirestore.instance.collection('Cambios').add(datosFinales);
  }
}
