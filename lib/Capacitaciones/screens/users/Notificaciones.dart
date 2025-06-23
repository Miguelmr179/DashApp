import 'package:dashapp/Capacitaciones/screens/admin/SendNotification.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class NotificationsScreen extends StatefulWidget {
  final String uid;

  const NotificationsScreen({super.key, required this.uid});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();

}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final Set<String> _knownDocumentIds = {}; // 👈 Guardamos los mensajes ya conocidos
  String _viewMode = 'recibidas'; // recibidas, enviadas, eliminadas

  String userRole = 'user'; // Valor predeterminado

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }


  Future<void> _fetchUserRole() async {
    final docSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .get();

    setState(() {
      userRole = docSnapshot.data()?['role'] ?? 'user';
    });
  }
  Future<void> _markAllAsRead() async {
    String? readField;
    Query? query;

    if (_viewMode == 'recibidas') {
      readField = 'readByReceiver';
      query = FirebaseFirestore.instance
          .collection('notifications')
          .where('uid', isEqualTo: widget.uid)
          .where('deletedByReceiver', isEqualTo: false)
          .where(readField, isEqualTo: false);
    } else if (_viewMode == 'enviadas') {
      readField = 'readBySender';
      query = FirebaseFirestore.instance
          .collection('notifications')
          .where('senderUid', isEqualTo: widget.uid)
          .where('deletedBySender', isEqualTo: false)
          .where(readField, isEqualTo: false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ No se pueden marcar como leídas las notificaciones eliminadas')),
      );
      return;
    }

    final querySnapshot = await query.get();
    final batch = FirebaseFirestore.instance.batch();

    for (var doc in querySnapshot.docs) {
      batch.update(doc.reference, {readField: true});
    }

    await batch.commit();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📩 Todas las notificaciones ${_viewMode == 'recibidas' ? 'recibidas' : 'enviadas'} fueron marcadas como leídas'),
      ),
    );
  }
  Future<void> _deleteAllNotifications() async {
    Query query;

    if (_viewMode == 'recibidas') {
      query = FirebaseFirestore.instance
          .collection('notifications')
          .where('uid', isEqualTo: widget.uid)
          .where('deletedByReceiver', isEqualTo: false);
    } else if (_viewMode == 'enviadas') {
      query = FirebaseFirestore.instance
          .collection('notifications')
          .where('senderUid', isEqualTo: widget.uid)
          .where('deletedBySender', isEqualTo: false);
    } else if (_viewMode == 'eliminadas') {
      // No permitimos eliminar definitivamente desde la vista de eliminadas
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ No se puede eliminar desde la vista de eliminadas')),
      );
      return;
    } else {
      return;
    }

    final querySnapshot = await query.get();
    final batch = FirebaseFirestore.instance.batch();

    for (var doc in querySnapshot.docs) {
      final fieldToUpdate = (_viewMode == 'recibidas') ? 'deletedByReceiver' : 'deletedBySender';
      batch.update(doc.reference, {fieldToUpdate: true});
    }

    await batch.commit();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🗑️ Las notificaciones visibles fueron marcadas como eliminadas')),
    );
  }
  Future<void> _deleteSingleNotification(String docId) async {
    final doc = await FirebaseFirestore.instance.collection('notifications').doc(docId).get();
    final data = doc.data() as Map<String, dynamic>?;

    if (data == null) return;

    final isSender = data['senderUid'] == widget.uid;

    await FirebaseFirestore.instance.collection('notifications').doc(docId).update({
      isSender ? 'deletedBySender' : 'deletedByReceiver': true,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notificación marcada como eliminada')),
    );
  }
  String _searchQuery = '';
  String _filterType = '';

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'success':
        return Colors.green;
      case 'warning':
        return Colors.orange;
      case 'alert':
        return Colors.red;
      default:
        return Colors.lightBlueAccent;
    }
  }

  Map<String, List<QueryDocumentSnapshot>> _groupByDate(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    Map<String, List<QueryDocumentSnapshot>> grouped = {
      'Hoy': [],
      'Ayer': [],
      'Esta semana': [],
      'Este mes': [],
      'Anterior': [],
    };

    for (var doc in docs) {
      final timestamp = (doc['timestamp'] as Timestamp).toDate();
      final date = DateTime(timestamp.year, timestamp.month, timestamp.day);

      if (date == today) {
        grouped['Hoy']!.add(doc);
      } else if (date == yesterday) {
        grouped['Ayer']!.add(doc);
      } else if (now.difference(date).inDays <= 7) {
        grouped['Esta semana']!.add(doc);
      } else if (now.difference(date).inDays <= 30) {
        grouped['Este mes']!.add(doc);
      } else {
        grouped['Anterior']!.add(doc);
      }
    }

    return grouped..removeWhere((key, value) => value.isEmpty);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundGradient = isDarkMode
        ? const LinearGradient(
      colors: [Color(0xFF0F2027), Color(0xFF2C5364)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    )
        : const LinearGradient(
      colors: [Color(0xFFE0E0E0), Color(0xFFFFFFFF)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          if (userRole == 'admin')
              IconButton(
                icon: const Icon(Icons.send),
                tooltip: 'Enviar notificación',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminSendNotificationScreen()),
                  );
                },
              ),
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Marcar todo como leído',
            onPressed: _markAllAsRead,

          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Eliminar todo',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Eliminar todas las notificaciones'),
                  content: const Text('¿Estás seguro de eliminar todas las notificaciones?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _deleteAllNotifications();
                      },
                      child: const Text('Eliminar'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
        body: Container(
          decoration: BoxDecoration(gradient: backgroundGradient),
          child: SafeArea(
            child: Column(
              children: [
                // 🔍 Filtros de búsqueda y tipo
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                              decoration: const InputDecoration(
                                hintText: 'Buscar notificaciones...',
                                prefixIcon: Icon(Icons.search),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          DropdownButton<String>(
                            value: _filterType,
                            hint: const Text('Tipo'),
                            onChanged: (value) => setState(() => _filterType = value ?? ''),
                            items: const [
                              DropdownMenuItem(value: '', child: Text('Todos')),
                              DropdownMenuItem(value: 'success', child: Text('Éxito')),
                              DropdownMenuItem(value: 'warning', child: Text('Advertencia')),
                              DropdownMenuItem(value: 'alert', child: Text('Alerta')),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ToggleButtons(
                        isSelected: [
                          _viewMode == 'recibidas',
                          if (userRole != 'user') _viewMode == 'enviadas',
                          _viewMode == 'eliminadas',
                        ],
                        onPressed: (index) {
                          setState(() {
                            if (userRole != 'user') {
                              _viewMode = ['recibidas', 'enviadas', 'eliminadas'][index];
                            } else {
                              _viewMode = ['recibidas', 'eliminadas'][index];
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text('Recibidas'),
                          ),
                          if (userRole != 'user')
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text('Enviadas'),
                            ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text('Eliminadas'),
                          ),
                        ],
                      ),

                    ],
                  ),
                ),


                // 📨 Lista de notificaciones
          Expanded(
            child: Builder(
              builder: (context) {
                Query baseQuery = FirebaseFirestore.instance
                    .collection('notifications')
                    .orderBy('timestamp', descending: true);

                if (_viewMode == 'recibidas') {
                  baseQuery = baseQuery
                      .where('uid', isEqualTo: widget.uid)
                      .where('deletedByReceiver', isEqualTo: false);
                } else if (_viewMode == 'enviadas') {
                  baseQuery = baseQuery
                      .where('senderUid', isEqualTo: widget.uid)
                      .where('deletedBySender', isEqualTo: false);
                } else if (_viewMode == 'eliminadas') {
                  baseQuery = baseQuery
                      .where(Filter.or(
                    Filter.and(
                      Filter("uid", isEqualTo: widget.uid),
                      Filter("deletedByReceiver", isEqualTo: true),
                    ),
                    Filter.and(
                      Filter("senderUid", isEqualTo: widget.uid),
                      Filter("deletedBySender", isEqualTo: true),
                    ),
                  ));
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: baseQuery.snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('❌ Error: ${snapshot.error}'));
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Text(
                          _viewMode == 'enviadas'
                              ? 'No has enviado notificaciones aún.'
                              : 'No se encontraron notificaciones.',
                        ),
                      );
                    }


                    final filteredDocs = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final message = (data['message'] ?? '').toLowerCase();
                      final type = (data['type'] ?? '').toLowerCase();
                      final matchesSearch = _searchQuery.isEmpty || message.contains(_searchQuery);
                      final matchesType = _filterType.isEmpty || type == _filterType;
                      return matchesSearch && matchesType;
                    }).toList();

                    if (filteredDocs.isEmpty) {
                      return const Center(child: Text('No se encontraron notificaciones.'));
                    }

                    final grouped = _groupByDate(filteredDocs);

                    return ListView(
                      children: grouped.entries.map((entry) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Text(
                                entry.key,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                            ...entry.value.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final docId = doc.id;
                              final type = data['type'] ?? '';
                              final isSender = data['senderUid'] == widget.uid;
                              final isUnread = isSender ? !(data['readBySender'] ?? false) : !(data['readByReceiver'] ?? false);
                              final isNew = !_knownDocumentIds.contains(docId);
                              if (isNew) _knownDocumentIds.add(docId);

                              return Dismissible(
                                key: ValueKey(docId),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  color: Colors.red,
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  child: const Icon(Icons.delete_forever, color: Colors.white),
                                ),
                                onDismissed: (_) => _deleteSingleNotification(docId),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).cardColor,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 4,
                                        offset: Offset(2, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          color: _getNotificationColor(type),
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(12),
                                            bottomLeft: Radius.circular(12),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: ListTile(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          //Mostrar el nombre del usuario que envió la notificación
                                          leading: CircleAvatar(
                                            backgroundColor: _getNotificationColor(type),
                                            child: const Icon(Icons.notifications, color: Colors.white),
                                          ),

                                          title: FutureBuilder<DocumentSnapshot>(
                                            future: FirebaseFirestore.instance
                                                .collection('users')
                                                .doc(data['senderUid'])
                                                .get(),
                                            builder: (context, snapshot) {
                                              if (snapshot.connectionState == ConnectionState.waiting) {
                                                return const Text(
                                                  'Cargando...',
                                                  style: TextStyle(fontWeight: FontWeight.bold),
                                                );
                                              }

                                              if (!snapshot.hasData || !snapshot.data!.exists) {
                                                return const Text(
                                                  'Servidor.dcc@grupodiecastmexico',
                                                  style: TextStyle(fontWeight: FontWeight.bold),
                                                );
                                              }

                                              final userData = snapshot.data!.data() as Map<String, dynamic>;
                                              final senderName = userData['fullName'] ?? userData['email'] ?? 'Sin nombre';

                                              return Text(
                                                isSender ? 'Tú' : senderName,
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              );
                                            },
                                          ),

                                          subtitle: Text(
                                            data['message'] ?? '',
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                          ),


                                          trailing: isUnread
                                              ? const Icon(Icons.fiber_new, color: Colors.deepOrangeAccent)
                                              : const Icon(Icons.check_circle_outline, color: Colors.grey),
                                          onTap: () async {
                                            final isSender = data['senderUid'] == widget.uid;
                                            final readField = isSender ? 'readBySender' : 'readByReceiver';

                                            if (data[readField] == false) {
                                              await FirebaseFirestore.instance
                                                  .collection('notifications')
                                                  .doc(docId)
                                                  .update({readField: true});
                                              setState(() {});
                                            }
                                          },

                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        );
                      }).toList(),
                    );
                  },
                );
              },
            ),
          ),
              ],
            ),
          ),
        ),
    );
  }
}


