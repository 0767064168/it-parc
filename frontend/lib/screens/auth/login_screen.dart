// ============================================
// lib/screens/auth/login_screen.dart — Login
// ============================================

import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import 'package:dio/dio.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  late final AnimationController _entranceCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  late final AnimationController _blobCtrl;

  @override
  void initState() {
    super.initState();

    // Entrance animation
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic));

    // Blob slow rotation
    _blobCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _entranceCtrl.dispose();
    _blobCtrl.dispose();
    super.dispose();
  }

  void _showServerConfigDialog(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final urlController = TextEditingController(text: authProvider.getServerUrl());
    bool isTesting = false;
    String? testResult;
    Color testResultColor = Colors.white;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Configuration Serveur',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Entrez l\'adresse URL de l\'API du serveur :',
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: urlController,
                    style: GoogleFonts.inter(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Ex: http://192.168.1.38:3000/api',
                      hintStyle: GoogleFonts.inter(color: Colors.white30),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.primaryColor),
                      ),
                    ),
                  ),
                  if (testResult != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      testResult!,
                      style: GoogleFonts.inter(color: testResultColor, fontSize: 13, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: isTesting
                        ? null
                        : () async {
                            setState(() {
                              isTesting = true;
                              testResult = 'Connexion en cours...';
                              testResultColor = Colors.white70;
                            });

                            try {
                              final testDio = Dio(BaseOptions(
                                connectTimeout: const Duration(seconds: 4),
                                receiveTimeout: const Duration(seconds: 4),
                              ));
                              final testUrl = urlController.text.trim();
                              final cleanUrl = testUrl.endsWith('/')
                                  ? testUrl.substring(0, testUrl.length - 1)
                                  : testUrl;
                              
                              final response = await testDio.get('$cleanUrl/health');
                              if (response.statusCode == 200 &&
                                  response.data is Map &&
                                  response.data['success'] == true) {
                                setState(() {
                                  testResult = '✅ Connexion réussie !';
                                  testResultColor = const Color(0xFF34D399);
                                });
                              } else {
                                setState(() {
                                  testResult = '❌ Serveur injoignable ou réponse invalide';
                                  testResultColor = const Color(0xFFFCA5A5);
                                });
                              }
                            } catch (e) {
                              setState(() {
                                testResult = '❌ Erreur de connexion au serveur';
                                testResultColor = const Color(0xFFFCA5A5);
                              });
                            } finally {
                              setState(() {
                                isTesting = false;
                              });
                            }
                          },
                    icon: isTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                          )
                        : const Icon(Icons.bolt_rounded, size: 18),
                    label: Text(isTesting ? 'Test...' : 'Tester la connexion'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Annuler', style: GoogleFonts.inter(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final cleanUrl = urlController.text.trim();
                    final finalUrl = cleanUrl.endsWith('/')
                        ? cleanUrl.substring(0, cleanUrl.length - 1)
                        : cleanUrl;
                    await authProvider.updateServerUrl(finalUrl);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Configuration serveur enregistrée : $finalUrl'),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.login(
        _usernameController.text,
        _passwordController.text,
      );
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(authProvider.errorMessage ?? 'Identifiants incorrects')),
              ],
            ),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 600;

    return Scaffold(
      body: Stack(
        children: [
          // ── Fond gradient ──────────────────────────────────────
          Container(
            decoration: const BoxDecoration(gradient: AppGradients.loginBackground),
          ),

          // ── Blob décoratif animé ───────────────────────────────
          AnimatedBuilder(
            animation: _blobCtrl,
            builder: (context, child) {
              return CustomPaint(
                size: size,
                painter: _BlobPainter(_blobCtrl.value),
              );
            },
          ),

          // ── Contenu centré ────────────────────────────────────
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: _buildCard(authProvider, isDesktop, size),
                ),
              ),
            ),
          ),

          // ── Bouton configuration serveur ───────────────────────
          Positioned(
            top: 16,
            right: 16,
            child: SafeArea(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: Colors.white.withValues(alpha: 0.1),
                    child: IconButton(
                      icon: const Icon(Icons.dns_rounded, color: Colors.white70),
                      tooltip: 'Configuration Serveur',
                      onPressed: () => _showServerConfigDialog(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(AuthProvider authProvider, bool isDesktop, Size size) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: isDesktop ? 440 : size.width * 0.92,
          padding: const EdgeInsets.symmetric(horizontal: 36.0, vertical: 40.0),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(28.0),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.20),
              width: 1.0,
            ),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: AppGradients.heroBanner,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.lan_rounded, color: Colors.white, size: 36),
                  ),
                ),
                const SizedBox(height: 24),

                // Titre
                Text(
                  'IT PARC',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 2.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Direction Informatique de Bouaké',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 36),

                // Champ utilisateur
                _buildField(
                  controller: _usernameController,
                  label: 'Nom d\'utilisateur',
                  hint: 'admin, tech.coul…',
                  icon: Icons.person_outline_rounded,
                  action: TextInputAction.next,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
                ),
                const SizedBox(height: 16),

                // Champ mot de passe
                _buildField(
                  controller: _passwordController,
                  label: 'Mot de passe',
                  hint: '••••••••',
                  icon: Icons.lock_outline_rounded,
                  action: TextInputAction.done,
                  obscure: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: Colors.white54,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  onSubmitted: (_) => _handleLogin(),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Champ requis' : null,
                ),
                const SizedBox(height: 28),

                // Bouton connexion
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    gradient: authProvider.isLoading
                        ? const LinearGradient(colors: [Color(0xFF94A3B8), Color(0xFF94A3B8)])
                        : AppGradients.heroBanner,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: authProvider.isLoading
                        ? []
                        : [
                            BoxShadow(
                              color: AppTheme.primaryColor.withValues(alpha: 0.45),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: authProvider.isLoading ? null : _handleLogin,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: authProvider.isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  'Se connecter',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Aide
                Text(
                  'En cas de perte, contactez le support informatique.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required TextInputAction action,
    bool obscure = false,
    Widget? suffixIcon,
    void Function(String)? onSubmitted,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      textInputAction: action,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.white54, size: 20),
        suffixIcon: suffixIcon,
        labelStyle: GoogleFonts.inter(color: Colors.white60, fontSize: 13),
        hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 13),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.20)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.20)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.60), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFCA5A5)),
        ),
        errorStyle: GoogleFonts.inter(color: const Color(0xFFFCA5A5), fontSize: 11),
      ),
    );
  }
}

