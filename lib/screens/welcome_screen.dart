import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../providers/cart_provider.dart';
import '../utils/share_helper.dart';
import '../services/pocketbase_service.dart';
import 'register_seller_screen.dart';
import 'katalog_screen.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import 'cart_screen.dart';
import 'orders_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Top Bar with Cart, Orders & Share
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Orders Button
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const OrdersScreen()),
                      );
                    },
                    icon: const Icon(Icons.receipt_long, color: AppTheme.primaryColor),
                    label: const Text(
                      'Pesanan Saya',
                      style: TextStyle(color: AppTheme.primaryColor, fontSize: 12),
                    ),
                  ),
                  // Right side buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Share Button
                      TextButton.icon(
                        onPressed: () => ShareHelper.shareApp(),
                        icon: const Icon(Icons.share, color: AppTheme.primaryColor, size: 18),
                        label: const Text(
                          'Bagikan',
                          style: TextStyle(color: AppTheme.primaryColor, fontSize: 12),
                        ),
                      ),
                      // Cart Button
                      Consumer<CartProvider>(
                        builder: (context, cart, child) {
                          return Stack(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.shopping_cart, color: AppTheme.primaryColor),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const CartScreen()),
                                  );
                                },
                              ),
                              if (cart.itemCount > 0)
                                Positioned(
                                  right: 4,
                                  top: 4,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      cart.itemCount.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Spacer(),
              // Logo & Nama
              _buildLogoSection(),
              const SizedBox(height: 32),
              // Welcome Text
              _buildWelcomeText(),
              const Spacer(),
              // Tombol MASUK (Auto Login)
              _buildMasukButton(),
              const SizedBox(height: 12),
              // Pengunjung Button
              _buildVisitorButton(context),
              const SizedBox(height: 12),
              // Pemilik Usaha Button
              _buildPemilikUsahaButton(context),
              const SizedBox(height: 32),
              // Footer - Pemilik Aplikasi
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoSection() {
    return Column(
      children: [
        // Logo
        Container(
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
              AppTheme.katalogLogo,
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
        const SizedBox(height: 16),
        // Nama Organisasi (lebih kecil)
        const Text(
          'Marketplace Aisyiyah Jawa Timur',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
            letterSpacing: 0.5,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        // Tagline with bullet points
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Text(
            'Tangguh • Berdaya • Berkemajuan',
            style: TextStyle(
              fontSize: 11,
              color: Colors.orange.shade700,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeText() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.handshake,
            size: 20,
            color: Colors.green.shade700,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Marketplace Keluarga\nMuhammadiyah',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.green.shade800,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMasukButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 3,
        ),
        icon: const Icon(Icons.login, size: 20),
        label: const Text(
          'MASUK',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildVisitorButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const KatalogScreen()),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        icon: const Icon(Icons.visibility, size: 18),
        label: const Text(
          'PENGUNJUNG',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildPemilikUsahaButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: () {
          _showPemilikUsahaDialog(context);
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.primaryColor,
          side: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.store, size: 18),
        label: const Text(
          'SELLER',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  void _autoLogin() async {
    final pb = PocketBaseService.instance;

    if (!pb.authStore.isValid) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan daftar terlebih dahulu'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = pb.authStore.record as RecordModel?;

      if (user == null) {
        throw Exception('User tidak ditemukan');
      }

      final userData = user.data;

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            username: userData['name']?.toString() ?? userData['email']?.toString().split('@').first ?? 'User',
            namaToko: userData['NamaToko']?.toString() ?? '',
            daerah: userData['Daerah']?.toString() ?? '',
            noWa: userData['NoWa']?.toString() ?? '',
            userId: user.id,
            noAnggota: userData['NoAnggota']?.toString() ?? '',
            namaLengkap: userData['name']?.toString() ?? '',
            jabatan: userData['jabatan']?.toString() ?? '',
            sebagai: userData['sebagai']?.toString(),
            alamat: userData['Alamat']?.toString() ?? '',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showPemilikUsahaDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Icon(
              Icons.storefront,
              size: 48,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: 16),
            const Text(
              'Pemilik Usaha',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // Tombol Daftar Seller
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterSellerScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.app_registration),
                label: const Text('DAFTAR SELLER'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Logo ISWARA (small, beside text)
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: const DecorationImage(
                image: AssetImage(AppTheme.iswaraLogo),
                fit: BoxFit.cover,
              ),
            ),
            child: Image.asset(
              AppTheme.iswaraLogo,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.storefront,
                  color: AppTheme.primaryColor,
                  size: 20,
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ikatan Saudagar dan Wirausaha Aisyiyah',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor.withOpacity(0.7),
                    letterSpacing: 0.3,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'PW Jawa Timur',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor.withOpacity(0.7),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
