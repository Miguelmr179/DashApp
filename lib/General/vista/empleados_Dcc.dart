import 'package:dashapp/Capacitaciones/screens/admin/admin_manage_users_screen.dart';
import 'package:dashapp/General/modelo/empleados.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';


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
      'CP', 'antiguedad', 'apellidos', 'beneficiario', 'calle', 'colonia/Comunidad',
      'comunidad', 'contrato ind', 'curp', 'departamento', 'domicilio', 'edad', 'edo Civil',
      'email', 'escolaridad', 'emailEmpresa', 'fechaIng', 'fechaNac', 'genero',
      'jefe', 'municipio', 'no', 'nombre', 'ns', 'parentesco', 'parentesco2', 'porcentaje',
      'privilegio', 'puesto', 'reporta', 'rfc', 'salario', 'telefono 1', 'telefono 2', 'tipo', 'vacaciones',
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

    List<TableRow> _buildFilas(BuildContext context, List<String> campos) {
      List<TableRow> filas = [];
      for (int i = 0; i < campos.length; i += 3) {
        final filaCampos = campos.sublist(i, (i + 3) > campos.length ? campos.length : i + 3);

        filas.add(
          TableRow(
            children: List.generate(3, (index) {
              if (index < filaCampos.length) {
                final campo = filaCampos[index];
                final isFechaIng = campo == 'fechaIng';
                final isFechaNac = campo == 'fechaNac';

                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: GestureDetector(
                    onTap: (isFechaIng || isFechaNac)
                        ? () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(1900),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        final formatted = isFechaIng
                            ? DateFormat('dd/MM/yyyy').format(picked)
                            : DateFormat('yyyy-MM-dd').format(picked);
                        controllers[campo]!.text = formatted;
                      }
                    }
                        : null,
                    child: AbsorbPointer(
                      absorbing: isFechaIng || isFechaNac,
                      child: TextField(
                        controller: controllers[campo],
                        decoration: InputDecoration(
                          labelText: campo,
                          filled: true,
                          fillColor: isDarkMode ? Colors.grey[850] : Colors.grey[100],
                          labelStyle: TextStyle(
                            color: isDarkMode ? Colors.white70 : Colors.grey[700],
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.indigo.shade300, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                      ),
                    ),
                  ),
                );
              } else {
                return const SizedBox(); // Celda vacía si no hay campo
              }
            }),
          ),
        );
      }
      return filas;
    }

    void _crearUsuarioDesdeControles() {
      final nuevo = Usuario(
        CP: int.tryParse(controllers['CP']!.text) ?? 0,
        id: usuario?.id ?? controllers['no']!.text,
        titulo: '1',
        antiguedad: int.tryParse(controllers['antiguedad']!.text) ?? 0,
        apellidos: controllers['apellidos']!.text,
        beneficiario: controllers['beneficiario']!.text,
        calle: controllers['calle']!.text,
        coloniaComunidad: controllers['colonia/Comunidad']!.text,
        comunidad: controllers['comunidad']!.text,
        contratoInd: controllers['contrato ind']!.text,
        curp: controllers['curp']!.text,
        departamento: controllers['departamento']!.text,
        domicilio: controllers['domicilio']!.text,
        edad: int.tryParse(controllers['edad']!.text) ?? 0,
        edoCivil: controllers['edo Civil']!.text,
        email: controllers['email']!.text,
        escolaridad: controllers['escolaridad']!.text,
        emailEmpresa: controllers['emailEmpresa']!.text,
        fechaIng: controllers['fechaIng']!.text,
        fechaNac: controllers['fechaNac']!.text,
        genero: controllers['genero']!.text,
          foto: 'https://cdn-icons-png.flaticon.com/512/1077/1077012.png',
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
        telefono1: int.tryParse(controllers['telefono 1']!.text) ?? 0,
        telefono2: int.tryParse(controllers['telefono 2']!.text) ?? 0,
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
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 900,
                maxHeight: MediaQuery.of(context).size.height * 0.9,
              ),
              child: Material(
                borderRadius: BorderRadius.circular(24),
                color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      child: Text(
                        usuario == null ? 'Nuevo Usuario' : 'Editar Usuario',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                Expanded(
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Table(
                        columnWidths: const {
                          0: FlexColumnWidth(1),
                          1: FlexColumnWidth(1),
                          2: FlexColumnWidth(1),
                        },
                        children: [

                          /// 🧍 Datos personales
                          const TableRow(children: [
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('🧍 Datos personales', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                            SizedBox(),
                            SizedBox(),
                          ]),
                          ..._buildFilas(context, ['nombre', 'apellidos', 'curp']),
                          ..._buildFilas(context, ['rfc', 'fechaNac', 'edad']),
                          ..._buildFilas(context, ['genero', 'edo Civil', 'escolaridad']),
                          ..._buildFilas(context, ['parentesco', 'parentesco2', 'beneficiario']),

                          /// 📞 Contacto
                          const TableRow(children: [
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('📞 Contacto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                            SizedBox(),
                            SizedBox(),
                          ]),
                          ..._buildFilas(context, ['email', 'emailEmpresa', 'telefono 1']),
                          ..._buildFilas(context, ['telefono 2']),

                          /// 🏡 Dirección
                          const TableRow(children: [
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('🏡 Dirección', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                            SizedBox(),
                            SizedBox(),
                          ]),
                          ..._buildFilas(context, ['calle', 'colonia/Comunidad', 'comunidad']),
                          ..._buildFilas(context, ['municipio', 'CP', 'domicilio']),

                          /// 💼 Información laboral
                          const TableRow(children: [
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('💼 Información laboral', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                            SizedBox(),
                            SizedBox(),
                          ]),
                          ..._buildFilas(context, ['puesto', 'departamento', 'fechaIng']),
                          ..._buildFilas(context, ['antiguedad', 'contrato ind', 'vacaciones']),
                          ..._buildFilas(context, ['tipo', 'salario']),

                          /// 🏢 Empresa y jerarquía
                          const TableRow(children: [
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('🏢 Empresa y jerarquía', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                            SizedBox(),
                            SizedBox(),
                          ]),
                          ..._buildFilas(context, ['no', 'privilegio', 'jefe']),
                          ..._buildFilas(context, ['reporta', 'ns', 'porcentaje']),
                        ],
                      ),
                    ),
                  ),
                ),

                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.cancel_outlined),
                            label: const Text('Cancelar'),
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              textStyle: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.save),
                            label: const Text('Guardar'),
                            onPressed: _crearUsuarioDesdeControles,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },

        ),
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

