import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import '../../config/theme.dart';
import '../../config/pocketbase_config.dart';
import '../../services/pocketbase_service.dart';

class EditProductScreen extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> productData;
  final String userId;
  final String namaToko;
  final String daerah;
  final String noWa;

  const EditProductScreen({
    super.key,
    required this.productId,
    required this.productData,
    required this.userId,
    required this.namaToko,
    required this.daerah,
    required this.noWa,
  });

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _namaProdukController;
  late final TextEditingController _deskripsiController;
  late final TextEditingController _hargaController;

  String? _selectedKategori;
  String? _selectedDaerah;
  bool _isLoading = false;
  bool _isUploading = false;
  bool _imageChanged = false;

  // Image handling
  File? _selectedImage;
  String? _existingImageUrl;
  final ImagePicker _picker = ImagePicker();

  // Batas ukuran file: 300KB
  static const int maxFileSizeBytes = 300 * 1024; // 300 KB

  // List kategori produk
  final List<String> _kategoriList = [
    'Makanan & Minuman',
    'Fashion & Busana',
    'Kecantikan & Skincare',
    'Kerajinan Tangan',
    'Produk Rumahan',
    'Elektronik & Gadget',
    'Hobi &文旅',
    'Jasa & Layanan',
    'Pertanian & Peternakan',
    'Lainnya',
  ];

  // List daerah
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
  ];

  @override
  void initState() {
    super.initState();
    // Pre-fill form dengan data produk yang ada
    _namaProdukController = TextEditingController(
      text: widget.productData['nama'] ?? '',
    );
    _deskripsiController = TextEditingController(
      text: widget.productData['deskripsi'] ?? '',
    );
    _hargaController = TextEditingController(
      text: widget.productData['harga']?.toString() ?? '',
    );
    _selectedKategori = widget.productData['kategori'];
    _selectedDaerah = widget.productData['Daerah'] ?? widget.daerah;
    _existingImageUrl = widget.productData['gambar']?.toString();
  }

  @override
  void dispose() {
    _namaProdukController.dispose();
    _deskripsiController.dispose();
    _hargaController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 50,
      );

      if (image != null) {
        final fileSize = await File(image.path).length();

        if (fileSize > maxFileSizeBytes) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Ukuran file terlalu besar (${(fileSize / 1024).toStringAsFixed(1)} KB).\nMaksimum 300 KB.',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
          return;
        }

        setState(() {
          _selectedImage = File(image.path);
          _imageChanged = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memilih gambar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showImageSourceDialog() {
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
            const Text(
              'Pilih Sumber Foto',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildSourceOption(
                    icon: Icons.photo_library,
                    label: 'Galeri',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSourceOption(
                    icon: Icons.camera_alt,
                    label: 'Kamera',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: AppTheme.primaryColor),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _simpanProduk() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedKategori == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih kategori produk'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final pb = PocketBaseService.instance;

      // Prepare data
      final data = <String, dynamic>{
        'nama': _namaProdukController.text.trim(),
        'kategori': _selectedKategori,
        'deskripsi': _deskripsiController.text.trim(),
        'harga': int.tryParse(_hargaController.text.trim()) ?? 0,
        'Daerah': _selectedDaerah ?? widget.daerah,
      };

      // Upload gambar baru jika ada perubahan
      if (_imageChanged && _selectedImage != null) {
        setState(() => _isUploading = true);

        final multipartFile = await http.MultipartFile.fromPath(
          'gambar',
          _selectedImage!.path,
        );

        await pb.collection(PocketBaseConfig.produkCollection).update(
          widget.productId,
          body: data,
          files: [multipartFile],
        );

        setState(() => _isUploading = false);
      } else {
        // Tanpa perubahan gambar
        await pb.collection(PocketBaseConfig.produkCollection).update(
          widget.productId,
          body: data,
        );
      }

      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Produk berhasil diperbarui!'),
          backgroundColor: AppTheme.successColor,
        ),
      );

      // Kembali ke halaman sebelumnya
      Navigator.pop(context, true); // Return true = success
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _hapusGambar() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: AppTheme.errorColor),
            SizedBox(width: 12),
            Text('Hapus Foto'),
          ],
        ),
        content: const Text('Hapus foto produk ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final pb = PocketBaseService.instance;
                await pb.collection(PocketBaseConfig.produkCollection).update(
                  widget.productId,
                  body: {'gambar': ''},
                );
                setState(() {
                  _selectedImage = null;
                  _existingImageUrl = null;
                  _imageChanged = true;
                });
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Gagal menghapus gambar: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('HAPUS'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Produk'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              _buildHeaderCard(),
              const SizedBox(height: 24),

              // Foto Produk
              _buildPhotoSection(),
              const SizedBox(height: 24),

              // Nama Produk
              TextFormField(
                controller: _namaProdukController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama Produk',
                  hintText: 'Masukkan nama produk',
                  prefixIcon: Icon(Icons.shopping_bag_outlined),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Nama produk wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Harga
              TextFormField(
                controller: _hargaController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Harga (Rp)',
                  hintText: 'Contoh: 50000',
                  prefixIcon: Icon(Icons.attach_money),
                ),
              ),
              const SizedBox(height: 16),

              // Kategori
              DropdownButtonFormField<String>(
                value: _selectedKategori,
                decoration: const InputDecoration(
                  labelText: 'Kategori',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: _kategoriList.map((kategori) {
                  return DropdownMenuItem(
                    value: kategori,
                    child: Text(kategori),
                  );
                }).toList(),
                onChanged: (value) =>
                    setState(() => _selectedKategori = value),
                validator: (value) =>
                    value == null ? 'Pilih kategori' : null,
              ),
              const SizedBox(height: 16),

              // Daerah
              DropdownButtonFormField<String>(
                value: _selectedDaerah,
                decoration: const InputDecoration(
                  labelText: 'Daerah',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                items: _daerahList.map((daerah) {
                  return DropdownMenuItem(
                    value: daerah,
                    child: Text(daerah),
                  );
                }).toList(),
                onChanged: (value) =>
                    setState(() => _selectedDaerah = value),
              ),
              const SizedBox(height: 16),

              // Deskripsi
              TextFormField(
                controller: _deskripsiController,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi Produk',
                  hintText: 'Jelaskan produk Anda...',
                  alignLabelWithHint: true,
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 60),
                    child: Icon(Icons.description_outlined),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Deskripsi wajib diisi';
                  }
                  if (value.length < 10) {
                    return 'Deskripsi minimal 10 karakter';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Tombol Simpan
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: (_isLoading || _isUploading) ? null : _simpanProduk,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: (_isLoading || _isUploading)
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'MENYIMPAN...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save),
                            SizedBox(width: 8),
                            Text(
                              'SIMPAN PERUBAHAN',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.1),
            AppTheme.accentColor.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.edit,
              color: AppTheme.primaryColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit Produk',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Perbarui data produk Anda',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection() {
    final hasImage = _selectedImage != null || (_existingImageUrl != null && _existingImageUrl!.isNotEmpty);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        children: [
          // Preview gambar
          GestureDetector(
            onTap: _showImageSourceDialog,
            child: Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.dividerColor,
                  style: BorderStyle.solid,
                ),
                image: _selectedImage != null
                    ? DecorationImage(
                        image: FileImage(_selectedImage!),
                        fit: BoxFit.cover,
                      )
                    : _existingImageUrl != null && _existingImageUrl!.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(_existingImageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
              ),
              child: !hasImage
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 64,
                          color: AppTheme.textLight,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Klik untuk upload foto',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    )
                  : Stack(
                      children: [
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(12),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.edit, color: Colors.white, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  'Klik untuk更换照片',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),

          // Info
          if (hasImage) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _imageChanged
                          ? 'Foto baru akan diupload saat disimpan'
                          : 'Foto saat ini - klik untuk更换',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Tombol Hapus Foto
            TextButton.icon(
              onPressed: _hapusGambar,
              icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
              label: const Text(
                'Hapus Foto',
                style: TextStyle(color: AppTheme.errorColor),
              ),
            ),
          ],

          if (!hasImage) ...[
            // Tombol Galeri dan Kamera
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galeri'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Kamera'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
