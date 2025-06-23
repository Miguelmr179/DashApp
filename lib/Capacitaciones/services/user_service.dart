import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  Future<bool> isAdmin(String uid) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (userDoc.exists) {
        return userDoc.get('isAdmin') ?? false;
      } else {
        return false;
      }
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }
}