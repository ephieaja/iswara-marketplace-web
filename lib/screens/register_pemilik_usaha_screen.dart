import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../config/theme.dart';
import '../../services/pocketbase_service.dart';
import 'dashboard_screen.dart';

class RegisterPemilikUsahaScreen extends StatefulWidget {
  const RegisterPemilikUsahaScreen({super.key});

  @override
  State<RegisterPemilikUsahaScreen> createState() => _RegisterPemilikUsahaScreenState();
}

class _RegisterPemilikUsahaScreenState extends State<RegisterPemilikUsahaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _noAnggotaController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _namaTokoController = TextEditingController();
  final _noWaController = TextEditingController();

  bool _isLoading = false;
  String _statusText = '';

  @override
  void dispose() {
    _namaController.dispose();
    _noAnggotaController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _namaTokoController.dispose();
    _noWaController.dispose();
    super.dispose();
  }

  void _daftar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _statusText = 'Mendaftarkan...';
    });

    try {
      final pb = PocketBaseService.instance;
      final email = _emailController.text.trim();

      // Check if email already exists by trying to auth
      try {
        await pb.collection('users').authWithPassword(email, 'check_existing_user');
      } on ClientException {
        // If auth fails with invalid credentials, user might exist
        // We need to check via list filter
      }

      // Create user in PocketBase
      final userData = await pb.collection('users').create(
        body: {
          'email': email,
          'password': _passwordController.text,
          'passwordConfirm': _passwordController.text,
          'name': _namaController.text.trim(),
          'emailVisibility': true,
        },
      );

      // Now auth with the new credentials
      final authData = await pb.collection('users').authWithPassword(
        email,
        _passwordController.text,
      );

      // Save additional data to pemilik_usaha collection
      await pb.collection('pemilik_usaha').create(
        body: {
          'userId': authData.record.id,
          'email': email,
          'namaToko': _namaTokoController.text.trim(),
          'nama': _namaController.text.trim(),
          'noWa': _noWaController.text.trim(),
          'noAnggota': _noAnggotaController.text.trim(),
          'daerah': '',
          'alamat': '',
        },
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _statusText = 'Berhasil!';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pendaftaran berhasil!'), backgroundColor: Colors.green),
      );

      // Navigate to dashboard
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            username: _namaController.text.trim(),
            namaToko: _namaTokoController.text,
            daerah: '',
            noWa: _noWaController.text,
            userId: authData.record.id,
            noAnggota: _noAnggotaController.text,
            namaLengkap: _namaController.text,
            jabatan: '',
            alamat: '',
          ),
        ),
        (route) => false,
      );

    } on ClientException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusText = 'Error';
      });

      String msg = 'Terjadi kesalahan';
      if (e.response != null && e.response['message'] != null) {
        final pbMsg = e.response['message'].toString().toLowerCase();
        if (pbMsg.contains('email')) {
          msg = 'Email sudah terdaftar';
        } else {
          msg = pbMsg;
        }
      } else if (e.statusCode == 400) {
        msg = 'Data tidak valid';
      } else if (e.statusCode == 404) {
        msg = 'Layanan tidak ditemukan';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusText = 'Error: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Pemilik Usaha'),
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
              const Icon(Icons.store, size: 60, color: AppTheme.primaryColor),
              const SizedBox(height: 16),
              const Text(
                'Pendaftaran Pemilik Usaha',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Isi form di bawah untuk mendaftar',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              // Nama
              TextFormField(
                controller: _namaController,
                decoration: const InputDecoration(labelText: 'Nama Lengkap', prefixIcon: Icon(Icons.person)),
                validator: (v) => v?.isEmpty ?? true ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 16),

              // No Anggota
              TextFormField(
                controller: _noAnggotaController,
                decoration: const InputDecoration(labelText: 'No. Anggota (opsional)', prefixIcon: Icon(Icons.badge)),
              ),
              const SizedBox(height: 16),

              // Email
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email)),
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
                decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock)),
                validator: (v) {
                  if (v?.isEmpty ?? true) return 'Wajib diisi';
                  if (v!.length < 8) return 'Min. 8 karakter';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Nama Toko
              TextFormField(
                controller: _namaTokoController,
                decoration: const InputDecoration(labelText: 'Nama Toko/Usaha', prefixIcon: Icon(Icons.store)),
                validator: (v) => v?.isEmpty ?? true ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 16),

              // No WA
              TextFormField(
                controller: _noWaController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'No. WhatsApp', prefixIcon: Icon(Icons.phone)),
                validator: (v) => v?.isEmpty ?? true ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 30),

              // Status
              if (_statusText.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_statusText, textAlign: TextAlign.center),
                ),
                const SizedBox(height: 16),
              ],

              // Button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _daftar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('DAFTAR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
