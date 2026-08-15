import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../config/theme.dart';
import '../services/pocketbase_service.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

/// Welcome Screen — Fase 2 Redesign 14 Agt 2026
///
/// Layout minimalis: logo ISWARA animasi + tagline "Berdaya, Tangguh, Berkemajuan".
/// Auto-navigate 5 detik sesuai auth state (sudah login → Dashboard, belum → Login).
/// Style senada iswara_app (logo container tanpa background putih, tagline oranye).
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  static const _welcomeDuration = Duration(milliseconds: 5000);

  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _taglineFade;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    // Master controller: 5 detik total (sesuai spec user — durasi ditambah)
    _controller = AnimationController(
      vsync: this,
      duration: _welcomeDuration,
    );

    // Logo: scale dari 0.6 → 1.0 (0-1200ms), fade 0 → 1 (0-800ms)
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.24, curve: Curves.easeOutBack),
      ),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.16, curve: Curves.easeIn),
      ),
    );

    // Tagline: fade in setelah logo (1000-2400ms)
    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.20, 0.48, curve: Curves.easeIn),
      ),
    );

    // Start animasi
    _controller.forward();

    // Auto-navigate setelah 5 detik
    Future.delayed(_welcomeDuration, _navigateBasedOnAuth);
  }

  void _navigateBasedOnAuth() {
    if (!mounted || _navigated) return;
    _navigated = true;

    final pb = PocketBaseService.instance;
    final user =
        pb.authStore.isValid ? pb.authStore.record as RecordModel? : null;

    if (user != null) {
      final userData = user.data;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            username: userData['name']?.toString() ??
                userData['email']?.toString().split('@').first ??
                'User',
            namaToko: userData['namatoko']?.toString() ?? '',
            daerah: userData['daerah']?.toString() ?? '',
            noWa: userData['nowa']?.toString() ?? '',
            userId: user.id,
            noAnggota: userData['noanggota']?.toString() ?? '',
            namaLengkap: userData['name']?.toString() ?? '',
            jabatan: userData['jabatan']?.toString() ?? '',
            sebagai: userData['sebagai']?.toString(),
            alamat: userData['alamat']?.toString() ?? '',
            sellerStatus: userData['seller_status']?.toString() ?? 'approved',
            instagram: userData['instagram']?.toString(),
            facebook: userData['facebook']?.toString(),
            tiktok: userData['tiktok']?.toString(),
            website: userData['website']?.toString(),
          ),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.white,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Spacer(),

                // Logo ISWARA — style senada iswara_app (tanpa background putih)
                FadeTransition(
                  opacity: _logoFade,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          AppTheme.iswaraLogo,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: AppTheme.primaryColor,
                              child: const Icon(
                                Icons.storefront,
                                size: 50,
                                color: Colors.white,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Tagline "Berdaya, Tangguh, Berkemajuan"
                // Style senada iswara_app: orange container + orange.shade700 text
                FadeTransition(
                  opacity: _taglineFade,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Text(
                      'Berdaya • Tangguh • Berkemajuan',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),

                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}