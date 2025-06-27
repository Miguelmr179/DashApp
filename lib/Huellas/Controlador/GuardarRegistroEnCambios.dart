import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> guardarRegistroEnCambios(Map<String, dynamic> datos) async {
  final String regNo = datos['Reg_no'] ?? '';
  final String fecha = datos['fecha'] ?? '';
  final String tipo = datos['tipo'] ?? '';
  final String hora = datos['hora'] ?? '';
  final Timestamp registro = datos['Reg_FechaHoraRegistro'] ?? Timestamp.now();


  if (regNo.isEmpty || fecha.isEmpty || tipo.isEmpty || hora.isEmpty) {
    throw Exception('Faltan datos esenciales para guardar el registro.');
  }

  final query = await FirebaseFirestore.instance
      .collection('checadas')
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
    'Reg_FechaHoraRegistro': registro,
    'observaciones': datos['observaciones'] ?? '',
  };

  if (query.docs.isNotEmpty) {
    await query.docs.first.reference.update(datosFinales);
  } else {
    await FirebaseFirestore.instance.collection('checadas').add(datosFinales);
  }
}
