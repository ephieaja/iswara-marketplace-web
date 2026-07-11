import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../config/theme.dart';
import '../../services/pocketbase_service.dart';

class RegisterAnggotaScreen extends StatefulWidget {
  final bool isEditing;
  final String? editDocId;

  const RegisterAnggotaScreen({
    super.key,
    this.isEditing = false,
    this.editDocId,
  });

  @override
  State<RegisterAnggotaScreen> createState() => _RegisterAnggotaScreenState();
}

class _RegisterAnggotaScreenState extends State<RegisterAnggotaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _alamatController = TextEditingController();
  final _noWaController = TextEditingController();
  final _sebagaiController = TextEditingController();

  String? _selectedProvinsi;
  String? _selectedDaerah;
  String? _selectedJabatan;
  bool _isLoading = false;

  // For editing
  String? _existingNoAnggota;
  bool _isDataLoaded = false;

  // List Provinsi
  final List<String> _provinsiList = [
    'Jawa Timur',
  ];

  // List Daerah per Provinsi
  final Map<String, List<String>> _daerahMap = {
    'Jawa Timur': [
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
    ],
  };

  // List jabatan (updated)
  final List<String> _jabatanList = [
    'Pimpinan Wilayah',
    'Pimpinan Daerah',
    'Pimpinan Cabang',
    'Pimpinan Ranting',
    'Anggota',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.isEditing && widget.editDocId != null) {
      _loadExistingData();
    }
  }

  Future<void> _loadExistingData() async {
    if (widget.editDocId == null) return;

    setState(() => _isLoading = true);

    try {
      final pb = PocketBaseService.instance;
      final doc = await pb.collection('anggota_iswara').getOne(widget.editDocId!);

      final data = doc.data;
      setState(() {
        _namaController.text = data['namaLengkap'] ?? '';
        _alamatController.text = data['alamat'] ?? '';
        _noWaController.text = data['noWa'] ?? '';
        _selectedProvinsi = data['provinsi'];
        _selectedDaerah = data['daerah'];
        _selectedJabatan = data['jabatan'];
        _sebagaiController.text = data['sebagai'] ?? '';
        _existingNoAnggota = data['noAnggota'];
        _isDataLoaded = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _alamatController.dispose();
    _noWaController.dispose();
    _sebagaiController.dispose();
    super.dispose();
  }

  void _daftar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDaerah == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih asal daerah')),
      );
      return;
    }

    if (_selectedJabatan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih jabatan di Aisyiyah')),
      );
      return;
    }

    if (_selectedProvinsi == null || _selectedDaerah == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih asal daerah')),
      );
      return;
    }

    // Jika pimpinan, harus isi "sebagai"
    if ((_selectedJabatan == 'Pimpinan Wilayah' ||
         _selectedJabatan == 'Pimpinan Daerah' ||
         _selectedJabatan == 'Pimpinan Cabang' ||
         _selectedJabatan == 'Pimpinan Ranting') &&
        _sebagaiController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi field "Sebagai" untuk pimpinan')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final pb = PocketBaseService.instance;
      String noAnggota;

      if (widget.isEditing && widget.editDocId != null) {
        // Update existing data
        noAnggota = _existingNoAnggota ?? _generateNoAnggota();

        await pb.collection('anggota_iswara').update(
          widget.editDocId!,
          body: {
            'namaLengkap': _namaController.text.trim(),
            'alamat': _alamatController.text.trim(),
            'noWa': _noWaController.text.trim(),
            'provinsi': _selectedProvinsi,
            'daerah': _selectedDaerah,
            'jabatan': _selectedJabatan,
            'sebagai': _selectedJabatan != 'Anggota'
                ? _sebagaiController.text.trim()
                : null,
          },
        );
      } else {
        // Create new data
        noAnggota = _generateNoAnggota();

        await pb.collection('anggota_iswara').create(
          body: {
            'noAnggota': noAnggota,
            'namaLengkap': _namaController.text.trim(),
            'alamat': _alamatController.text.trim(),
            'noWa': _noWaController.text.trim(),
            'provinsi': _selectedProvinsi,
            'daerah': _selectedDaerah,
            'jabatan': _selectedJabatan,
            'sebagai': _selectedJabatan != 'Anggota'
                ? _sebagaiController.text.trim()
                : null,
          },
        );
      }

      if (!mounted) return;

      setState(() => _isLoading = false);

      // Show success dialog
      _showSuccessDialog(noAnggota, widget.isEditing);

    } on ClientException catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      String errorMsg = 'Terjadi kesalahan';
      if (e.response != null && e.response['message'] != null) {
        errorMsg = e.response['message'].toString();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $errorMsg'),
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

  String _generateNoAnggota() {
    // Format: ISW-YYYYMMDD-XXXX (contoh: ISW-20260708-0001)
    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    // Generate random 4 digit
    final random = DateTime.now().millisecondsSinceEpoch % 10000;
    return 'ISW-$dateStr-${random.toString().padLeft(4, '0')}';
  }

  void _showSuccessDialog(String noAnggota, bool isEdit) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: AppTheme.successColor,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isEdit ? 'Update Berhasil!' : 'Pendaftaran Berhasil!',
              style: const TextStyle(fontSize: 20),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isEdit
                  ? 'Data anggota berhasil diperbarui.'
                  : 'Selamat! Anda telah terdaftar sebagai anggota ISWARA.',
              textAlign: TextAlign.center,
            ),
            if (!isEdit) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'No. Anggota Anda:',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      noAnggota,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Catat No. Anggota ini untuk mendaftar\nsebagai Pemilik Usaha.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
                if (!isEdit) {
                  // Show option to register as business owner
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              child: Text(isEdit ? 'OK' : 'DAFTAR PEMILIK USAHA'),
            ),
          ),
          if (!isEdit) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('NANTI SAJA'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && !_isDataLoaded && widget.isEditing) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Edit Anggota ISWARA'),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Anggota ISWARA' : 'Daftar Anggota ISWARA'),
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

                // Nama Lengkap
                _buildEditableField(
                  controller: _namaController,
                  label: 'Nama Lengkap',
                  hint: 'Masukkan nama lengkap',
                  icon: Icons.person_outlined,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Nama lengkap wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Alamat
                _buildEditableField(
                  controller: _alamatController,
                  label: 'Alamat',
                  hint: 'Masukkan alamat lengkap',
                  icon: Icons.location_on_outlined,
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Alamat wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // No. WA
                _buildEditableField(
                  controller: _noWaController,
                  label: 'No. WhatsApp',
                  hint: '08xxxxxxxxxx',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'No. WhatsApp wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Provinsi
                _buildDropdownField(
                  value: _selectedProvinsi,
                  label: 'Provinsi',
                  icon: Icons.map_outlined,
                  items: _provinsiList,
                  onChanged: (value) => setState(() {
                    _selectedProvinsi = value;
                    _selectedDaerah = null; // Reset daerah when provinsi changes
                  }),
                  validator: (value) => value == null ? 'Pilih provinsi' : null,
                ),
                const SizedBox(height: 16),

                // Daerah
                _buildDropdownField(
                  value: _selectedDaerah,
                  label: 'Daerah',
                  icon: Icons.location_city_outlined,
                  items: _selectedProvinsi != null
                      ? (_daerahMap[_selectedProvinsi] ?? [])
                      : [],
                  onChanged: (value) => setState(() => _selectedDaerah = value),
                  validator: (value) => value == null ? 'Pilih daerah' : null,
                ),
                const SizedBox(height: 16),

                // Jabatan di Aisyiyah
                _buildDropdownField(
                  value: _selectedJabatan,
                  label: 'Jabatan di Aisyiyah',
                  icon: Icons.work_outlined,
                  items: _jabatanList,
                  onChanged: (value) => setState(() {
                    _selectedJabatan = value;
                    _sebagaiController.clear();
                  }),
                  validator: (value) => value == null ? 'Pilih jabatan' : null,
                ),
                const SizedBox(height: 16),

                // Field "Sebagai" - hanya tampil jika pimpinan
                if (_selectedJabatan == 'Pimpinan Wilayah' ||
                    _selectedJabatan == 'Pimpinan Daerah' ||
                    _selectedJabatan == 'Pimpinan Cabang' ||
                    _selectedJabatan == 'Pimpinan Ranting') ...[
                  _buildEditableField(
                    controller: _sebagaiController,
                    label: 'Sebagai',
                    hint: 'Contoh: Ketua PC, Sekretaris PC, dll',
                    icon: Icons.badge_outlined,
                  ),
                  const SizedBox(height: 16),
                ],

                // Tombol Simpan
                SizedBox(
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
                        : Text(
                            widget.isEditing ? 'SIMPAN PERUBAHAN' : 'SIMPAN',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
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
          Icon(
            widget.isEditing ? Icons.edit : Icons.card_membership,
            size: 48,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(height: 12),
          Text(
            widget.isEditing ? 'Edit Anggota ISWARA' : 'Pendaftaran Anggota ISWARA',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isEditing
                ? 'Perbarui data anggota ISWARA'
                : 'Lengkapi data untuk mendaftar sebagai\nanggota IKATAN SAUDAGAR AISIYIYAH JAWA TIMUR',
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

  Widget _buildEditableField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
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
            Icon(
              Icons.edit,
              size: 14,
              color: Colors.grey[400],
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required String label,
    required IconData icon,
    required List<String> items,
    required void Function(String?) onChanged,
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
            Icon(
              Icons.edit,
              size: 14,
              color: Colors.grey[400],
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            prefixIcon: Icon(icon),
          ),
          items: items.map((item) {
            return DropdownMenuItem(value: item, child: Text(item));
          }).toList(),
          onChanged: onChanged,
          validator: validator,
        ),
      ],
    );
  }
}
