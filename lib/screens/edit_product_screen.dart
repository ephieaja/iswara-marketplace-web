import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import '../../config/theme.dart';
import '../../config/pocketbase_config.dart';
import '../../models/product_model.dart';
import '../../services/pocketbase_service.dart';
import '../../utils/ownership_helper.dart';

/// Edit Produk untuk ISWARA Marketplace (Fase 1.5)
///
/// PERUBAHAN 14 Agt 2026 (Fase 1):
/// - PATCH `ProdukMarketplace` (bukan `Produk` legacy)
/// - Varian di-manage via diff: fetch existing `produk_varian_marketplace`
///   records di initState, lalu saat Save:
///   * Varian dengan `existingRecordId` ada di list → PATCH
///   * Varian baru (`existingRecordId` null) → POST
///   * Varian yang ada di PB tapi dihapus dari form → DELETE
/// - `seller` field sudah di-snapshot di ProdukMarketplace record (tidak diubah)
/// - Max file size 200KB (Fase 1 marketplace), sebelumnya 300KB
class EditProductScreen extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> productData;
  final String userId;
  final String namaToko;
  final String daerah;
  final String noWa;

  /// Record id `SellersMarketplace` untuk user ini. Opsional — kalau null,
  /// screen akan fetch otomatis dari `SellersMarketplace` collection pakai
  /// `user` relation = users_auth.id.
  final String? sellersMarketplaceId;

  const EditProductScreen({
    super.key,
    required this.productId,
    required this.productData,
    required this.userId,
    required this.namaToko,
    required this.daerah,
    required this.noWa,
    this.sellersMarketplaceId,
  });

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _namaProdukController;
  late final TextEditingController _deskripsiController;
  late final TextEditingController _hargaController;
  late final TextEditingController _varianLabelController;

  String? _selectedKategori;
  String? _selectedDaerah;
  bool _isLoading = false;
  bool _isUploading = false;

  // Image handling - 3 foto
  final List<XFile?> _selectedImages = [null, null, null];
  final List<List<int>?> _selectedImageBytes = [null, null, null];
  final List<String?> _existingImageUrls = [null, null, null];
  final ImagePicker _picker = ImagePicker();

  // Varian handling (clone pattern diskusi 8 Agt 2026)
  final List<_EditVariantEntry> _varianList = [];

  // Batas ukuran file: 200KB per foto (Fase 1 marketplace, samakan dengan PB schema).
  // Sebelumnya 300KB (clone dari iswara_app).
  static const int maxFileSizeBytes = 200 * 1024; // 200 KB

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
    _varianLabelController = TextEditingController(
      text: widget.productData['varian_label']?.toString() ?? '',
    );
    _selectedKategori = widget.productData['kategori'];
    _selectedDaerah = widget.productData['daerah'] ?? widget.daerah;

    // Load existing image URLs from 'gambar' field (array)
    if (widget.productData.containsKey('gambar')) {
      final gambar = widget.productData['gambar'];
      if (gambar is List) {
        for (int i = 0; i < gambar.length && i < 3; i++) {
          if (gambar[i] != null && gambar[i].toString().isNotEmpty) {
            _existingImageUrls[i] = '${PocketBaseConfig.pocketBaseUrl}/api/files/${PocketBaseConfig.produkMarketplaceCollection}/${widget.productId}/${gambar[i]}';
          }
        }
      } else if (gambar != null && gambar.toString().isNotEmpty) {
        _existingImageUrls[0] = '${PocketBaseConfig.pocketBaseUrl}/api/files/${PocketBaseConfig.produkMarketplaceCollection}/${widget.productId}/${gambar}';
      }
    }

    // Load existing variants dari `produk_varian_marketplace` collection (Fase 1).
    // Fallback ke JSON inline `varian_list` kalau gagal (untuk backward compat
    // dengan data lama yang masih di Produk legacy).
    _loadExistingVariants();
  }

  /// Fetch existing varian records dari `produk_varian_marketplace` collection.
  /// Pre-fill `_varianList` dengan data + existingRecordId.
  Future<void> _loadExistingVariants() async {
    try {
      final pb = PocketBaseService.instance;
      final result = await pb
          .collection(PocketBaseConfig.produkVarianMarketplaceCollection)
          .getList(
            filter: 'produk = "${widget.productId}"',
            perPage: 50,
          );

      if (!mounted) return;

      if (result.items.isNotEmpty) {
        // Pakai data dari PB collection
        setState(() {
          for (final record in result.items) {
            final entry = _EditVariantEntry();
            entry.namaController.text = record.data['nama']?.toString() ?? '';
            entry.hargaController.text = record.data['harga']?.toString() ?? '';
            entry.stokController.text = record.data['stok']?.toString() ?? '0';
            entry.skuController.text = record.data['sku']?.toString() ?? '';
            entry.existingRecordId = record.id;
            _varianList.add(entry);
          }
        });
      } else {
        // Fallback ke JSON inline (legacy data)
        final rawVarianList = widget.productData['varian_list'];
        if (rawVarianList is List) {
          for (final v in rawVarianList) {
            if (v is Map) {
              final entry = _EditVariantEntry();
              entry.namaController.text = v['nama']?.toString() ?? '';
              entry.hargaController.text = v['harga']?.toString() ?? '';
              entry.stokController.text = v['stok']?.toString() ?? '0';
              entry.skuController.text = v['sku']?.toString() ?? '';
              _varianList.add(entry);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error load existing variants: $e');
      // Fallback ke JSON inline
      final rawVarianList = widget.productData['varian_list'];
      if (rawVarianList is List && mounted) {
        setState(() {
          for (final v in rawVarianList) {
            if (v is Map) {
              final entry = _EditVariantEntry();
              entry.namaController.text = v['nama']?.toString() ?? '';
              entry.hargaController.text = v['harga']?.toString() ?? '';
              entry.stokController.text = v['stok']?.toString() ?? '0';
              entry.skuController.text = v['sku']?.toString() ?? '';
              _varianList.add(entry);
            }
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _namaProdukController.dispose();
    _deskripsiController.dispose();
    _hargaController.dispose();
    _varianLabelController.dispose();
    for (final v in _varianList) {
      v.dispose();
    }
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
                'Ukuran foto terlalu besar (${(fileSize / 1024).toStringAsFixed(1)} KB).\nMaksimum 200 KB per foto.',
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
      final existingCreatedBy = widget.productData['created_by']?.toString();
      final existingCreatedByNowa = widget.productData['created_by_nowa']?.toString();
      if ((existingCreatedBy != null && existingCreatedBy.isNotEmpty) ||
          (existingCreatedByNowa != null && existingCreatedByNowa.isNotEmpty)) {
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

      // Prepare data ProdukMarketplace (Fase 1 schema)
      final data = <String, dynamic>{
        'nama': _namaProdukController.text.trim(),
        'kategori': _selectedKategori,
        'deskripsi': _deskripsiController.text.trim(),
        'harga': int.tryParse(_hargaController.text.trim()) ?? 0,
        'daerah': _selectedDaerah ?? widget.daerah,
        // Varian label tetap di Produk (varian_list di-collection terpisah)
        'varian_label': _varianLabelController.text.trim(),
        // 'varian_list' JSON inline TIDAK dipakai lagi (Fase 1)
      };

      // Prepare files untuk upload - semua foto dengan field name 'gambar'
      // PocketBase akan menyimpan sebagai array (max 15 file, 200KB each)
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

      // PATCH ProdukMarketplace (Fase 1)
      if (files.isNotEmpty) {
        await pb
            .collection(PocketBaseConfig.produkMarketplaceCollection)
            .update(
          widget.productId,
          body: data,
          files: files,
        );
      } else {
        await pb
            .collection(PocketBaseConfig.produkMarketplaceCollection)
            .update(
          widget.productId,
          body: data,
        );
      }

      setState(() => _isUploading = false);

      // ============================================
      // DIFF SYNC VARIAN (Fase 1)
      // ============================================
      // Track id varian existing di awal form (sebelum user edit).
      // Setelah Save, id yang masih ada di _varianList → PATCH
      //                              id baru → POST
      //                              id di original tapi TIDAK ada di _varianList → DELETE
      final Set<String> originalIds = _varianList
          .map((v) => v.existingRecordId)
          .whereType<String>()
          .toSet();
      final Set<String> keptIds = {};

      for (final variant in _varianList) {
        // Skip varian kosong (nama kosong)
        if (variant.namaController.text.trim().isEmpty) {
          // Kalau ada existingRecordId tapi nama kosong, DELETE
          if (variant.existingRecordId != null) {
            try {
              await pb
                  .collection(PocketBaseConfig.produkVarianMarketplaceCollection)
                  .delete(variant.existingRecordId!);
            } catch (e) {
              debugPrint('Error DELETE varian kosong: $e');
            }
          }
          continue;
        }

        final harga = int.tryParse(variant.hargaController.text.trim()) ?? 0;
        final stok = int.tryParse(variant.stokController.text.trim()) ?? 0;
        final sku = variant.skuController.text.trim();

        try {
          if (variant.existingRecordId == null) {
            // POST varian baru
            await pb
                .collection(PocketBaseConfig.produkVarianMarketplaceCollection)
                .create(
              body: {
                'produk': widget.productId,
                'nama': variant.namaController.text.trim(),
                'harga': harga,
                'stok': stok,
                if (sku.isNotEmpty) 'sku': sku,
              },
            );
          } else {
            // PATCH varian existing
            await pb
                .collection(PocketBaseConfig.produkVarianMarketplaceCollection)
                .update(
              variant.existingRecordId!,
              body: {
                'nama': variant.namaController.text.trim(),
                'harga': harga,
                'stok': stok,
                if (sku.isNotEmpty) 'sku': sku,
              },
            );
            keptIds.add(variant.existingRecordId!);
          }
        } catch (e) {
          debugPrint('Error sync varian: $e');
          // Lanjut ke varian berikutnya (partial save OK)
        }
      }

      // DELETE varian yang ada di original tapi tidak ada di keptIds
      final removedIds = originalIds.difference(keptIds);
      for (final removedId in removedIds) {
        try {
          await pb
              .collection(PocketBaseConfig.produkVarianMarketplaceCollection)
              .delete(removedId);
        } catch (e) {
          debugPrint('Error DELETE removed varian: $e');
        }
      }

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
              const SizedBox(height: 24),

              // Varian section (clone pattern diskusi 8 Agt 2026)
              _buildVarianSection(),
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
                    'Maks. 200 KB per foto. Ganti foto dengan klik pada slot.',
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

  // ========================================================
  // VARIAN SECTION (clone pattern diskusi 8 Agt 2026)
  // ========================================================
  Widget _buildVarianSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.style, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Varian Produk',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: AppTheme.primaryColor),
                tooltip: 'Tambah Varian',
                onPressed: _addVariant,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Opsional. Mis. warna (fashion), rasa (makanan), ukuran (pakaian). Tiap varian bisa punya harga sendiri.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _varianLabelController,
            decoration: const InputDecoration(
              labelText: 'Label Varian',
              hintText: 'Mis. Warna, Rasa, Ukuran',
              prefixIcon: Icon(Icons.label_outline),
            ),
          ),
          const SizedBox(height: 12),
          if (_varianList.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey.shade500, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Belum ada varian. Produk tanpa varian tetap bisa dijual.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            )
          else
            ..._varianList.asMap().entries.map((entry) => _buildVariantCard(entry.key, entry.value)),
        ],
      ),
    );
  }

  Widget _buildVariantCard(int index, _EditVariantEntry variant) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Varian ${index + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _removeVariant(index),
                child: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: variant.namaController,
            decoration: const InputDecoration(
              labelText: 'Nama Varian *',
              hintText: 'Mis. Merah, Pedas, L',
              isDense: true,
            ),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: variant.hargaController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Harga *',
                    hintText: '50000',
                    prefixIcon: Icon(Icons.attach_money, size: 18),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: variant.stokController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Stok',
                    hintText: '0',
                    prefixIcon: Icon(Icons.inventory_2_outlined, size: 18),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: variant.skuController,
            decoration: const InputDecoration(
              labelText: 'SKU (opsional)',
              hintText: 'Mis. BTK-MRH',
              prefixIcon: Icon(Icons.qr_code, size: 18),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _addVariant() {
    setState(() {
      _varianList.add(_EditVariantEntry());
    });
  }

  void _removeVariant(int index) {
    setState(() {
      _varianList[index].dispose();
      _varianList.removeAt(index);
    });
  }
}

/// Model lokal untuk variant entry di form edit product.
/// Fase 1: tambah `existingRecordId` untuk track record id `produk_varian_marketplace`
/// (null kalau varian ini BARU, belum ada di PB).
class _EditVariantEntry {
  final TextEditingController namaController = TextEditingController();
  final TextEditingController hargaController = TextEditingController();
  final TextEditingController stokController = TextEditingController(text: '0');
  final TextEditingController skuController = TextEditingController();

  /// Record id di `produk_varian_marketplace` collection (Fase 1).
  /// - null: varian BARU, akan di-POST saat Save
  /// - non-null: varian existing, akan di-PATCH saat Save (atau DELETE kalau dihapus)
  String? existingRecordId;

  void dispose() {
    namaController.dispose();
    hargaController.dispose();
    stokController.dispose();
    skuController.dispose();
  }

  ProductVariant toVariant() {
    return ProductVariant(
      nama: namaController.text.trim(),
      harga: int.tryParse(hargaController.text.trim()) ?? 0,
      stok: int.tryParse(stokController.text.trim()) ?? 0,
      sku: skuController.text.trim().isEmpty ? null : skuController.text.trim(),
    );
  }
}

