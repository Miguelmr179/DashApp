import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminSendNotificationScreen extends StatefulWidget {
  const AdminSendNotificationScreen({super.key});

  @override
  State<AdminSendNotificationScreen> createState() => _AdminSendNotificationScreenState();
}

class _AdminSendNotificationScreenState extends State<AdminSendNotificationScreen> {

  String? selectedUid;
  String message = '';
  String type = 'alert';

  bool sending = false;

  Future<void> sendNotification() async {
    if (selectedUid == null || message.trim().isEmpty) return;

    setState(() => sending = true);
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? 'admin';

    try {
      if (selectedUid == 'ALL') {
        final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
        final batch = FirebaseFirestore.instance.batch();

        for (var doc in usersSnapshot.docs) {
          final uid = doc.id;
          final notifRef = FirebaseFirestore.instance.collection('notifications').doc();
          batch.set(notifRef, {
            'message': message,
            'read': false,
            'timestamp': Timestamp.now(),
            'uid': uid,
            'senderUid': currentUid,
            'type': type,
            'deletedByReceiver': false,
            'deletedBySender': false,
            'readBySender': false,
            'readByReceiver': false,
          });
        }

        await batch.commit();
      } else {
        await FirebaseFirestore.instance.collection('notifications').add({
          'message': message,
          'readBySender': false,
          'readByReceiver': false,
          'timestamp': Timestamp.now(),
          'uid': selectedUid,
          'senderUid': currentUid,
          'type': type,
          'deletedByReceiver': false,
          'deletedBySender': false,
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Notificación registrada')),
      );

      setState(() {
        message = '';
        selectedUid = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error al registrar: $e')),
      );
    }

    setState(() => sending = false);
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('📣 Enviar Notificación'),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Card(
                elevation: 12,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                color: Theme.of(context).cardColor.withOpacity(0.95),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Selecciona un usuario y escribe un mensaje para notificar',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('users').snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const LinearProgressIndicator();

                          final users = snapshot.data!.docs;

                          return DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Usuario',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            isExpanded: true,
                            value: selectedUid,
                            items: [
                              const DropdownMenuItem(
                                value: 'ALL',
                                child: Text('🌐 Todos los usuarios'),
                              ),
                              ...users.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                final name = data['fullName'] ?? data['email'];
                                return DropdownMenuItem<String>(
                                  value: doc.id,
                                  child: Text(name),
                                );
                              }),
                            ],
                            onChanged: (value) => setState(() => selectedUid = value),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: type,
                        decoration: InputDecoration(
                          labelText: 'Tipo de notificación',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'success', child: Text('✅ Éxito')),
                          DropdownMenuItem(value: 'warning', child: Text('⚠️ Advertencia')),
                          DropdownMenuItem(value: 'alert', child: Text('❗Alerta')),
                        ],
                        onChanged: (value) => setState(() => type = value ?? 'alert'),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        decoration: InputDecoration(
                          labelText: 'Mensaje',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 5,
                        onChanged: (value) => message = value,
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.send_rounded),
                          label: sending
                              ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                              : const Text('Enviar Notificación'),
                          onPressed: sending ? null : sendNotification,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            backgroundColor: Colors.blueAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
