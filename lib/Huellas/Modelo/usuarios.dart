class Usuario {
  final String titulo;
  final String nombre;
  final String? foto;
  String? fotoLocal;

  Usuario({
    required this.titulo,
    required this.nombre,
    this.foto,
    this.fotoLocal,
  });

  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      titulo: map['Título'] ?? '',
      nombre: map['nombre'] ?? '',
      foto: map['foto'],
      fotoLocal: map['foto_local'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'titulo': titulo,
      'nombre': nombre,
      'foto': foto,
      'foto_local': fotoLocal,
    };
  }
}


class RegistroOffline {
  final String titulo;
  final String nombre;
  final DateTime fechaHora;

  RegistroOffline({
    required this.titulo,
    required this.nombre,
    required this.fechaHora,
  });

  Map<String, dynamic> toJson() => {
    'Title': nombre,
    'Reg_no': titulo,
    'Reg_FechaHoraRegistro': fechaHora.toIso8601String(),
  };

  factory RegistroOffline.fromJson(Map<String, dynamic> json) {
    return RegistroOffline(
      titulo: json['Reg_no'],
      nombre: json['Title'],
      fechaHora: DateTime.parse(json['Reg_FechaHoraRegistro']),
    );
  }
}
