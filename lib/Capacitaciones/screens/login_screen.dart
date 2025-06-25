import 'dart:async';

import 'package:dashapp/Capacitaciones/screens/register_screen.dart';
import 'package:dashapp/Capacitaciones/services/EditProfileScreen.dart';
import 'package:dashapp/General/home_screen.dart';
import 'package:dashapp/Huellas/Vistas/menu.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dashapp/Capacitaciones/services/theme_notifier.dart';
import 'package:dashapp/Capacitaciones/services/auth_service.dart';
import 'package:google_sign_in/google_sign_in.dart';


class LoginScreen extends StatefulWidget {
  final String? initialEmail;
  final String? initialPassword;

  const LoginScreen({Key? key, this.initialEmail, this.initialPassword}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}


class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null) {
      _emailController.text = widget.initialEmail!;
    }
    if (widget.initialPassword != null) {
      _passwordController.text = widget.initialPassword!;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }



  Future<void> _loginWithEmail() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    if (_formKey.currentState!.validate()) {
      try {
        UserCredential userCredential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        )
            .timeout(const Duration(seconds: 12), onTimeout: () {
          throw TimeoutException('Verifica tu conexión a internet.');
        });

        final userId = userCredential.user!.uid;
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (!userDoc.exists) {
          setState(() {
            _errorMessage = 'Este usuario no está registrado en el sistema.';
            _isLoading = false;
          });
          return;
        }

        final data = userDoc.data();
        final fullName = data?['fullName'];
        final nomina = data?['nomina'];
        final role = data?['role'] ?? 'user';
        final isActive = data?['activo'] == true;

        if (!isActive) {
          setState(() {
            _errorMessage = 'Tu cuenta está inactiva. Contacta al administrador.';
            _isLoading = false;
          });
          return;
        }

        if (mounted) {
          final isIncomplete = fullName == null ||
              nomina == null ||
              (fullName is String && fullName.trim().isEmpty) ||
              (nomina is String && nomina.trim().isEmpty);

          if (isIncomplete) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                  (Route<dynamic> route) => false,
            );
          } else {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => HomeScreen(role: role)),
                  (Route<dynamic> route) => false,
            );
          }
        }
      } on TimeoutException {
        setState(() {
          _errorMessage = 'El proceso tomó demasiado tiempo. Intenta nuevamente.';
          _isLoading = false;
        });
      } on FirebaseAuthException catch (e) {
        setState(() {
          if (e.code == 'user-not-found' || e.code == 'wrong-password') {
            _errorMessage = 'Correo o contraseña inválidos.';
          } else {
            _errorMessage = 'Ocurrió un error. Intenta nuevamente.';
          }
        });
      } catch (e) {
        setState(() {
          _errorMessage = 'Ocurrió un error inesperado. Intenta más tarde.';
        });
      } finally {
        setState(() => _isLoading = false);
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      await GoogleSignIn().signOut();
      await FirebaseAuth.instance.signOut();

      final user = await _authService
          .signInWithGoogle()
          .timeout(const Duration(seconds: 12), onTimeout: () {
        throw TimeoutException('La solicitud ha tardado demasiado.');
      });

      if (kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS) &&
          user == null) {
        return;
      }

      if (user != null) {
        final userDocRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.id);
        final docSnapshot = await userDocRef.get();

        if (!docSnapshot.exists) {
          setState(() {
            _errorMessage = 'Tu cuenta no está registrada. Favor de registrarse.';
            _isLoading = false;
          });
          return;
        }

        final data = docSnapshot.data();
        final role = data?['role'] ?? 'user';
        final fullName = data?['fullName'];
        final nomina = data?['nomina'];
        final isActive = data?['activo'] == true;

        if (!isActive) {
          setState(() {
            _errorMessage = 'Tu cuenta está inactiva. Contacta al administrador.';
            _isLoading = false;
          });
          return;
        }

        if (mounted) {
          if (fullName == null ||
              fullName.toString().trim().isEmpty ||
              nomina == null ||
              nomina.toString().trim().isEmpty) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                  (Route<dynamic> route) => false,
            );
          } else {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => HomeScreen(role: role)),
                  (Route<dynamic> route) => false,
            );
          }
        }
      } else {
        setState(() {
          _errorMessage = 'Error al iniciar sesión con Google.';
          _isLoading = false;
        });
      }
    } on TimeoutException {
      setState(() {
        _errorMessage = 'El proceso tomó demasiado tiempo. Intenta nuevamente.';
        _isLoading = false;
      });
    } catch (e) {
      print('Error during Google Sign-In: $e');
      setState(() {
        _errorMessage = 'Ocurrió un error inesperado al iniciar sesión.';
        _isLoading = false;
      });
    }
  }

  Future<bool> _mostrarDialogoContrasena(BuildContext context) async {
    final TextEditingController _controller = TextEditingController();
    bool acceso = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Acceso restringido'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Ingresa la contraseña para continuar:'),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: 'Contraseña',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_controller.text.trim() == 'Dcc2025') {
                  acceso = true;
                }
                Navigator.pop(context);
              },
              child: const Text('Aceptar'),
            ),
          ],
        );
      },
    );

    return acceso;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = themeNotifier.value == ThemeMode.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final hintTextColor = isDarkMode ? Colors.white54 : Colors.black45;
    final iconColor = isDarkMode ? Colors.white : Colors.black54;

    return Scaffold(
      body: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient:
                  isDarkMode
                      ? const LinearGradient(
                        colors: [Color(0xFF0F2027), Color(0xFF2C5364)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      )
                      : const LinearGradient(
                        colors: [Color(0xFFE0E0E0), Color(0xFFFFFFFF)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
            ),
            child: Stack(
              children: [
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        //Insert your logo here
                        Image.asset(
                          'assets/ds.png',
                          height: 120,
                          width: 120,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Bienvenido',
                          style: TextStyle(
                            fontSize: 32,
                            color: textColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Sistema Dash',
                          style: TextStyle(
                            fontSize: 18,
                            color: textColor.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 40),
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              _buildTextField(
                                controller: _emailController,
                                hintText: 'Correo',
                                icon: Icons.email,
                                keyboardType: TextInputType.emailAddress,
                                textColor: textColor,
                                hintColor: hintTextColor,
                                iconColor: iconColor,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Por favor ingresa tu correo';
                                  }
                                  if (!value.contains('@')) {
                                    return 'Correo inválido';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              _buildTextField(
                                controller: _passwordController,
                                hintText: 'Contraseña',
                                icon: Icons.lock,
                                obscureText: true,
                                textColor: textColor,
                                hintColor: hintTextColor,
                                iconColor: iconColor,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Por favor ingresa tu contraseña';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 30),
                              if (_errorMessage != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 20.0),
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ),
                              if (_isLoading)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: CircularProgressIndicator(),
                                ),
                              if (!_isLoading) ...[
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _loginWithEmail,
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16.0,
                                      ),
                                      backgroundColor: const Color(0xFF6A11CB),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      'Iniciar Sesión',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _loginWithGoogle,
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16.0,
                                      ),
                                      backgroundColor: Colors.redAccent,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: const Icon(Icons.login),
                                    label: const Text(
                                      'Iniciar con Google',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => const RegisterScreen(),
                                    ),
                                  );
                                },
                                child: Text(
                                  'Crear nueva cuenta',
                                  style: TextStyle(
                                    color: textColor.withOpacity(0.7),
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  final accesoPermitido = await _mostrarDialogoContrasena(context);
                                  if (accesoPermitido) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const MenuPage(),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Contraseña incorrecta')),
                                    );
                                  }
                                },
                                child: Text(
                                  'Iniciar sesión como invitado',
                                  style: TextStyle(
                                    color: textColor.withOpacity(0.7),
                                  ),
                                ),
                              ),

                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: IconButton(
                        icon: Icon(
                          themeNotifier.value == ThemeMode.dark
                              ? Icons.wb_sunny_outlined
                              : Icons.nightlight_round,
                          color: iconColor,
                        ),
                        onPressed: () {
                          themeNotifier.value =
                              themeNotifier.value == ThemeMode.dark
                                  ? ThemeMode.light
                                  : ThemeMode.dark;
                          setState(() {});
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required Color textColor,
    required Color hintColor,
    required Color iconColor,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        filled: true,
        fillColor: textColor.withOpacity(0.05),
        hintText: hintText,
        hintStyle: TextStyle(color: hintColor),
        prefixIcon: Icon(icon, color: iconColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
