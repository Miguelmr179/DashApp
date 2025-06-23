import 'package:cloud_firestore/cloud_firestore.dart';

class AreaService {
  final _areasCollection = FirebaseFirestore.instance.collection('areas');

  Future<List<String>> getAllAreas() async {
    final snapshot = await _areasCollection.get();
    return snapshot.docs.map((doc) => doc['name'] as String).toList();
  }

  Future<void> addArea(String areaName) async {
    await _areasCollection.add({'name': areaName.trim()});
  }

  Future<void> deleteArea(String areaName) async {
    final snapshot = await _areasCollection
        .where('name', isEqualTo: areaName.trim())
        .get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }
}
