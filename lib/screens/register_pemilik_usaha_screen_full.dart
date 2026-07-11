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
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _konfirmasiPasswordController = TextEditingController();
  final _namaTokoController = TextEditingController();
  final _jenisUsahaController = TextEditingController();
  final _lokasiUsahaController = TextEditingController();
  final _noWaController = TextEditingController();

  bool _isLoading = false;
  bool _isSearching = false;
  bool _isFound = false;

  // Track which fields are being edited
  Map<String, bool> _editingFields = {};

  // Data anggota yang ditemukan
  Map<String, dynamic>? _anggotaData;
  String? _anggotaDocId;

  @override
  void dispose() {
    _namaController.dispose();
    _noAnggotaController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _konfirmasiPasswordController.dispose();
    _namaTokoController.dispose();
    _jenisUsahaController.dispose();
    _lokasiUsahaController.dispose();
    _noWaController.dispose();
    super.dispose();
  }

  void _toggleEdit(String field) {
    setState(() {
      _editingFields[field] = !(_editingFields[field] ?? false);
    });
  }

  void _cariAnggota() async {
    final nama = _namaController.text.trim();
    final noAnggota = _noAnggotaController.text.trim();

    if (nama.isEmpty && noAnggota.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan Nama Lengkap atau No. Anggota')),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _isFound = false;
      _anggotaData = null;
      _editingFields = {};
    });

    try {
      final pb = PocketBaseService.instance;

      // Build filter
      String filter = '';
      if (noAnggota.isNotEmpty) {
        filter = 'noAnggota = "$noAnggota"';
      } else {
        filter = 'namaLengkap = "$nama"';
      }

      final result = await pb.collection('anggota_iswara').getList(
        filter: filter,
        perPage: 1,
      );

      if (!mounted) return;

      if (result.items.isEmpty) {
        setState(() {
          _isSearching = false;
          _isFound = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data anggota tidak ditemukan. Pastikan Nama atau No. Anggota benar.'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        final record = result.items.first;
        final data = record.data;
        setState(() {
          _isSearching = false;
          _isFound = true;
          _anggotaData = data;
          _anggotaDocId = record.id;
          // Pre-fill data dari anggota
          _namaController.text = data['namaLengkap'] ?? '';
          _noWaController.text = data['noWa'] ?? '';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data anggota ditemukan! Lengkapi data di bawah.'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSearching = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _daftar() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isFound || _anggotaData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cari data anggota terlebih dahulu')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final pb = PocketBaseService.instance;
      final email = _emailController.text.trim();

      // Create user in PocketBase
      final newUser = await pb.collection('users').create(
        body: {
          'email': email,
          'password': _passwordController.text,
          'passwordConfirm': _passwordController.text,
          'name': _namaController.text.trim(),
          'username': _usernameController.text.trim(),
          'emailVisibility': true,
        },
      );

      // Now auth with the new credentials
      final authData = await pb.collection('users').authWithPassword(
        email,
        _passwordController.text,
      );

      // Update data anggota dengan data terbaru dari form
      if (_anggotaDocId != null) {
        await pb.collection('anggota_iswara').update(
          _anggotaDocId!,
          body: {
            'namaLengkap': _namaController.text.trim(),
            'noWa': _noWaController.text.trim(),
          },
        );
      }

      // Simpan data pemilik usaha ke koleksi pemilik_usaha
      await pb.collection('pemilik_usaha').create(
        body: {
          'userId': authData.record.id,
          'anggotaDocId': _anggotaDocId,
          'noAnggota': _anggotaData!['noAnggota'],
          'username': _usernameController.text.trim(),
          'email': email,
          'namaToko': _namaTokoController.text.trim(),
          'jenisUsaha': _jenisUsahaController.text.trim(),
          'lokasiUsaha': _lokasiUsahaController.text.trim(),
          'noWa': _noWaController.text.trim(),
          'daerah': _anggotaData!['daerah'] ?? '',
          'alamat': _anggotaData!['alamat'] ?? '',
        },
      );

      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pendaftaran berhasil!'),
          backgroundColor: AppTheme.successColor,
        ),
      );

      // Langsung login dan ke dashboard
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            username: _usernameController.text.trim(),
            namaToko: _namaTokoController.text.trim(),
            daerah: _anggotaData!['daerah'] ?? '',
            noWa: _noWaController.text.trim(),
            userId: authData.record.id,
            noAnggota: _anggotaData!['noAnggota'] ?? '',
            namaLengkap: _namaController.text.trim(),
            jabatan: _anggotaData!['jabatan'] ?? '',
            sebagai: _anggotaData!['sebagai'],
            alamat: _anggotaData!['alamat'] ?? '',
          ),
        ),
        (route) => false, // Remove all previous routes
      );

    } on ClientException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      String errorMessage = 'Terjadi kesalahan';
      if (e.response != null && e.response['message'] != null) {
        final pbMsg = e.response['message'].toString().toLowerCase();
        if (pbMsg.contains('email')) {
          errorMessage = 'Email sudah terdaftar';
        } else {
          errorMessage = pbMsg;
        }
      } else if (e.statusCode == 400) {
        errorMessage = 'Data tidak valid';
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
        title: const Text('Daftar Pemilik Usaha'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title
                _buildHeader(),
                const SizedBox(height: 24),

                // Section 1: Cari Data Anggota
                _buildCariAnggotaSection(),
                const SizedBox(height: 24),

                // Section 2: Data Anggota (jika ditemukan)
                if (_isFound && _anggotaData != null) ...[
                  _buildAnggotaSection(),
                  const SizedBox(height: 24),
                  _buildAkunSection(),
                  const SizedBox(height: 24),
                  _buildUsahaSection(),
                  const SizedBox(height: 32),
                  _buildSubmitButton(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.1),
            AppTheme.primaryLight.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.store,
            size: 48,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(height: 12),
          const Text(
            'Pendaftaran Pemilik Usaha',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Masukkan No. Anggota atau Nama Lengkap\nuntuk verifikasi data Anda',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCariAnggotaSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.person_search,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Verifikasi Anggota ISWARA',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // No. Anggota
          TextFormField(
            controller: _noAnggotaController,
            decoration: const InputDecoration(
              labelText: 'No. Anggota ISWARA',
              hintText: 'Contoh: ISW-20260708-0001',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 12),

          // Nama Lengkap
          TextFormField(
            controller: _namaController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nama Lengkap',
              hintText: 'Masukkan nama lengkap Anda',
              prefixIcon: Icon(Icons.person_outlined),
            ),
          ),
          const SizedBox(height: 16),

          // Tombol Cari
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isSearching ? null : _cariAnggota,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              icon: _isSearching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.search),
              label: Text(_isSearching ? 'Mencari...' : 'CARI ANGGOTA'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField({
    required String label,
    required String value,
    required IconData icon,
    required TextEditingController controller,
    bool isEditing = false,
    VoidCallback? onEdit,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onEdit,
              child: Row(
                children: [
                  Icon(
                    isEditing ? Icons.check_circle : Icons.edit,
                    size: 14,
                    color: isEditing ? AppTheme.successColor : Colors.grey[400],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isEditing ? 'Selesai' : 'Edit',
                    style: TextStyle(
                      fontSize: 12,
                      color: isEditing ? AppTheme.successColor : Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        isEditing
            ? TextFormField(
                controller: controller,
                maxLines: maxLines,
                keyboardType: keyboardType,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: hint ?? value,
                  prefixIcon: Icon(icon),
                ),
                validator: validator,
              )
            : Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: Colors.grey[600]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        value.isNotEmpty ? value : hint ?? '-',
                        style: TextStyle(
                          color: value.isNotEmpty ? AppTheme.textPrimary : Colors.grey[400],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ],
    );
  }

  Widget _buildAnggotaSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.successColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_user,
                color: AppTheme.successColor,
              ),
              const SizedBox(width: 8),
              const Text(
                'Data Anggota ISWARA',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.successColor,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _anggotaData!['noAnggota'] ?? '-',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.successColor,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // Nama Lengkap (editable)
          _buildEditableField(
            label: 'Nama Lengkap',
            value: _anggotaData!['namaLengkap'] ?? '-',
            icon: Icons.person_outlined,
            controller: _namaController,
            isEditing: _editingFields['nama'] ?? false,
            onEdit: () => _toggleEdit('nama'),
          ),
          const SizedBox(height: 16),

          // Alamat (read-only dari anggota)
          _buildEditableField(
            label: 'Alamat',
            value: _anggotaData!['alamat'] ?? '-',
            icon: Icons.location_on_outlined,
            controller: TextEditingController(text: _anggotaData!['alamat'] ?? ''),
            isEditing: _editingFields['alamat'] ?? false,
            onEdit: () => _toggleEdit('alamat'),
            hint: 'Alamat tidak dapat diedit',
          ),
          const SizedBox(height: 16),

          // No. WA (editable)
          _buildEditableField(
            label: 'No. WhatsApp',
            value: _anggotaData!['noWa'] ?? '-',
            icon: Icons.phone_outlined,
            controller: _noWaController,
            isEditing: _editingFields['noWa'] ?? false,
            onEdit: () => _toggleEdit('noWa'),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),

          // Daerah (read-only)
          _buildEditableField(
            label: 'Asal Daerah',
            value: _anggotaData!['daerah'] ?? '-',
            icon: Icons.location_city_outlined,
            controller: TextEditingController(text: _anggotaData!['daerah'] ?? ''),
            isEditing: _editingFields['daerah'] ?? false,
            onEdit: () => _toggleEdit('daerah'),
          ),
          const SizedBox(height: 16),

          // Jabatan (read-only)
          _buildEditableField(
            label: 'Jabatan di Aisyiyah',
            value: _anggotaData!['jabatan'] ?? '-',
            icon: Icons.work_outlined,
            controller: TextEditingController(text: _anggotaData!['jabatan'] ?? ''),
            isEditing: _editingFields['jabatan'] ?? false,
            onEdit: () => _toggleEdit('jabatan'),
          ),
        ],
      ),
    );
  }

  Widget _buildAkunSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.account_circle,
                  color: Colors.blue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Akun Login Aplikasi',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Username
          _buildEditableField(
            label: 'Username',
            value: _usernameController.text,
            icon: Icons.alternate_email,
            controller: _usernameController,
            isEditing: _editingFields['username'] ?? false,
            onEdit: () => _toggleEdit('username'),
            hint: 'Masukkan username untuk login',
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Username wajib diisi';
              }
              if (value.length < 3) {
                return 'Username minimal 3 karakter';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Email
          _buildEditableField(
            label: 'Email',
            value: _emailController.text,
            icon: Icons.email_outlined,
            controller: _emailController,
            isEditing: _editingFields['email'] ?? false,
            onEdit: () => _toggleEdit('email'),
            hint: 'Masukkan email Anda',
            keyboardType: TextInputType.emailAddress,
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

          // Password
          _buildEditableField(
            label: 'Password',
            value: '',
            icon: Icons.lock_outlined,
            controller: _passwordController,
            isEditing: _editingFields['password'] ?? false,
            onEdit: () => _toggleEdit('password'),
            hint: 'Masukkan password (min. 8 karakter)',
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Password wajib diisi';
              }
              if (value.length < 8) {
                return 'Password minimal 8 karakter';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Konfirmasi Password
          _buildEditableField(
            label: 'Konfirmasi Password',
            value: '',
            icon: Icons.lock_outlined,
            controller: _konfirmasiPasswordController,
            isEditing: _editingFields['konfirmasi'] ?? false,
            onEdit: () => _toggleEdit('konfirmasi'),
            hint: 'Ulangi password',
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Konfirmasi password wajib diisi';
              }
              if (value != _passwordController.text) {
                return 'Password tidak cocok';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUsahaSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.store_outlined,
                  color: Colors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Data Toko / Usaha',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Nama Toko
          _buildEditableField(
            label: 'Nama Toko / Usaha',
            value: _namaTokoController.text,
            icon: Icons.store_outlined,
            controller: _namaTokoController,
            isEditing: _editingFields['namaToko'] ?? false,
            onEdit: () => _toggleEdit('namaToko'),
            hint: 'Masukkan nama toko/usaha Anda',
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Nama toko wajib diisi';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Jenis Usaha
          _buildEditableField(
            label: 'Jenis Usaha',
            value: _jenisUsahaController.text,
            icon: Icons.category_outlined,
            controller: _jenisUsahaController,
            isEditing: _editingFields['jenisUsaha'] ?? false,
            onEdit: () => _toggleEdit('jenisUsaha'),
            hint: 'Contoh: Fashion, Makanan, Kerajinan, dll',
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Jenis usaha wajib diisi';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Lokasi Usaha
          _buildEditableField(
            label: 'Lokasi Usaha',
            value: _lokasiUsahaController.text,
            icon: Icons.location_on_outlined,
            controller: _lokasiUsahaController,
            isEditing: _editingFields['lokasi'] ?? false,
            onEdit: () => _toggleEdit('lokasi'),
            hint: 'Contoh: Surabaya, Sidoarjo, dll',
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Lokasi usaha wajib diisi';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _daftar,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
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
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check),
                  SizedBox(width: 8),
                  Text(
                    'SIMPAN & MASUK',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
