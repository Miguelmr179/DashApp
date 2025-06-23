import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user.dart';

class AuthService {
  GoogleSignIn? _googleSignIn;

  AuthService() {
    if (!kIsWeb) {
      _googleSignIn = GoogleSignIn();
    }
  }

  Future<UserModel?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        final UserCredential userCredential =
            await FirebaseAuth.instance.signInWithPopup(googleProvider);
        final user = userCredential.user;
        if (user == null) return null;
        return UserModel(
          id: user.uid,
          email: user.email ?? '',
          role: 'user',
        );
      } else {
        final googleSignInAccount = await _googleSignIn?.signIn();
        if (googleSignInAccount == null) return null;

        final googleAuth = await googleSignInAccount.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final userCredential =
            await FirebaseAuth.instance.signInWithCredential(credential);
        final user = userCredential.user;
        if (user == null) return null;
        return UserModel(
          id: user.uid,
          email: user.email ?? '',
          role: 'user',
        );
      }
    } catch (e) {
      print('Error during Google Sign-In: $e');
      return null;
    }
  }
}
