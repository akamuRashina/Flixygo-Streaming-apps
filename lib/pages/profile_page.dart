import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/api_models.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/watch_history_service.dart';
import '../services/profile_photo_service.dart';
import 'settings_page.dart';
import 'about_app_page.dart';
import 'login_page.dart';
import 'home_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoggedIn = false;
  String? _username;
  String? _photoUrl;
  List<WatchHistoryItem> _recent = [];
  bool _loadingRecent = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _isLoggedIn = await AuthService.instance.isLoggedIn();
    _username = await AuthService.instance.getUsername();
    _photoUrl = await ProfilePhotoService.instance.getPhotoUrl();
    if (mounted) setState(() {});

    if (_isLoggedIn) {
      try {
        final history = await WatchHistoryService.instance.list();
        if (!mounted) return;
        setState(() {
          _recent = history.take(6).toList();
          _loadingRecent = false;
        });
      } catch (_) {
        if (mounted) setState(() => _loadingRecent = false);
      }
    } else {
      setState(() => _loadingRecent = false);
    }
  }

  Future<void> _changePhoto() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2A2018), Color(0xFF1A1209)],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Color(0xFFDE903A)),
              title: Text('Pilih Foto', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(context, 'pick'),
            ),
            if (_photoUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF3B30)),
                title: Text('Hapus Foto', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
          ],
        ),
      ),
    );

    if (choice == 'pick') {
      try {
        final url = await ProfilePhotoService.instance.pickAndSavePhoto();
        if (url != null && mounted) setState(() => _photoUrl = url);
      } catch (e) {
        if (!mounted) return;
        final message = e is ApiException ? e.message : 'Gagal mengunggah foto.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message, style: GoogleFonts.poppins()), backgroundColor: const Color(0xFF8B2E2E)),
        );
      }
    } else if (choice == 'remove') {
      try {
        await ProfilePhotoService.instance.clearPhoto();
        if (mounted) setState(() => _photoUrl = null);
      } catch (e) {
        if (!mounted) return;
        final message = e is ApiException ? e.message : 'Gagal menghapus foto.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message, style: GoogleFonts.poppins()), backgroundColor: const Color(0xFF8B2E2E)),
        );
      }
    }
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  void _showHelpBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2A2018), Color(0xFF1A1209)],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFDE903A).withOpacity(0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.headset_mic_outlined, color: Color(0xFFDE903A), size: 24),
                ),
                const SizedBox(width: 14),
                Text('Bantuan dan Layanan', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
              ],
            ),
            const SizedBox(height: 24),
            _buildHelpOption(
              context: context,
              icon: Icons.email_outlined,
              title: 'Hubungi via Email',
              subtitle: 'Kirim pertanyaan ke email kami',
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Email: Digitalaegis12@gmail.com', style: GoogleFonts.poppins()),
                    duration: const Duration(seconds: 3),
                    backgroundColor: const Color(0xFF2A1C10),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildHelpOption(
              context: context,
              icon: Icons.bug_report_outlined,
              title: 'Laporkan Masalah',
              subtitle: 'Bantu kami meningkatkan aplikasi',
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Kirim laporan ke Digitalaegis12@gmail.com', style: GoogleFonts.poppins()),
                    duration: const Duration(seconds: 3),
                    backgroundColor: const Color(0xFF2A1C10),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFDE903A).withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(icon, color: const Color(0xFFDE903A), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.white.withOpacity(0.6))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.5), size: 20),
          ],
        ),
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
            _buildTopHeaderCard(context),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Baru saja di tonton', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(height: 12),
                  _buildRecentlyWatchedSection(),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildMenuItem(
                    icon: Icons.settings_outlined,
                    label: 'Pengaturan',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
                  ),
                  const SizedBox(height: 14),
                  _buildMenuItem(
                    icon: Icons.headset_mic_outlined,
                    label: 'Bantuan dan Layanan',
                    onTap: () => _showHelpBottomSheet(context),
                  ),
                  const SizedBox(height: 14),
                  _buildMenuItem(
                    icon: Icons.help_outline_rounded,
                    label: 'Tentang aplikasi',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutAppPage())),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildLogoutItem(onTap: _isLoggedIn ? _logout : () => Navigator.pop(context)),
            ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeaderCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 16, bottom: 32, left: 20, right: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFDE903A), Color(0xFFC77E2E)]),
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
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _isLoggedIn ? _changePhoto : null,
            child: Stack(
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFF3EAD8),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))],
                    image: _photoUrl != null
                        ? DecorationImage(image: NetworkImage(_photoUrl!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _photoUrl == null
                      ? const Icon(Icons.person, size: 60, color: Color(0xFF8B6240))
                      : null,
                ),
                if (_isLoggedIn)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDE903A),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_rounded, size: 15, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _isLoggedIn ? (_username ?? 'Pengguna') : 'Tamu',
            style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          if (!_isLoggedIn) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
                _load();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(20)),
                child: Text('Masuk / Daftar', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentlyWatchedSection() {
    if (!_isLoggedIn) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2018).withOpacity(0.7),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        child: Text(
          'Masuk untuk melihat riwayat tontonanmu.',
          style: GoogleFonts.poppins(color: Colors.white54, fontSize: 13),
        ),
      );
    }

    if (_loadingRecent) {
      return const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(color: AppColors.homeTextCream)));
    }

    if (_recent.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2018).withOpacity(0.7),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        child: Text('Belum ada tontonan.', style: GoogleFonts.poppins(color: Colors.white54, fontSize: 13)),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2018).withOpacity(0.7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: _recent
              .map((item) => Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: _buildMovieCard(title: item.title, imageUrl: item.poster),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildMovieCard({required String title, required String imageUrl}) {
    return SizedBox(
      width: 115,
      height: 155,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF3B2A1B), Color(0xFF1B120A)]),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.85)]),
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Text(
                title,
                style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.white, height: 1.2),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2018).withOpacity(0.7),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.0),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white))),
            const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutItem({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF2E1813).withOpacity(0.8),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFFFF3B30).withOpacity(0.3), width: 1.0),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: const Color(0xFFFF3B30).withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.logout_rounded, color: Color(0xFFFF3B30), size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                _isLoggedIn ? 'Keluar' : 'Tutup',
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 24),
          ],
        ),
      ),
    );
  }
}
