import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoginMode = true;
  bool _isSubmitting = false;
  bool _isCheckingSession = true;
  String? _errorMessage;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.forward();
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    final loggedIn = await AuthService.instance.isLoggedIn();
    if (!mounted) return;
    if (loggedIn) {
      _navigateToHome();
      return;
    }
    setState(() => _isCheckingSession = false);
  }

  @override
  void dispose() {
    _animController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomePage(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Username dan password wajib diisi.');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = 'Password minimal 6 karakter.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      if (_isLoginMode) {
        await AuthService.instance.login(username: username, password: password);
      } else {
        await AuthService.instance.register(username: username, password: password);
      }
      if (!mounted) return;
      _navigateToHome();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Terjadi kesalahan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingSession) {
      return Scaffold(
        backgroundColor: AppColors.loginBg,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.loginBg,
      body: Stack(
        children: [
          // ── LIQUID GLASS AMBIENT GLOW ORBS IN BACKGROUND ──
          Positioned(
            top: -40,
            right: -50,
            child: Container(
              width: 230,
              height: 230,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF3EBA7).withOpacity(0.18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF3EBA7).withOpacity(0.25),
                    blurRadius: 90,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.loginDarkTop.withOpacity(0.25),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.loginDarkTop.withOpacity(0.3),
                    blurRadius: 90,
                    spreadRadius: 35,
                  ),
                ],
              ),
            ),
          ),

          // ── FIXED, NON-SCROLLABLE MAIN CONTENT ──
          SafeArea(
            child: Column(
              children: [
                // ── TOP GIANT ROUND DARK CHOCOLATE SHAPE (fills remaining space) ──
                Expanded(
                  child: Stack(
                    children: [
                      ClipPath(
                        clipper: HeaderCircleClipper(),
                        child: Container(
                          width: double.infinity,
                          height: double.infinity,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0xFF432A12),
                                AppColors.loginDarkTop,
                                Color(0xFF5A3B1B),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: AppColors.loginLogoYellow,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.25),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/images/icon.png',
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(
                                        Icons.play_circle_fill_rounded,
                                        size: 62,
                                        color: AppColors.loginDarkTop,
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'FlixyGo',
                                style: GoogleFonts.poppins(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.loginTextLight,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'light app for stream film,\nanime, and kdrama',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.loginTextLight,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── FORM SECTION (natural height — header above flexes to fill the rest) ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 14),

                      Text(
                        'Username',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.loginTextDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildGlassTextField(
                        controller: _usernameController,
                        hintText: 'Masukkan username',
                      ),

                      const SizedBox(height: 14),

                      Text(
                        'Password',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.loginTextDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildGlassTextField(
                        controller: _passwordController,
                        hintText: 'Minimal 6 karakter',
                        isPassword: true,
                      ),

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B2E2E).withOpacity(0.85),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 28),

                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              label: 'Log in',
                              isActive: _isLoginMode,
                              onTap: () {
                                if (!_isLoginMode) {
                                  setState(() {
                                    _isLoginMode = true;
                                    _errorMessage = null;
                                  });
                                } else {
                                  _submit();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildActionButton(
                              label: 'Sign Up',
                              isActive: !_isLoginMode,
                              onTap: () {
                                if (_isLoginMode) {
                                  setState(() {
                                    _isLoginMode = false;
                                    _errorMessage = null;
                                  });
                                } else {
                                  _submit();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      Center(
                        child: _isSubmitting
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: CircularProgressIndicator(
                                  color: AppColors.loginDarkTop,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                _isLoginMode
                                    ? 'Tekan "Log in" lagi untuk masuk'
                                    : 'Tekan "Sign Up" lagi untuk daftar',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppColors.loginTextDark.withOpacity(0.6),
                                ),
                              ),
                      ),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassTextField({
    required TextEditingController controller,
    required String hintText,
    bool isPassword = false,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.loginFieldBg.withOpacity(0.9),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword,
            enabled: !_isSubmitting,
            style: GoogleFonts.poppins(
              color: AppColors.loginTextDark,
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: GoogleFonts.poppins(
                color: AppColors.loginTextDark.withOpacity(0.45),
                fontSize: 14,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _isSubmitting ? null : onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isActive
                    ? [
                        AppColors.loginButtonActive,
                        AppColors.loginButtonBg,
                      ]
                    : [
                        AppColors.loginButtonBg.withOpacity(0.75),
                        AppColors.loginFieldBg.withOpacity(0.7),
                      ],
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isActive
                    ? Colors.white.withOpacity(0.4)
                    : Colors.white.withOpacity(0.2),
                width: isActive ? 1.5 : 1.0,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.22),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Center(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isActive
                      ? AppColors.loginTextLight
                      : AppColors.loginTextDark.withOpacity(0.8),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── GIANT ROUND CIRCLE CLIPPER FOR TOP SECTION ──
class HeaderCircleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height * 0.65);

    final controlPoint = Offset(size.width * 0.5, size.height * 1.05);
    final endPoint = Offset(size.width, size.height * 0.65);

    path.quadraticBezierTo(
      controlPoint.dx,
      controlPoint.dy,
      endPoint.dx,
      endPoint.dy,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
