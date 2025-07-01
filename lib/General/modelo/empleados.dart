class Usuario {

  final int CP;
  final String id;
  final String titulo;
  final int antiguedad;
  final String apellidos;
  final String beneficiario;
  final String calle;
  final String coloniaComunidad;
  final String comunidad;
  final String contratoInd;
  final String curp;
  final String departamento;
  final String domicilio;
  final int edad;
  final String edoCivil;
  final String email;
  final String escolaridad;
  final String emailEmpresa;
  final String fechaIng;
  final String fechaNac;
  final String genero;
  final String foto;
  final int jefe;
  final String municipio;
  final int no;
  final String nombre;
  final String ns;
  final String parentesco;
  final String parentesco2;
  final int porcentaje;
  final String privilegio;
  final String puesto;
  final int reporta;
  final String rfc;
  final int salario;
  final int telefono1;
  final int telefono2;
  final String tipo;
  final String vacaciones;

  Usuario({
    required this.CP,
    required this.id,
    required this.titulo,
    required this.antiguedad,
    required this.apellidos,
    required this.beneficiario,
    required this.calle,
    required this.coloniaComunidad,
    required this.comunidad,
    required this.contratoInd,
    required this.curp,
    required this.departamento,
    required this.domicilio,
    required this.edad,
    required this.edoCivil,
    required this.email,
    required this.escolaridad,
    required this.emailEmpresa,
    required this.fechaIng,
    required this.fechaNac,
    required this.genero,
    required this.foto,
    required this.jefe,
    required this.municipio,
    required this.no,
    required this.nombre,
    required this.ns,
    required this.parentesco,
    required this.parentesco2,
    required this.porcentaje,
    required this.privilegio,
    required this.puesto,
    required this.reporta,
    required this.rfc,
    required this.salario,
    required this.telefono1,
    required this.telefono2,
    required this.tipo,
    required this.vacaciones,
  });



  factory Usuario.fromMap(String id, Map<String, dynamic> data) {
    return Usuario(
      CP: data['CP'] is int ? data['CP'] : int.tryParse('${data['CP']}') ?? 0,
      id: id,
      titulo: '${data['Título'] ?? ''}',
      antiguedad: data['antiguedad'] is int ? data['antiguedad'] : int.tryParse('${data['antiguedad']}') ?? 0,
      apellidos: '${data['apellidos'] ?? ''}',
      beneficiario: '${data['beneficiario'] ?? ''}',
      calle: '${data['calle'] ?? ''}',
      coloniaComunidad: '${data['coloniaComunidad'] ?? ''}',
      comunidad: '${data['comunidad'] ?? ''}',
      contratoInd: '${data['contratoInd'] ?? ''}',
      curp: '${data['curp'] ?? ''}',
      departamento: '${data['departamento'] ?? ''}',
      domicilio: '${data['domicilio'] ?? ''}',
      edad: data['edad'] is int ? data['edad'] : int.tryParse('${data['edad']}') ?? 0,
      edoCivil: '${data['edoCivil'] ?? ''}',
      email: '${data['email'] ?? ''}',
      escolaridad: '${data['escolaridad'] ?? ''}',
      emailEmpresa: '${data['emailEmpresa'] ?? ''}',
      fechaIng: '${data['fechaIng'] ?? ''}',
      fechaNac: '${data['fechaNac'] ?? ''}',
      genero: '${data['genero'] ?? ''}',
      foto: '${data['foto'] ?? ''}',
      jefe: data['jefe'] is int ? data['jefe'] : int.tryParse('${data['jefe']}') ?? 0,
      municipio: '${data['municipio'] ?? ''}',
      no: data['no'] is int ? data['no'] : int.tryParse('${data['no']}') ?? 0,
      nombre: '${data['nombre'] ?? ''}',
      ns: '${data['ns'] ?? ''}',
      parentesco: '${data['parentesco'] ?? ''}',
      parentesco2: '${data['parentesco2'] ?? ''}',
      porcentaje: data['porcentaje'] is int ? data['porcentaje'] : int.tryParse('${data['porcentaje']}') ?? 0,
      privilegio: '${data['privilegio'] ?? ''}',
      puesto: '${data['puesto'] ?? ''}',
      reporta: data['reporta'] is int ? data['reporta'] : int.tryParse('${data['reporta']}') ?? 0,
      rfc: '${data['rfc'] ?? ''}',
      salario: data['salario'] is int ? data['salario'] : int.tryParse('${data['salario']}') ?? 0,
      telefono1: data['telefono1'] is int ? data['telefono1'] : int.tryParse('${data['telefono1']}') ?? 0,
      telefono2: data['telefono2'] is int ? data['telefono2'] : int.tryParse('${data['telefono2']}') ?? 0,
      tipo: '${data['tipo'] ?? ''}',
      vacaciones: '${data['vacaciones'] ?? ''}',
    );
  }

  Map<String, dynamic> toMap() => {
    'CP': CP,
    'Título': titulo,
    'antiguedad': antiguedad,
    'apellidos': apellidos,
    'beneficiario': beneficiario,
    'calle': calle,
    'coloniaComunidad': coloniaComunidad,
    'comunidad': comunidad,
    'contratoInd': contratoInd,
    'curp': curp,
    'departamento': departamento,
    'domicilio': domicilio,
    'edad': edad,
    'edoCivil': edoCivil,
    'email': email,
    'escolaridad': escolaridad,
    'emailEmpresa': emailEmpresa,
    'fechaIng': fechaIng,
    'fechaNac': fechaNac,
    'genero': genero,
    'foto': foto,
    'jefe': jefe,
    'municipio': municipio,
    'no': no,
    'nombre': nombre,
    'ns': ns,
    'parentesco': parentesco,
    'parentesco2': parentesco2,
    'porcentaje': porcentaje,
    'privilegio': privilegio,
    'puesto': puesto,
    'reporta': reporta,
    'rfc': rfc,
    'salario': salario,
    'telefono1': telefono1,
    'telefono2': telefono2,
    'tipo': tipo,
    'vacaciones': vacaciones,
  };
}
