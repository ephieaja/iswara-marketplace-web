import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../config/theme.dart';
import '../../config/pocketbase_config.dart';
import '../../services/pocketbase_service.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final pb = PocketBaseService.instance;

      // Fase 1: Login pakai `users_auth` collection (bukan `users` legacy).
      final authData = await pb
          .collection(PocketBaseConfig.usersAuthCollection)
          .authWithPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );

      final user = authData.record;
      final userData = user.data;

      if (!mounted) return;

      // Cek apakah user ini juga seller (SellersMarketplace)
      String namaToko = '';
      String daerah = '';
      String sellerStatus = 'approved';
      String? instagram;
      String? facebook;
      String? tiktok;
      String? website;
      try {
        final sellerResult = await pb
            .collection(PocketBaseConfig.sellersMarketplaceCollection)
            .getList(
              filter: 'user = "${user.id}"',
              perPage: 1,
            );
        if (sellerResult.items.isNotEmpty) {
          final sellerData = sellerResult.items.first.data;
          namaToko = sellerData['namatoko']?.toString() ?? '';
          daerah = sellerData['daerah_toko']?.toString() ??
              sellerData['daerah']?.toString() ??
              '';
          sellerStatus = sellerData['status_verifikasi']?.toString() ?? 'pending';
          instagram = sellerData['instagram']?.toString();
          facebook = sellerData['facebook']?.toString();
          tiktok = sellerData['tiktok']?.toString();
          website = sellerData['website']?.toString();
        }
      } catch (e) {
        debugPrint('Error fetch SellersMarketplace: $e');
      }

      // Ambil data user dari record
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            username: userData['name']?.toString() ??
                userData['email']?.toString().split('@').first ??
                'User',
            namaToko: namaToko,
            daerah: daerah,
            // Fase 1: users_auth pakai `phone` (bukan `nowa` di legacy)
            noWa: userData['phone']?.toString() ??
                userData['nowa']?.toString() ??
                '',
            userId: user.id,
            noAnggota: '', // No konsep noanggota di users_auth marketplace
            namaLengkap: userData['name']?.toString() ?? '',
            jabatan: '',
            sebagai: null,
            alamat: userData['alamat']?.toString() ?? '',
            sellerStatus: sellerStatus,
            instagram: instagram,
            facebook: facebook,
            tiktok: tiktok,
            website: website,
          ),
        ),
        (route) => false,
      );
    } on ClientException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      String errorMessage;
      final response = e.response;

      if (response != null && response.containsKey('message')) {
        errorMessage = response['message'].toString();
      } else if (e.statusCode == 400) {
        errorMessage = 'Email atau password salah';
      } else if (e.statusCode == 404) {
        errorMessage = 'Akun tidak ditemukan';
      } else {
        errorMessage = 'Login gagal. Coba lagi.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Masuk'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.storefront,
                    size: 50,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Selamat Datang',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Masuk dengan email dan password\nakun ISWARA Anda',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'Masukkan email Anda',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email wajib diisi';
                    }
                    if (!value.contains('@')) {
                      return 'Format email tidak valid';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Masukkan password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password wajib diisi';
                    }
                    if (value.length < 6) {
                      return 'Password minimal 6 karakter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'MASUK',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Belum punya akun? Daftar melalui menu Pemilik Usaha.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
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
      ),
    );
  }
}
