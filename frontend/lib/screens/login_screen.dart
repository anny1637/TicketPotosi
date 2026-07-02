import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../screens/home_screen.dart';
import '../screens/register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // Paleta de Colores Lavanda Pastel (Claymorphism/Neumorphic)
  static const Color brandBg = Color(0xFFF3E8FF); // Fondo lavanda claro
  static const Color cardBg = Colors.white;
  static const Color primaryPurple = Color(0xFF9F78FF);
  static const Color primaryLight = Color(0xFFC7B0FF);
  static const Color textDark = Color(0xFF4A3E65);
  static const Color textMuted = Color(0xFF9E92B4);
  static const Color inputBg = Color(0xFFF8F6FC);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final response = await ApiService.login(
        _loginController.text.trim(),
        _passwordController.text.trim(),
      );

      if (response['token'] != null) {
        await ApiService.saveToken(response['token']);
        await ApiService.saveUserData(response['user'] as Map<String, dynamic>);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const HomeScreen(),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
        }
      } else {
        _showMessage(
          response['message'] ?? 'Credenciales incorrectas',
          isError: true,
        );
      }
    } catch (e) {
      debugPrint('Error login: $e');
      _showMessage(
        'No se pudo conectar al servidor. Inténtalo de nuevo.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showForgotPasswordDialog() {
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool isResetting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Column(
            children: [
              Icon(Icons.lock_reset_rounded, color: primaryPurple, size: 40),
              SizedBox(height: 8),
              Text(
                'Restablecer Contraseña',
                style: TextStyle(color: textDark, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ingresa tu correo y celular registrados para cambiar tu contraseña de inmediato.',
                  style: TextStyle(color: textMuted, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                _dialogField(emailCtrl, 'Correo Electrónico', Icons.email_rounded),
                const SizedBox(height: 10),
                _dialogField(phoneCtrl, 'Número de Celular', Icons.phone_rounded, keyboardType: TextInputType.phone),
                const SizedBox(height: 10),
                _dialogField(passCtrl, 'Nueva Contraseña', Icons.lock_open_rounded, obscure: true),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: textMuted)),
            ),
            ElevatedButton(
              onPressed: isResetting
                  ? null
                  : () async {
                      final email = emailCtrl.text.trim();
                      final phone = phoneCtrl.text.trim();
                      final newPass = passCtrl.text;

                      if (email.isEmpty || phone.isEmpty || newPass.isEmpty) {
                        _showMessage('Por favor completa todos los campos', isError: true);
                        return;
                      }
                      if (newPass.length < 6) {
                        _showMessage('La contraseña debe tener mínimo 6 caracteres', isError: true);
                        return;
                      }

                      setDialogState(() => isResetting = true);
                      try {
                        final res = await ApiService.forgotPassword(email, phone, newPass);
                        Navigator.pop(ctx);
                        _showMessage(res['message'] ?? 'Contraseña restablecida correctamente.');
                      } catch (e) {
                        _showMessage('Error al restablecer. Verifica tus datos de registro.', isError: true);
                      } finally {
                        setDialogState(() => isResetting = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryPurple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isResetting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Restablecer', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogField(TextEditingController ctrl, String label, IconData icon,
      {bool obscure = false, TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: textDark, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: textMuted, fontSize: 12),
        prefixIcon: Icon(icon, color: primaryPurple, size: 16),
        filled: true,
        fillColor: inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
    );
  }

  void _showServerConfigDialog() async {
    final currentUrl = await ApiService.getBaseUrl();
    final urlCtrl = TextEditingController(text: currentUrl);
    bool isScanning = false;

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Column(
            children: [
              Icon(Icons.wifi_rounded, color: primaryPurple, size: 36),
              SizedBox(height: 8),
              Text(
                'Conexión de Servidor',
                style: TextStyle(color: textDark, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Introduce la IP local o busca automáticamente el servidor en tu red WiFi.',
                style: TextStyle(color: textMuted, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: urlCtrl,
                style: const TextStyle(color: textDark, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'URL de API del Servidor',
                  labelStyle: const TextStyle(color: textMuted, fontSize: 12),
                  prefixIcon: const Icon(Icons.link_rounded, color: primaryPurple, size: 16),
                  filled: true,
                  fillColor: inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: isScanning
                    ? null
                    : () async {
                        setDialogState(() => isScanning = true);
                        final newUrl = await ApiService.scanAndSaveServerIp();
                        setDialogState(() {
                          isScanning = false;
                          if (newUrl != null) {
                            urlCtrl.text = newUrl;
                            _showMessage('¡Servidor encontrado e inalámbricamente vinculado!');
                          } else {
                            _showMessage('No se detectó el servidor. Verifica que corra en el puerto 8000.', isError: true);
                          }
                        });
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryPurple.withOpacity(0.1),
                  foregroundColor: primaryPurple,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                icon: isScanning
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: primaryPurple, strokeWidth: 2))
                    : const Icon(Icons.wifi_find_rounded, size: 18),
                label: const Text('Autodetectar Servidor 🔍', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                final url = urlCtrl.text.trim();
                if (url.isNotEmpty) {
                  await ApiService.setBaseUrl(url);
                  Navigator.pop(ctx);
                  _showMessage('URL del servidor guardada correctamente.');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryPurple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Guardar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: TextStyle(color: isError ? Colors.white : textDark, fontSize: 13, fontWeight: FontWeight.w600)),
        backgroundColor: isError ? const Color(0xFFF48FB1) : const Color(0xFFC8E6C9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: brandBg,
      body: SafeArea(
        child: Stack(
          children: [
            FadeTransition(
              opacity: _fadeAnim,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  const SizedBox(height: 20),
                  // Bienvenido texto en español
                  const Text(
                    '¡Bienvenido!',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: textDark,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Inicia sesión para continuar con tu viaje',
                    style: TextStyle(
                      fontSize: 14,
                      color: textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Ilustración 3D de avatar/corazón estilo arcilla
                  _buildClayIllustration(),
                  const SizedBox(height: 24),

                  // Tarjeta de login con bordes muy redondeados
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD6C8EC).withOpacity(0.4),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Input Email/User
                          _buildInput(
                            controller: _loginController,
                            hint: 'Correo o Número de celular',
                            icon: Icons.person_rounded,
                            validator: (v) => (v == null || v.isEmpty) ? 'Ingresa tu correo o celular' : null,
                          ),
                          const SizedBox(height: 16),

                          // Input Password
                          _buildInput(
                            controller: _passwordController,
                            hint: 'Contraseña',
                            icon: Icons.lock_rounded,
                            obscure: _obscurePassword,
                            suffix: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                color: textMuted,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            validator: (v) => (v == null || v.isEmpty) ? 'Ingresa tu contraseña' : null,
                          ),

                          // Olvidó contraseña (FUNCIONAL)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _showForgotPasswordDialog,
                              child: const Text(
                                '¿Olvidaste tu contraseña?',
                                style: TextStyle(
                                  color: primaryPurple,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Botón Login redondeado 3D
                          GestureDetector(
                            onTap: _isLoading ? null : _login,
                            child: Container(
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [primaryPurple, Color(0xFFB18FFF)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryPurple.withOpacity(0.4),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Text(
                                        'Ingresar',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Línea decorativa "o continuar con"
                          Row(
                            children: [
                              Expanded(child: Divider(color: textMuted.withOpacity(0.3))),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Text('o continuar con', style: TextStyle(color: textMuted, fontSize: 11)),
                              ),
                              Expanded(child: Divider(color: textMuted.withOpacity(0.3))),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Iconos de redes sociales (Google, Facebook y TikTok)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildSocialIcon(
                                child: const Text(
                                  'G',
                                  style: TextStyle(
                                    color: Color(0xFFDB4437),
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    fontFamily: 'sans-serif',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 20),
                              _buildSocialIcon(
                                child: const Icon(
                                  Icons.facebook,
                                  color: Color(0xFF1877F2),
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 20),
                              _buildSocialIcon(
                                child: const Icon(
                                  Icons.music_note_rounded,
                                  color: Color(0xFF010101),
                                  size: 24,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Registro
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "¿No tienes una cuenta? ",
                                style: TextStyle(color: textMuted, fontSize: 13),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                                ),
                                child: const Text(
                                  'Regístrate',
                                  style: TextStyle(
                                    color: primaryPurple,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.settings_suggest_rounded, color: primaryPurple, size: 28),
                tooltip: 'Configurar Servidor',
                onPressed: _showServerConfigDialog,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialIcon({required Widget child}) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE1D5F5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD6C8EC).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: child,
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      style: const TextStyle(color: textDark, fontSize: 14, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: textMuted, fontSize: 13),
        prefixIcon: Container(
          margin: const EdgeInsets.only(right: 12, left: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFEDE7F6),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: primaryPurple, size: 20),
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: primaryLight, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
    );
  }

  Widget _buildClayIllustration() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD6C8EC).withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
        ),
        Container(
          width: 100,
          height: 100,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [primaryPurple, primaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.confirmation_number_rounded,
              color: Colors.white,
              size: 44,
            ),
          ),
        ),
        Positioned(
          top: 0,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFF8A80),
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: Colors.white,
              size: 12,
            ),
          ),
        ),
      ],
    );
  }
}
