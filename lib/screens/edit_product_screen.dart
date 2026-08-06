import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import '../../config/theme.dart';
import '../../config/pocketbase_config.dart';
import '../../services/pocketbase_service.dart';
import '../../utils/ownership_helper.dart';

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

  // Image handling - 3 foto
  final List<XFile?> _selectedImages = [null, null, null];
  final List<List<int>?> _selectedImageBytes = [null, null, null];
  final List<String?> _existingImageUrls = [null, null, null];
  final ImagePicker _picker = ImagePicker();

  // Batas ukuran file: 300KB per foto
  static const int maxFileSizeBytes = 300 * 1024; // 300 KB

  // List kategori produk
  final List<String> _kategoriList = [
    'MakanandanMinuman',
    'Fashion',
    'KerajinanTangan',
    'Buku',
    'Travel',
    'ElektronikdanGadget',
    'Jasa',
    'ProdukDigital',
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
    _selectedDaerah = widget.productData['daerah'] ?? widget.daerah;

    // Load existing image URLs from 'gambar' field (array)
    if (widget.productData.containsKey('gambar')) {
      final gambar = widget.productData['gambar'];
      if (gambar is List) {
        for (int i = 0; i < gambar.length && i < 3; i++) {
          if (gambar[i] != null && gambar[i].toString().isNotEmpty) {
            _existingImageUrls[i] = '${PocketBaseConfig.pocketBaseUrl}/api/files/${PocketBaseConfig.produkCollection}/${widget.productId}/${gambar[i]}';
          }
        }
      } else if (gambar != null && gambar.toString().isNotEmpty) {
        _existingImageUrls[0] = '${PocketBaseConfig.pocketBaseUrl}/api/files/${PocketBaseConfig.produkCollection}/${widget.productId}/${gambar}';
      }
    }
  }

  @override
  void dispose() {
    _namaProdukController.dispose();
    _deskripsiController.dispose();
    _hargaController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(int slot, ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 60,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final fileSize = bytes.length;

        if (fileSize > maxFileSizeBytes) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Ukuran foto terlalu besar (${(fileSize / 1024).toStringAsFixed(1)} KB).\nMaksimum 300 KB per foto.',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
          return;
        }

        setState(() {
          _selectedImages[slot] = image;
          _selectedImageBytes[slot] = bytes;
          _existingImageUrls[slot] = null; // Clear existing if new image selected
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

  void _showImageSourceDialog(int slot) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
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
            Text(
              'Pilih Foto ${slot + 1}',
              style: const TextStyle(
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
                      Navigator.pop(ctx);
                      _pickImage(slot, ImageSource.gallery);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSourceOption(
                    icon: Icons.camera_alt,
                    label: 'Kamera',
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(slot, ImageSource.camera);
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

  void _removeImage(int slot) {
    setState(() {
      _selectedImages[slot] = null;
      _selectedImageBytes[slot] = null;
    });
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

      // Ownership check (clone pattern iswara_app _canModify).
      // Cegah seller non-super_admin edit produk orang lain.
      final currentUser = pb.authStore.record;
      // Kalau produk existing tidak punya created_by (data lama),
      // fallback ke izinkan edit (graceful degradation).
      final existingCreatedBy = widget.productData['created_by']?.toString();
      final existingCreatedByNowa = widget.productData['created_by_nowa']?.toString();
      if ((existingCreatedBy != null && existingCreatedBy.isNotEmpty) ||
          (existingCreatedByNowa != null && existingCreatedByNowa.isNotEmpty)) {
        // Build a synthetic RecordModel-like check
        final canEdit = isSuperAdmin(currentUser) ||
            (existingCreatedByNowa != null &&
                existingCreatedByNowa.isNotEmpty &&
                normalizePhone(existingCreatedByNowa) == normalizePhone(widget.noWa)) ||
            (existingCreatedBy == widget.userId);
        if (!canEdit) {
          setState(() => _isLoading = false);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Anda tidak punya izin untuk mengedit produk ini'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      // Prepare data
      final data = <String, dynamic>{
        'nama': _namaProdukController.text.trim(),
        'kategori': _selectedKategori,
        'deskripsi': _deskripsiController.text.trim(),
        'harga': int.tryParse(_hargaController.text.trim()) ?? 0,
        'daerah': _selectedDaerah ?? widget.daerah,
      };

      // Prepare files untuk upload - semua foto dengan field name 'gambar'
      // PocketBase akan menyimpan sebagai array
      final files = <http.MultipartFile>[];

      for (int i = 0; i < 3; i++) {
        if (_selectedImages[i] != null && _selectedImageBytes[i] != null) {
          files.add(http.MultipartFile.fromBytes(
            'gambar', // Semua foto pakai field name 'gambar' (sebagai array)
            _selectedImageBytes[i]!,
            filename: _selectedImages[i]!.name,
          ));
        }
      }

      setState(() => _isUploading = true);

      // Update data dengan/s tanpa file
      if (files.isNotEmpty) {
        await pb.collection(PocketBaseConfig.produkCollection).update(
          widget.productId,
          body: data,
          files: files,
        );
      } else {
        await pb.collection(PocketBaseConfig.produkCollection).update(
          widget.productId,
          body: data,
        );
      }

      setState(() => _isUploading = false);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Produk berhasil diperbarui!'),
          backgroundColor: AppTheme.successColor,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan produk: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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

              // Foto Produk (3 slot)
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
              const SizedBox(height: 16),
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
      child: const Row(
        children: [
          Icon(
            Icons.edit,
            color: AppTheme.primaryColor,
            size: 28,
          ),
          SizedBox(width: 16),
          Expanded(
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Foto Produk',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Upload hingga 3 foto produk',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),

          // 3 Foto Slots
          Row(
            children: [
              _buildPhotoSlot(0),
              const SizedBox(width: 8),
              _buildPhotoSlot(1),
              const SizedBox(width: 8),
              _buildPhotoSlot(2),
            ],
          ),

          const SizedBox(height: 16),

          // Info
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
                const Expanded(
                  child: Text(
                    'Maks. 300 KB per foto. Ganti foto dengan klik pada slot.',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSlot(int index) {
    // Check if has new image or existing image
    final hasNewImage = _selectedImages[index] != null;
    final hasExistingImage = _existingImageUrls[index] != null;

    return Expanded(
      child: GestureDetector(
        onTap: () => _showImageSourceDialog(index),
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (hasNewImage || hasExistingImage)
                  ? AppTheme.primaryColor
                  : AppTheme.dividerColor,
              width: (hasNewImage || hasExistingImage) ? 2 : 1,
            ),
          ),
          child: hasNewImage
              ? Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Image.memory(
                        Uint8List.fromList(_selectedImageBytes[index]!),
                        width: double.infinity,
                        height: 120,
                        fit: BoxFit.contain,
                      ),
                    ),
                    // Badge nomor
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // Tombol hapus
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _removeImage(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                    // Overlay edit
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(11),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.edit, color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text(
                              'Edit',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : hasExistingImage
                  ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Image.network(
                            _existingImageUrls[index]!,
                            width: double.infinity,
                            height: 120,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => _buildEmptySlot(index),
                          ),
                        ),
                        // Badge nomor
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        // Overlay edit
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(11),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.edit, color: Colors.white, size: 12),
                                SizedBox(width: 4),
                                Text(
                                  'Edit',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : _buildEmptySlot(index),
        ),
      ),
    );
  }

  Widget _buildEmptySlot(int index) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_a_photo_outlined,
          size: 32,
          color: AppTheme.textLight,
        ),
        const SizedBox(height: 4),
        Text(
          'Foto ${index + 1}',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }
}
