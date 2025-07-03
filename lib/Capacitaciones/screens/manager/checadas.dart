import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

class ResumenChecadasJefeScreen extends StatefulWidget {
  final int nominaJefe;

  const ResumenChecadasJefeScreen({super.key, required this.nominaJefe});

  @override
  State<ResumenChecadasJefeScreen> createState() => _ResumenChecadasJefeScreenState();
}

class _ResumenChecadasJefeScreenState extends State<ResumenChecadasJefeScreen> {
  Future<List<TeamMemberAttendance>> _teamFuture = Future.value([]);
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _teamFuture = _fetchTeamMembers();
  }

  Future<List<TeamMemberAttendance>> _fetchTeamMembers() async {
    try {
      final teamQuery = await _firestore
          .collection('UsuariosDcc')
          .where('reporta', isEqualTo: widget.nominaJefe)
          .get();

      if (teamQuery.docs.isEmpty) return [];

      return teamQuery.docs.map((doc) {
        final data = doc.data();
        final regNo = data['Título']?.toString() ?? '';
        final int? no = data['no'] is int ? data['no'] : int.tryParse(data['no']?.toString() ?? '');
        //pasar no a string
        final noInt = no?.toString() ?? '';
        final nombre = data['nombre']?.toString() ?? 'Sin nombre';

        return TeamMemberAttendance(
          nomina: noInt,
          name: nombre,
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ Error al obtener empleados a cargo: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Empleados a tu cargo'),
      ),
      body: FutureBuilder<List<TeamMemberAttendance>>(
        future: _teamFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final teamData = snapshot.data ?? [];

          if (teamData.isEmpty) {
            return const Center(child: Text('No tienes empleados a tu cargo.'));
          }

          return SfDataGrid(
            source: TeamDataSource(teamData),
            columns: [
              GridColumn(
                columnName: 'nomina',
                width: 120,
                label: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(8.0),
                  child: const Text('Nómina', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              GridColumn(
                columnName: 'nombre',
                width: 220,
                label: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(8.0),
                  child: const Text('Nombre', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
            gridLinesVisibility: GridLinesVisibility.both,
            headerGridLinesVisibility: GridLinesVisibility.both,
          );
        },
      ),
    );
  }
}

class TeamMemberAttendance {
  final String nomina;
  final String name;

  TeamMemberAttendance({
    required this.nomina,
    required this.name,
  });
}

class TeamDataSource extends DataGridSource {
  TeamDataSource(List<TeamMemberAttendance> teamData) {
    _rows = teamData
        .map<DataGridRow>((e) => DataGridRow(cells: [
      DataGridCell<String>(columnName: 'nomina', value: e.nomina),
      DataGridCell<String>(columnName: 'nombre', value: e.name),
    ]))
        .toList();
  }

  late final List<DataGridRow> _rows;

  @override
  List<DataGridRow> get rows => _rows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((cell) {
        return Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(8.0),
          child: Text(
            cell.value.toString(),
            style: const TextStyle(color: Colors.black87),
          ),
        );
      }).toList(),
    );
  }
}
