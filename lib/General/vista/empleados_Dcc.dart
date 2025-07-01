import 'package:dashapp/Capacitaciones/screens/admin/admin_manage_users_screen.dart';
import 'package:dashapp/General/modelo/empleados.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class empleadosScreen extends StatefulWidget {
  const empleadosScreen({Key? key}) : super(key: key);

  @override
  State<empleadosScreen> createState() => _empleadosScreenState();
}

class _empleadosScreenState extends State<empleadosScreen> {
  final CollectionReference usuariosRef = FirebaseFirestore.instance.collection('UsuariosDcc');
  final TextEditingController _filtroNoController = TextEditingController();

  Future<void> _crearUsuario(Usuario usuario) async {
    await usuariosRef.doc(usuario.id).set(usuario.toMap());
  }

  Future<void> _actualizarUsuario(Usuario usuario) async {
    await usuariosRef.doc(usuario.id).update(usuario.toMap());
  }

  Future<void> _eliminarUsuario(String id) async {
    await usuariosRef.doc(id).delete();
  }

  void _mostrarFormulario(BuildContext context, {Usuario? usuario}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final campos = [
      'CP', 'titulo', 'antiguedad', 'apellidos', 'beneficiario', 'calle', 'coloniaComunidad',
      'comunidad', 'contratoInd', 'curp', 'departamento', 'domicilio', 'edad', 'edoCivil',
      'email', 'escolaridad', 'emailEmpresa', 'fechaIng', 'fechaNac', 'genero', 'foto',
      'jefe', 'municipio', 'no', 'nombre', 'ns', 'parentesco', 'parentesco2', 'porcentaje',
      'privilegio', 'puesto', 'reporta', 'rfc', 'salario', 'telefono1', 'telefono2', 'tipo', 'vacaciones',
    ];


    final Map<String, TextEditingController> controllers = {
      for (var campo in campos)
        campo: TextEditingController(
            text: usuario != null
                ? (usuario.toMap()[campo] is int
                ? usuario.toMap()[campo].toString()
                : (usuario.toMap()[campo] ?? '')
            ) : ''
        )

    };


    void _crearUsuarioDesdeControles() {
      final nuevo = Usuario(
        CP: int.tryParse(controllers['CP']!.text) ?? 0,
        id: usuario?.id ?? controllers['no']!.text,
        titulo: controllers['titulo']!.text,
        antiguedad: int.tryParse(controllers['antiguedad']!.text) ?? 0,
        apellidos: controllers['apellidos']!.text,
        beneficiario: controllers['beneficiario']!.text,
        calle: controllers['calle']!.text,
        coloniaComunidad: controllers['coloniaComunidad']!.text,
        comunidad: controllers['comunidad']!.text,
        contratoInd: controllers['contratoInd']!.text,
        curp: controllers['curp']!.text,
        departamento: controllers['departamento']!.text,
        domicilio: controllers['domicilio']!.text,
        edad: int.tryParse(controllers['edad']!.text) ?? 0,
        edoCivil: controllers['edoCivil']!.text,
        email: controllers['email']!.text,
        escolaridad: controllers['escolaridad']!.text,
        emailEmpresa: controllers['emailEmpresa']!.text,
        fechaIng: controllers['fechaIng']!.text,
        fechaNac: controllers['fechaNac']!.text,
        genero: controllers['genero']!.text,
        foto: controllers['foto']!.text,
        jefe: int.tryParse(controllers['jefe']!.text) ?? 0,
        municipio: controllers['municipio']!.text,
        no: int.tryParse(controllers['no']!.text) ?? 0,
        nombre: controllers['nombre']!.text,
        ns: controllers['ns']!.text,
        parentesco: controllers['parentesco']!.text,
        parentesco2: controllers['parentesco2']!.text,
        porcentaje: int.tryParse(controllers['porcentaje']?.text ?? '') ?? 0,
        privilegio: controllers['privilegio']!.text,
        puesto: controllers['puesto']!.text,
        reporta: int.tryParse(controllers['reporta']!.text) ?? 0,
        rfc: controllers['rfc']!.text,
        salario: int.tryParse(controllers['salario']!.text) ?? 0,
        telefono1: int.tryParse(controllers['telefono1']!.text) ?? 0,
        telefono2: int.tryParse(controllers['telefono2']!.text) ?? 0,
        tipo: controllers['tipo']!.text,
        vacaciones: controllers['vacaciones']!.text,
      );

      if (usuario == null) {
        _crearUsuario(nuevo);
      } else {
        _actualizarUsuario(nuevo);
      }
      Navigator.pop(context);
    }


    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          usuario == null ? 'Nuevo Usuario' : 'Editar Usuario',
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
        ),
        content: SingleChildScrollView(
          child: Column(
            children: campos.map((campo) => TextField(
              controller: controllers[campo],
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
              decoration: InputDecoration(
                labelText: campo,
                labelStyle: TextStyle(color: isDarkMode ? Colors.white70 : Colors.grey[800]),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: isDarkMode ? Colors.white24 : Colors.grey),
                ),
              ),
            )).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: _crearUsuarioDesdeControles,
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? const Color(0xFF2A2A2A) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return Container(
      decoration: BoxDecoration(
        gradient: isDarkMode
            ? const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F2027), Color(0xFF2C5364)],
        )
            : const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE0E0E0), Color(0xFFFFFFFF)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('Usuarios Registrados'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.manage_accounts),
              tooltip: 'Usuarios registrados',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminManageUsersScreen()),
                );
              },
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              const SizedBox(height: 50),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: _filtroNoController,
                  decoration: InputDecoration(
                    labelText: 'Buscar por número de nómina',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _filtroNoController.clear();
                        setState(() {});
                      },
                    ),
                  ),
                  onChanged: (value) => setState(() {}),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: usuariosRef.snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                    final usuarios = snapshot.data!.docs
                        .map((doc) => Usuario.fromMap(doc.id, doc.data() as Map<String, dynamic>))
                        .where((u) =>
                    _filtroNoController.text.isEmpty ||
                        u.no.toString().contains(_filtroNoController.text))

                        .toList();

                    return ListView.separated(
                      itemCount: usuarios.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final u = usuarios[index];
                        return Card(
                          color: cardColor,
                          elevation: 6,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor: Colors.transparent,
                                  backgroundImage: NetworkImage(u.foto),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(u.nombre,
                                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                                      Text(u.puesto, style: TextStyle(color: textColor.withOpacity(0.7))),
                                      const SizedBox(height: 4),
                                      Text('Correo: ${u.emailEmpresa}',
                                          style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12)),
                                      Text('No. Empleado: ${u.no}',
                                          style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    Chip(
                                      label: Text(u.privilegio == '1' ? 'Admin' : 'Usuario'),
                                      backgroundColor: u.privilegio == '1'
                                          ? Colors.indigo.shade300
                                          : Colors.grey.shade400,
                                      labelStyle: const TextStyle(color: Colors.white),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.edit, color: isDarkMode ? Colors.amber : Colors.indigo),
                                          onPressed: () => _mostrarFormulario(context, usuario: u),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                                          onPressed: () => _eliminarUsuario(u.id),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _mostrarFormulario(context),
          backgroundColor: Colors.indigo,
          icon: const Icon(Icons.person_add),
          label: const Text('Nuevo Usuario'),
        ),
      ),
    );
  }

}
