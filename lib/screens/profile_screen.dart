import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../services/pocketbase_service.dart';
import '../../utils/ownership_helper.dart';
import 'welcome_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_approval_screen.dart';
import 'aktivitas_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String username;
  final String namaToko;
  final String daerah;
  final String noWa;
  final String userId;
  final String noAnggota;
  final String namaLengkap;
  final String jabatan;
  final String? sebagai;
  final String alamat;
  final String? instagram;
  final String? facebook;
  final String? tiktok;
  final String? website;

  const ProfileScreen({
    super.key,
    required this.username,
    required this.namaToko,
    required this.daerah,
    required this.noWa,
    required this.userId,
    required this.noAnggota,
    required this.namaLengkap,
    required this.jabatan,
    this.sebagai,
    required this.alamat,
    this.instagram,
    this.facebook,
    this.tiktok,
    this.website,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaTokoController = TextEditingController();
  final _noWaController = TextEditingController();
  final _alamatController = TextEditingController();
  final _majlisController = TextEditingController();
  final _passwordController = TextEditingController();
  final _konfirmasiPasswordController = TextEditingController();
  final _instagramController = TextEditingController();
  final _facebookController = TextEditingController();
  final _tiktokController = TextEditingController();
  final _websiteController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureKonfirmasi = true;
  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _namaTokoController.text = widget.namaToko;
    _noWaController.text = widget.noWa;
    _alamatController.text = widget.alamat;
    _majlisController.text = widget.jabatan; // widget.jabatan = majlis
    _instagramController.text = widget.instagram ?? '';
    _facebookController.text = widget.facebook ?? '';
    _tiktokController.text = widget.tiktok ?? '';
    _websiteController.text = widget.website ?? '';
  }

  @override
  void dispose() {
    _namaTokoController.dispose();
    _noWaController.dispose();
    _alamatController.dispose();
    _majlisController.dispose();
    _passwordController.dispose();
    _konfirmasiPasswordController.dispose();
    _instagramController.dispose();
    _facebookController.dispose();
    _tiktokController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;

    final pb = PocketBaseService.instance;
    final userData = pb.authStore.record?.data;
    final currentCount = (userData?['ganti_nama_toko_count'] as num?)?.toInt() ?? 0;
    final newNamaToko = _namaTokoController.text.trim();
    final oldNamaToko = widget.namaToko;

    // Cek batas edit nama toko
    if (newNamaToko != oldNamaToko && currentCount >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Batas perubahan nama toko sudah habis (maksimal 3x)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Jika nama toko berubah, cek apakah sudah ada yang pakai
    if (newNamaToko != oldNamaToko) {
      final checkResult = await pb.collection('users').getList(
        filter: 'namatoko = "$newNamaToko"',
        perPage: 1,
      );

      if (checkResult.items.isNotEmpty && checkResult.items.first.id != widget.userId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nama toko sudah digunakan! Pilih nama lain.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      // Update semua field yang bisa diedit
      final updateBody = <String, dynamic>{
        'namatoko': newNamaToko,
        'nowa': _noWaController.text.trim(),
        'alamat': _alamatController.text.trim(),
        'majlis': _majlisController.text.trim(),
        'instagram': _instagramController.text.trim(),
        'facebook': _facebookController.text.trim(),
        'tiktok': _tiktokController.text.trim(),
        'website': _websiteController.text.trim(),
      };

      // Increment counter jika nama toko berubah
      if (newNamaToko != oldNamaToko) {
        updateBody['ganti_nama_toko_count'] = currentCount + 1;
      }

      await pb.collection('users').update(
        widget.userId,
        body: updateBody,
      );

      if (!mounted) return;

      setState(() => _isLoading = false);

      final message = newNamaToko != oldNamaToko
          ? 'Profil berhasil diperbarui! (${currentCount + 1}/3)'
          : 'Profil berhasil diperbarui!';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.successColor,
        ),
      );

      setState(() => _isEditing = false);
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memperbarui profil: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _logout() async {
    // Tampilkan loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final pb = PocketBaseService.instance;
      pb.authStore.clear();

      if (!mounted) return;

      // Tutup loading dialog
      Navigator.pop(context);

      // Navigate ke welcome screen dan hapus semua route sebelumnya
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      // Tutup loading dialog
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal logout'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Saya'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Avatar
              _buildAvatar(),
              const SizedBox(height: 24),

              // Data Anggota
              _buildDataAnggotaSection(),
              const SizedBox(height: 16),

              // Data Toko/Usaha
              _buildTokoSection(),
              const SizedBox(height: 24),

              // Password Section
              if (_isEditing) ...[
                _buildPasswordSection(),
                const SizedBox(height: 24),
                _buildEditActions(),
              ],

              if (!_isEditing) ...[
                const SizedBox(height: 24),
                _buildMenuItems(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primaryColor, AppTheme.primaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.namaToko.isNotEmpty
                  ? widget.namaToko[0].toUpperCase()
                  : widget.username[0].toUpperCase(),
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          widget.namaToko.isNotEmpty ? widget.namaToko : widget.username,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.successColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.verified,
                size: 14,
                color: AppTheme.successColor,
              ),
              const SizedBox(width: 4),
              Text(
                'Pemilik Usaha',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.successColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildDataAnggotaSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.2),
        ),
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
                  Icons.badge,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Data Anggota',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _buildInfoRow('No. Anggota', widget.noAnggota, Icons.tag),
          _buildInfoRow('Nama Lengkap', widget.namaLengkap, Icons.person),
          _buildInfoRow('Daerah', widget.daerah, Icons.location_city),
          _buildInfoRow('Alamat', widget.alamat, Icons.location_on),
          _buildInfoRow('Jabatan', widget.jabatan, Icons.work),
          if (widget.sebagai != null && widget.sebagai!.isNotEmpty)
            _buildInfoRow('Sebagai', widget.sebagai!, Icons.badge),
          // Social Media Section
          if ((widget.instagram != null && widget.instagram!.isNotEmpty) ||
              (widget.facebook != null && widget.facebook!.isNotEmpty) ||
              (widget.tiktok != null && widget.tiktok!.isNotEmpty) ||
              (widget.website != null && widget.website!.isNotEmpty)) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            const Text(
              'Media Sosial',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            if (widget.instagram != null && widget.instagram!.isNotEmpty)
              _buildInfoRow('Instagram', '@${widget.instagram}', Icons.camera_alt),
            if (widget.facebook != null && widget.facebook!.isNotEmpty)
              _buildInfoRow('Facebook', widget.facebook!, Icons.facebook),
            if (widget.tiktok != null && widget.tiktok!.isNotEmpty)
              _buildInfoRow('TikTok', '@${widget.tiktok}', Icons.music_note),
            if (widget.website != null && widget.website!.isNotEmpty)
              _buildInfoRow('Website', widget.website!, Icons.language),
          ],
        ],
      ),
    );
  }

  Widget _buildTokoSection() {
    final pb = PocketBaseService.instance;
    final userData = pb.authStore.record?.data;
    final editCount = (userData?['ganti_nama_toko_count'] as num?)?.toInt() ?? 0;
    final remaining = 3 - editCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.store, color: AppTheme.accentColor),
              SizedBox(width: 12),
              Text(
                'Data Toko / Usaha',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // Email (readonly)
          _buildReadOnlyField(
            label: 'Email',
            value: userData?['email'] ?? '-',
            icon: Icons.email_outlined,
          ),
          const SizedBox(height: 12),

          // Nama Toko (editable) dengan info sisa edit
          Row(
            children: [
              Expanded(
                child: _buildEditableField(
                  label: 'Nama Toko',
                  controller: _namaTokoController,
                  icon: Icons.store,
                  enabled: _isEditing,
                ),
              ),
              if (_isEditing) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: remaining > 0
                        ? AppTheme.infoColor.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$remaining x',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: remaining > 0 ? AppTheme.infoColor : Colors.red,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (_isEditing && remaining <= 1)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                remaining > 0
                    ? 'Sisa $remaining kali perubahan'
                    : 'Batas perubahan sudah habis',
                style: TextStyle(
                  fontSize: 11,
                  color: remaining > 0 ? Colors.orange : Colors.red,
                ),
              ),
            ),
          const SizedBox(height: 12),

          // No. WhatsApp (editable)
          _buildEditableField(
            label: 'No. WhatsApp',
            controller: _noWaController,
            icon: Icons.phone,
            enabled: _isEditing,
          ),
          const SizedBox(height: 12),

          // Alamat (editable)
          _buildEditableField(
            label: 'Alamat',
            controller: _alamatController,
            icon: Icons.location_on,
            enabled: _isEditing,
          ),
          const SizedBox(height: 12),

          // Majlis (editable)
          _buildEditableField(
            label: 'Majlis',
            controller: _majlisController,
            icon: Icons.work,
            enabled: _isEditing,
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          const Text(
            'Media Sosial',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          // Instagram (editable) - Opsional
          _buildEditableField(
            label: 'Instagram',
            controller: _instagramController,
            icon: Icons.camera_alt,
            enabled: _isEditing,
            required: false,
          ),
          const SizedBox(height: 12),

          // Facebook (editable) - Opsional
          _buildEditableField(
            label: 'Facebook',
            controller: _facebookController,
            icon: Icons.facebook,
            enabled: _isEditing,
            required: false,
          ),
          const SizedBox(height: 12),

          // TikTok (editable) - Opsional
          _buildEditableField(
            label: 'TikTok',
            controller: _tiktokController,
            icon: Icons.music_note,
            enabled: _isEditing,
            required: false,
          ),
          const SizedBox(height: 12),

          // Website (editable) - Opsional
          _buildEditableField(
            label: 'Website',
            controller: _websiteController,
            icon: Icons.language,
            enabled: _isEditing,
            required: false,
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.warningColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline, color: AppTheme.warningColor),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Ubah Password (Opsional)',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Password Baru
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password Baru',
              hintText: 'Kosongkan jika tidak diubah',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
            ),
            validator: (value) {
              if (_passwordController.text.isNotEmpty && value!.length < 6) {
                return 'Password minimal 6 karakter';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Konfirmasi Password
          TextFormField(
            controller: _konfirmasiPasswordController,
            obscureText: _obscureKonfirmasi,
            decoration: InputDecoration(
              labelText: 'Konfirmasi Password',
              hintText: 'Ulangi password baru',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureKonfirmasi ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() => _obscureKonfirmasi = !_obscureKonfirmasi);
                },
              ),
            ),
            validator: (value) {
              if (_passwordController.text.isNotEmpty &&
                  value != _passwordController.text) {
                return 'Password tidak cocok';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEditActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading
                ? null
                : () {
                    setState(() {
                      _isEditing = false;
                      _namaTokoController.text = widget.namaToko;
                      _passwordController.clear();
                      _konfirmasiPasswordController.clear();
                    });
                  },
            child: const Text('BATAL'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _simpan,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('SIMPAN'),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItems() {
    // Cek apakah user punya role admin di marketplace.
    // Pakai 2 lapis: is_super_admin (highest) ATAU role != 'member'.
    // Field 'role' dan 'is_super_admin' adalah schema marketplace (Tahap 2).
    // Untuk sekarang (Tahap A), fallback cek jabatan lama.
    final pb = PocketBaseService.instance;
    final currentUser = pb.authStore.record;
    final userIsSuperAdmin = isSuperAdmin(currentUser);
    final userRole = currentUser?.data['role']?.toString();
    final isAdmin = userIsSuperAdmin ||
        (userRole != null && userRole != 'member' && userRole.isNotEmpty) ||
        // Fallback sementara sampai field role diset di Tahap 2:
        widget.jabatan == 'Pimpinan Wilayah' ||
        widget.jabatan == 'Pimpinan Daerah' ||
        widget.jabatan == 'Pimpinan Cabang';

    // Cek apakah user boleh approve seller (super_admin, admin_wilayah, admin_pendaftaran).
    final isApprover = userIsSuperAdmin ||
        userRole == 'admin_wilayah' ||
        userRole == 'admin_pendaftaran' ||
        widget.jabatan == 'Pimpinan Wilayah' ||
        widget.jabatan == 'Pimpinan Daerah' ||
        widget.jabatan == 'Pimpinan Cabang';

    return Column(
      children: [
        // Menu Admin Dashboard (hanya untuk admin)
        // Tidak tampak di welcome screen, hanya untuk user dengan role admin.
        // Mirip iswara_app: admin menu ada di profile, hidden untuk user biasa.
        if (isAdmin) ...[
          _buildMenuItem(
            icon: Icons.admin_panel_settings,
            title: 'Dashboard Admin',
            color: AppTheme.primaryColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminDashboardScreen(
                    userId: widget.userId,
                    namaLengkap: widget.namaLengkap,
                    jabatan: widget.jabatan,
                    daerah: widget.daerah,
                    sebagai: widget.sebagai,
                  ),
                ),
              );
            },
          ),
          // Menu Verifikasi Seller (sub-menu admin)
          if (isApprover)
            _buildMenuItem(
              icon: Icons.verified_user,
              title: 'Verifikasi Seller',
              color: AppTheme.successColor,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminApprovalScreen(
                      userId: widget.userId,
                      namaLengkap: widget.namaLengkap,
                    ),
                  ),
                );
              },
            ),
        ],
        _buildMenuItem(
            icon: Icons.history,
            title: 'Aktivitas Saya',
            color: AppTheme.primaryColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AktivitasScreen()),
              );
            },
          ),
        _buildMenuItem(
          icon: Icons.help_outline,
          title: 'Bantuan',
          onTap: () {},
        ),
        _buildMenuItem(
          icon: Icons.info_outline,
          title: 'Tentang Marketplace',
          onTap: () {},
        ),
        _buildMenuItem(
          icon: Icons.delete_outline,
          title: 'Hapus Akun',
          color: AppTheme.errorColor,
          onTap: () => _showDeleteAccountDialog(),
        ),
        _buildMenuItem(
          icon: Icons.logout,
          title: 'Keluar',
          color: Colors.orange,
          onTap: () => _showLogoutDialog(),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isNotEmpty ? value : '-',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isNotEmpty ? value : '-',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required bool enabled,
    bool required = true,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: enabled ? Colors.white : AppTheme.backgroundColor,
      ),
      validator: required ? (value) {
        if (value == null || value.isEmpty) {
          return 'Field ini wajib diisi';
        }
        return null;
      } : null,
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.dividerColor),
            ),
            child: Row(
              children: [
                Icon(icon, color: color ?? AppTheme.primaryColor, size: 22),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: color ?? AppTheme.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: color ?? AppTheme.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.orange),
            SizedBox(width: 12),
            Text('Keluar'),
          ],
        ),
        content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('KELUAR'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: AppTheme.errorColor),
            SizedBox(width: 12),
            Text('Hapus Akun'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PERHATIAN: Menghapus akun akan:'),
            SizedBox(height: 12),
            Text('• Anda tidak bisa login lagi'),
            Text('• Data Anda tetap tersimpan untuk referensi'),
            Text('• Produk Anda tetap terlihat di marketplace'),
            SizedBox(height: 12),
            Text(
              'Tindakan ini TIDAK DAPAT dibatalkan!',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.errorColor),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showDeleteConfirmationDialog();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('LANJUTKAN'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog() {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock, color: AppTheme.errorColor),
            SizedBox(width: 12),
            Text('Konfirmasi Password'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Masukkan password Anda untuk konfirmasi:'),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteAccount(passwordController.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('HAPUS AKUN'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount(String password) async {
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password wajib diisi'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final pb = PocketBaseService.instance;

      // 1. Soft delete - set deleted_at timestamp (data tetap tersimpan)
      await pb.collection('users').update(
        widget.userId,
        body: {
          'deleted_at': DateTime.now().toIso8601String(),
        },
      );

      // 2. Clear auth store
      pb.authStore.clear();

      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Akun berhasil dinonaktifkan. Data Anda tetap tersimpan.'),
          backgroundColor: AppTheme.successColor,
        ),
      );

      // Kembali ke welcome screen
      Navigator.popUntil(context, (route) => route.isFirst);

    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus akun: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
