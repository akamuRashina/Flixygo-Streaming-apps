import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/app_lock_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';

class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  bool _lockEnabled = false;
  bool _isLocked = false;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initLockState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initLockState() async {
    final enabled = await SettingsService.instance.isLockEnabled();
    if (!mounted) return;

    setState(() {
      _lockEnabled = enabled;
      _isLocked = enabled;
    });

    if (enabled) {
      await _authenticate();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_lockEnabled) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (mounted) {
        setState(() => _isLocked = true);
      }
    } else if (state == AppLifecycleState.resumed && _isLocked) {
      _authenticate();
    }
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;

    setState(() => _isAuthenticating = true);

    final success = await AppLockService.instance.authenticate();

    if (!mounted) return;

    setState(() {
      _isAuthenticating = false;
      if (success) _isLocked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_lockEnabled && _isLocked)
          Positioned.fill(
            child: _LockOverlay(
              isAuthenticating: _isAuthenticating,
              onUnlock: _authenticate,
            ),
          ),
      ],
    );
  }
}

class _LockOverlay extends StatelessWidget {
  const _LockOverlay({
    required this.isAuthenticating,
    required this.onUnlock,
  });

  final bool isAuthenticating;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.homeBg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFDE903A), Color(0xFFC77E2E)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFDE903A).withOpacity(0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  color: Colors.white,
                  size: 42,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'FlixyGo Terkunci',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.homeTextCream,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Gunakan sidik jari, PIN, atau kata sandi perangkat untuk membuka aplikasi.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.homeSubText,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isAuthenticating ? null : onUnlock,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDE903A),
                    disabledBackgroundColor: const Color(0xFFDE903A).withOpacity(0.5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: isAuthenticating
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Buka Kunci',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
