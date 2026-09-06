import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/cache_service.dart';
import '../theme/app_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _cacheLoading = false;
  int _cacheSize = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final cacheSize = await CacheService.instance.getCacheSize();
    if (!mounted) return;
    setState(() => _cacheSize = cacheSize);
  }

  Future<void> _confirmClearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _buildConfirmDialog(
        title: 'Hapus Cache?',
        message:
            'Semua data cache sementara akan dihapus. Data akun dan riwayat tontonan tidak terpengaruh.',
        confirmLabel: 'Hapus',
        isDestructive: true,
      ),
    );

    if (confirmed == true) {
      await _clearCache();
    }
  }

  Future<void> _clearCache() async {
    if (_cacheLoading) return;

    setState(() => _cacheLoading = true);

    final result = await CacheService.instance.clearCache();
    final newSize = await CacheService.instance.getCacheSize();

    if (!mounted) return;

    setState(() {
      _cacheLoading = false;
      _cacheSize = newSize;
    });

    if (result.success) {
      _showSnackBar(
        'Cache berhasil dihapus (${CacheService.formatBytes(result.bytesFreed)}).',
      );
    } else {
      _showSnackBar('Gagal menghapus cache.', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: isError ? const Color(0xFF8B2E2E) : const Color(0xFF2E5A3A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.homeBg,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Penyimpanan',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.homeSubText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildCacheTile(),
                  const SizedBox(height: 36),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 28,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFDE903A), Color(0xFFC77E2E)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.settings_outlined,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Pengaturan',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCacheTile() {
    return GestureDetector(
      onTap: _cacheLoading ? null : _confirmClearCache,
      child: _buildSettingsCard(
        child: Row(
          children: [
            _buildIconBadge(Icons.delete_sweep_outlined),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hapus Cache',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _cacheLoading
                        ? 'Menghapus cache...'
                        : 'Ukuran cache: ${CacheService.formatBytes(_cacheSize)}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.homeSubText,
                    ),
                  ),
                ],
              ),
            ),
            if (_cacheLoading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFFDE903A),
                ),
              )
            else
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white70,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2018).withOpacity(0.7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
          width: 1,
        ),
      ),
      child: child,
    );
  }

  Widget _buildIconBadge(IconData icon) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFDE903A).withOpacity(0.18),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: const Color(0xFFDE903A), size: 24),
    );
  }

  Widget _buildConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    bool isDestructive = false,
  }) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2A2018),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      content: Text(
        message,
        style: GoogleFonts.poppins(
          color: AppColors.homeSubText,
          height: 1.5,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Batal',
            style: GoogleFonts.poppins(color: AppColors.homeSubText),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            confirmLabel,
            style: GoogleFonts.poppins(
              color: isDestructive ? const Color(0xFFFF3B30) : const Color(0xFFDE903A),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
