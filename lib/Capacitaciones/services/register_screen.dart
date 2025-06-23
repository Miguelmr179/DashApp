import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dashapp/Capacitaciones/screens/login_screen.dart';
import 'package:dashapp/Capacitaciones/services/auth_service.dart';
import 'package:dashapp/Capacitaciones/models/user.dart';
import 'package:dashapp/Capacitaciones/services/theme_notifier.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:google_sign_in/google_sign_in.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final AuthService _authService = AuthService();

  String? _errorMessage;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _registerWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text.trim() != _confirmPasswordController.text.trim()) {
      setState(() => _errorMessage = 'Las contraseñas no coinciden');
      return;
    }

    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = UserModel(
        id: userCredential.user!.uid,
        email: _emailController.text.trim(),
        role: 'user',
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set(user.toJson());

      if (mounted) {
        _showSuccessBanner();
        await Future.delayed(const Duration(seconds: 2));
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LoginScreen(
              initialEmail: _emailController.text.trim(),
              initialPassword: _passwordController.text.trim(),
            ),
          ),
        );

      }
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = e.message ?? 'Ocurrió un error durante el registro.');
    } catch (e) {
      setState(() => _errorMessage = 'Error inesperado. Intenta nuevamente.');
    }
  }

  Future<void> _registerWithGoogle() async {
    try {
      await GoogleSignIn().signOut();
      await FirebaseAuth.instance.signOut();

      final user = await _authService.signInWithGoogle();

      if (user != null) {
        final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.id);
        final docSnapshot = await userDocRef.get();

        if (docSnapshot.exists) {
          setState(() => _errorMessage = 'Este correo ya ha sido registrado, inicia sesión');
          await Future.delayed(const Duration(seconds: 3));
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
          return;
        }

        await userDocRef.set(user.toJson());

        if (mounted) {
          _showSuccessBanner();
          await Future.delayed(const Duration(seconds: 2));
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      } else {
        setState(() => _errorMessage = 'Error al registrarse con Google.');
      }
    } catch (e) {
      print('Error during Google Register: $e');
      setState(() => _errorMessage = 'Ocurrió un error durante el registro con Google.');
    }
  }

  void _showSuccessBanner() {
    Flushbar(
      message: '¡Registro exitoso! Redirigiendo...',
      duration: const Duration(seconds: 2),
      flushbarPosition: FlushbarPosition.TOP,
      backgroundColor: Colors.green,
      margin: const EdgeInsets.all(8.0),
      borderRadius: BorderRadius.circular(8.0),
      icon: const Icon(
        Icons.check_circle_outline,
        size: 28.0,
        color: Colors.white,
      ),
    ).show(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = themeNotifier.value == ThemeMode.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final hintTextColor = isDarkMode ? Colors.white54 : Colors.black45;
    final iconColor = isDarkMode ? Colors.white : Colors.black54;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: isDarkMode
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

                    Image.asset(
                      'assets/ds.png',
                      height: 120,
                      width: 120,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Crear cuenta',
                      style: TextStyle(
                        fontSize: 32,
                        color: textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Capacitaciones DCC',
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
                            textColor: textColor,
                            hintColor: hintTextColor,
                            iconColor: iconColor,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Por favor ingresa tu correo';
                              if (!value.contains('@')) return 'Correo inválido';
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(
                            controller: _passwordController,
                            hintText: 'Contraseña',
                            icon: Icons.lock,
                            textColor: textColor,
                            hintColor: hintTextColor,
                            iconColor: iconColor,
                            obscureText: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                color: iconColor,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Por favor ingresa tu contraseña';
                              if (value.length < 6) return 'La contraseña debe tener al menos 6 caracteres';
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(
                            controller: _confirmPasswordController,
                            hintText: 'Confirmar contraseña',
                            icon: Icons.lock_outline,
                            textColor: textColor,
                            hintColor: hintTextColor,
                            iconColor: iconColor,
                            obscureText: _obscureConfirmPassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                                color: iconColor,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword = !_obscureConfirmPassword;
                                });
                              },
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Confirma tu contraseña';
                              if (value != _passwordController.text) return 'Las contraseñas no coinciden';
                              return null;
                            },
                          ),
                          const SizedBox(height: 30),
                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 20.0),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.redAccent),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _registerWithEmail,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16.0),
                                backgroundColor: const Color(0xFF6A11CB),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Registrar con correo',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _registerWithGoogle,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16.0),
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.login),
                              label: const Text(
                                'Registrar con Google',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextButton(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (context) => const LoginScreen()),
                              );
                            },
                            child: Text(
                              '¿Ya tienes cuenta? Inicia sesión',
                              style: TextStyle(color: textColor.withOpacity(0.7)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
    Widget? suffixIcon,
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
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
