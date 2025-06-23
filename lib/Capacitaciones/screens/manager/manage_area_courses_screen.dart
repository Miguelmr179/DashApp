import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:dashapp/Capacitaciones/screens/admin/Create_Video.dart';

class ManageAreaCoursesScreen extends StatelessWidget {
  const ManageAreaCoursesScreen({Key? key}) : super(key: key);

  Future<String?> _getUserArea() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return doc.data()?['area'];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _getUserArea(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final area = snapshot.data;
        if (area == null) {
          return const Scaffold(body: Center(child: Text('No tienes un área asignada.')));
        }

        return CreateContentScreen(preselectedCategory: area);
      },
    );
  }
}
