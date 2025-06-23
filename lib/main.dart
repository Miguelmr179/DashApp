import 'package:dashapp/Capacitaciones/screens/login_screen.dart';
import 'package:dashapp/Capacitaciones/screens/home_screen.dart';
import 'package:dashapp/Capacitaciones/services/theme_notifier.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:flutter_localizations/flutter_localizations.dart';



import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  User? user;
  String? role;

  if (kIsWeb) {
    try {
      final result = await FirebaseAuth.instance.getRedirectResult();
      if (result.user != null) {
        user = result.user;
      }
    } catch (e) {
      print('Error al recuperar redirect: $e');
    }
  } else {
    user = FirebaseAuth.instance.currentUser;
  }

  if (user != null) {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        role = doc.data()?['role'] ?? 'user';
      }
    } catch (e) {
      print('Error al obtener datos de usuario: $e');
    }
  }

  await initializeDateFormatting('es', null);

  runApp(MyApp(initialUser: user, role: role));
}

class MyApp extends StatelessWidget {
  final User? initialUser;
  final String? role;

  const MyApp({super.key, required this.initialUser, required this.role});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'CapacitacionesDCC',
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: currentMode,

          // 👇 LO NUEVO
          locale: const Locale('es', 'MX'),
          supportedLocales: const [
            Locale('es', 'MX'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          home: initialUser != null && role != null
              ? HomeScreen(role: role!)
              : const LoginScreen(),
        );

      },
    );
  }
}