// ── Blob décoratif ────────────────────────────────────────────────────────────
class _BlobPainter extends CustomPainter {
  final double progress;
  _BlobPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final angle = progress * 2 * math.pi;

    void drawBlob(Offset center, double radius, Color color) {
      final paint = Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);
      canvas.drawCircle(center, radius, paint);
    }

    // Blob 1 — haut gauche, tourne lentement
    drawBlob(
      Offset(
        size.width * 0.15 + math.cos(angle) * 30,
        size.height * 0.2 + math.sin(angle) * 20,
      ),
      160,
      const Color(0xFF3B82F6).withValues(alpha: 0.35),
    );

    // Blob 2 — bas droite
    drawBlob(
      Offset(
        size.width * 0.85 + math.cos(angle + math.pi) * 25,
        size.height * 0.78 + math.sin(angle + math.pi) * 25,
      ),
      180,
      const Color(0xFF7C3AED).withValues(alpha: 0.30),
    );

    // Blob 3 — centre
    drawBlob(
      Offset(
        size.width * 0.5 + math.cos(angle * 0.7) * 40,
        size.height * 0.4 + math.sin(angle * 0.7) * 30,
      ),
      100,
      const Color(0xFF1D4ED8).withValues(alpha: 0.20),
    );
  }

  @override
  bool shouldRepaint(_BlobPainter old) => old.progress != progress;
}
