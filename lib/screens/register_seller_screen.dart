import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../config/theme.dart';
import '../../services/pocketbase_service.dart';

class RegisterSellerScreen extends StatefulWidget {
  const RegisterSellerScreen({super.key});

  @override
  State<RegisterSellerScreen> createState() => _RegisterSellerScreenState();
}

class _RegisterSellerScreenState extends State<RegisterSellerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _alamatController = TextEditingController();
  final _noWaController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _namaTokoController = TextEditingController();
  final _namaOrganisasiController = TextEditingController();
  final _noAnggotaController = TextEditingController();

  bool _isLoading = false;
  bool _isAcceptedTerms = false;
  String _selectedOrganisasi = 'Muhammadiyah';
  String _selectedTingkat = 'Anggota';
  String _selectedDaerah = 'Surabaya';

  // Organization options for membership
  final List<String> _organisasiList = [
    'Muhammadiyah',
    'Aisyiyah',
    'Pemuda Muhammadiyah',
    'Nasyiatul Aisyiyah',
    'IMM',
    'IPM',
    'Tapak Suci',
  ];

  // Tingkat/Package options
  final List<String> _tingkatList = [
    'Pimpinan Wilayah',
    'Pimpinan Cabang',
    'Pimpinan Ranting',
    'Anggota',
  ];

  final List<String> _daerahList = [
    'Surabaya',
    'Sidoarjo',
    'Kabupaten Malang',
    'Kota Malang',
    'Gresik',
    'Pasuruan',
    'Mojokerto',
    'Jember',
    'Banyuwangi',
    'Bondowoso',
    'Situbondo',
    'Probolinggo',
    'Lumajang',
    'Kediri',
    'Jombang',
    'Madiun',
    'Ngawi',
    'Bojonegoro',
    'Lamongan',
    'Tuban',
    'Bangkalan',
    'Sampang',
    'Pamekasan',
    'Sumenep',
    'Luar Jawa Timur',
  ];

  @override
  void dispose() {
    _namaController.dispose();
    _alamatController.dispose();
    _noWaController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _namaTokoController.dispose();
    _namaOrganisasiController.dispose();
    _noAnggotaController.dispose();
    _namaOrganisasiController.dispose();
    super.dispose();
  }

  void _daftar() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isAcceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anda harus menyetujui syarat dan ketentuan'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final pb = PocketBaseService.instance;

      // Create user in PocketBase
      final userData = {
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'passwordConfirm': _passwordController.text,
        'name': _namaController.text.trim(),
        'NamaToko': _namaTokoController.text.trim(),
        'Alamat': _alamatController.text.trim(),
        'Daerah': _selectedDaerah,
        'NoWa': _noWaController.text.trim(),
        'Organisasi': _selectedOrganisasi,
        'Tingkat': _selectedTingkat,
        'Majlis': _namaOrganisasiController.text.trim(),
        'NoAnggota': _noAnggotaController.text.trim(),
      };

      await pb.collection('users').create(body: userData);

      // Auto login after registration
      await pb.collection('users').authWithPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;

      setState(() => _isLoading = false);

      // Show success dialog
      _showSuccessDialog();

    } on ClientException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      String msg = 'Terjadi kesalahan';
      final response = e.response;
      if (response != null && response['message'] != null) {
        msg = response['message'].toString();
      } else if (e.statusCode == 400) {
        msg = 'Email sudah terdaftar atau data tidak valid';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                size: 64,
                color: Colors.green.shade600,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Pendaftaran Berhasil!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified, color: Colors.green.shade700, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'AKUN AKTIF',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.check, color: Colors.green.shade700, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Akun Anda langsung aktif!',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Silakan login langsung dengan email dan password yang sudah didaftarkan.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('LOGIN SEKARANG'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Seller'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryColor.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.store, size: 48, color: Colors.white),
                    const SizedBox(height: 12),
                    const Text(
                      'Pendaftaran Seller',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Bergabung dengan Marketplace Aisyiyah\ndan menjadi seller produk Islami',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Info Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Hanya anggota Muhammadiyah, Aisyiyah, dan ORTOM yang dapat mendaftar sebagai seller.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Section: Data Diri
              _buildSectionHeader('📝 Data Diri', Icons.person),
              const SizedBox(height: 16),

              // Nama Lengkap
              TextFormField(
                controller: _namaController,
                decoration: const InputDecoration(
                  labelText: 'Nama Lengkap *',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 16),

              // Alamat
              TextFormField(
                controller: _alamatController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Alamat Lengkap *',
                  prefixIcon: Icon(Icons.location_on),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 16),

              // No WhatsApp
              TextFormField(
                controller: _noWaController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'No. WhatsApp *',
                  prefixIcon: Icon(Icons.chat),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 24),

              // Section: Keanggotaan Persyarikatan
              _buildSectionHeader('🏛️ Keanggotaan Persyarikatan', Icons.groups),
              const SizedBox(height: 16),

              // Organisasi Dropdown
              DropdownButtonFormField<String>(
                value: _selectedOrganisasi,
                decoration: const InputDecoration(
                  labelText: 'Organisasi *',
                  prefixIcon: Icon(Icons.account_balance),
                  border: OutlineInputBorder(),
                ),
                items: _organisasiList.map((org) {
                  return DropdownMenuItem(value: org, child: Text(org));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedOrganisasi = value ?? 'Muhammadiyah';
                    _namaOrganisasiController.clear();
                  });
                },
              ),
              const SizedBox(height: 16),

              // Tingkat Dropdown
              DropdownButtonFormField<String>(
                value: _selectedTingkat,
                decoration: const InputDecoration(
                  labelText: 'Tingkat *',
                  prefixIcon: Icon(Icons.layers),
                  border: OutlineInputBorder(),
                ),
                items: _tingkatList.map((tingkat) {
                  return DropdownMenuItem(value: tingkat, child: Text(tingkat));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedTingkat = value ?? 'Anggota';
                  });
                },
              ),
              const SizedBox(height: 16),

              // Majlis (text input)
              TextFormField(
                controller: _namaOrganisasiController,
                decoration: const InputDecoration(
                  labelText: 'Majlis *',
                  hintText: 'Contoh: Majelis Diktilitbang',
                  prefixIcon: Icon(Icons.business),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 16),

              // No. Anggota (optional)
              TextFormField(
                controller: _noAnggotaController,
                decoration: const InputDecoration(
                  labelText: 'No. Anggota',
                  hintText: 'Bisa dikosongkan jika lupa',
                  prefixIcon: Icon(Icons.tag),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Daerah Dropdown
              DropdownButtonFormField<String>(
                value: _selectedDaerah,
                decoration: const InputDecoration(
                  labelText: 'Daerah *',
                  prefixIcon: Icon(Icons.location_city),
                  border: OutlineInputBorder(),
                ),
                items: _daerahList.map((daerah) {
                  return DropdownMenuItem(value: daerah, child: Text(daerah));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedDaerah = value ?? 'Surabaya';
                  });
                },
              ),
              const SizedBox(height: 24),

              // Section: Akun & Toko
              _buildSectionHeader('🏪 Akun & Toko', Icons.store),
              const SizedBox(height: 16),

              // Email
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email *',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v?.isEmpty ?? true) return 'Wajib diisi';
                  if (!v!.contains('@')) return 'Email tidak valid';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Password
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password *',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                  helperText: 'Minimal 6 karakter',
                ),
                validator: (v) {
                  if (v?.isEmpty ?? true) return 'Wajib diisi';
                  if (v!.length < 6) return 'Min. 6 karakter';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Nama Toko
              TextFormField(
                controller: _namaTokoController,
                decoration: const InputDecoration(
                  labelText: 'Nama Toko/Usaha *',
                  prefixIcon: Icon(Icons.store),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 24),

              // Terms Checkbox
              CheckboxListTile(
                value: _isAcceptedTerms,
                onChanged: (value) {
                  setState(() => _isAcceptedTerms = value ?? false);
                },
                title: const Text(
                  'Saya menyatakan bahwa saya adalah anggota aktif Muhammadiyah, Aisyiyah, atau ORTOM dan menyetujui Syarat & Ketentuan Marketplace Aisyiyah Jawa Timur.',
                  style: TextStyle(fontSize: 12),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 24),

              // Button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _daftar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'DAFTAR SEKARANG',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Info after registration
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule, color: Colors.grey.shade600, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Setelah daftar, akun Anda akan diverifikasi oleh admin dalam 1x24 jam.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
