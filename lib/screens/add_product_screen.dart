import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import '../../config/theme.dart';
import '../../config/pocketbase_config.dart';
import '../../services/pocketbase_service.dart';

class AddProductScreen extends StatefulWidget {
  final String userId;
  final String namaToko;
  final String daerah;
  final String noWa;
  final Function(Map<String, dynamic>)? onProductAdded;

  const AddProductScreen({
    super.key,
    required this.userId,
    required this.namaToko,
    required this.daerah,
    required this.noWa,
    this.onProductAdded,
  });

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaProdukController = TextEditingController();
  final _deskripsiController = TextEditingController();
  final _hargaController = TextEditingController();
  final _beratController = TextEditingController(text: '100'); // Default 100 gram

  String? _selectedKategori;
  String? _selectedDaerah;
  bool _isLoading = false;
  bool _isUploading = false;
  int _currentProductCount = 0;
  bool _isCheckingProductCount = true;

  // Image handling - 3 foto
  final List<XFile?> _selectedImages = [null, null, null];
  final List<List<int>?> _selectedImageBytes = [null, null, null];
  final ImagePicker _picker = ImagePicker();

  // Batas ukuran file: 300KB per foto
  static const int maxFileSizeBytes = 300 * 1024; // 300 KB
  // Batas maksimal produk per akun
  static const int maxProductsPerUser = 15;

  // List kategori produk (match dengan PocketBase - tanpa spasi)
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
    _checkProductCount();
  }

  Future<void> _checkProductCount() async {
    try {
      final pb = PocketBaseService.instance;
      final result = await pb.collection(PocketBaseConfig.produkCollection).getList(
        filter: 'sellerid = "${widget.userId}"',
        perPage: 1,
      );
      setState(() {
        _currentProductCount = result.totalItems;
        _isCheckingProductCount = false;
      });
    } catch (e) {
      debugPrint('Error checking product count: $e');
      setState(() {
        _isCheckingProductCount = false;
      });
    }
  }

  @override
  void dispose() {
    _namaProdukController.dispose();
    _deskripsiController.dispose();
    _hargaController.dispose();
    _beratController.dispose();
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
                'Ukuran foto terlalu besar (${(fileSize / 1024).toStringAsFixed(1)} KB).\nMaksimum 300 KB per foto.\n\nSaran: Kompres foto terlebih dahulu.',
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

    // Cek batas produk
    if (_currentProductCount >= maxProductsPerUser) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maksimal $maxProductsPerUser produk per akun.\nHapus produk yang ada untuk menambahkan yang baru.'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    if (_selectedKategori == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih kategori produk'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    // Cek apakah ada minimal 1 foto
    final hasImage = _selectedImages.any((img) => img != null);
    if (!hasImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimal upload 1 foto produk'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final pb = PocketBaseService.instance;

      setState(() => _isUploading = true);

      RecordModel result;

      if (_selectedImages.any((img) => img != null)) {
        // Prepare multipart request - kirim field langsung tanpa jsonEncode
        final uri = Uri.parse('${PocketBaseConfig.pocketBaseUrl}/api/collections/${PocketBaseConfig.produkCollection}/records');
        final request = http.MultipartRequest('POST', uri);

        // Add fields langsung (bukan jsonEncode)
        request.fields['sellerid'] = widget.userId;
        request.fields['namatoko'] = widget.namaToko;
        request.fields['nama'] = _namaProdukController.text.trim();
        request.fields['kategori'] = _selectedKategori ?? '';
        request.fields['deskripsi'] = _deskripsiController.text.trim();
        request.fields['harga'] = (_hargaController.text.trim().isEmpty ? 0 : int.tryParse(_hargaController.text.trim()) ?? 0).toString();
        request.fields['berat'] = (_beratController.text.trim().isEmpty ? 100 : int.tryParse(_beratController.text.trim()) ?? 100).toString();
        request.fields['daerah'] = _selectedDaerah ?? widget.daerah;
        request.fields['nowa'] = widget.noWa;
        // Ownership fields (clone pattern iswara_app, lihat ownership_helper.dart).
        request.fields['created_by'] = widget.userId;
        request.fields['created_by_nowa'] = widget.noWa;

        // Add files - each image for 'gambar' field
        for (int i = 0; i < 3; i++) {
          if (_selectedImageBytes[i] != null) {
            request.files.add(http.MultipartFile.fromBytes(
              'gambar',
              _selectedImageBytes[i]!,
              filename: 'gambar_${i + 1}.jpg',
            ));
          }
        }

        // Send request
        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final json = jsonDecode(response.body);
          result = RecordModel.fromJson(json);
        } else {
          throw Exception('Upload failed: ${response.statusCode} - ${response.body}');
        }
      } else {
        // Tanpa gambar - pakai SDK biasa
        result = await pb.collection(PocketBaseConfig.produkCollection).create(
          body: {
            'sellerid': widget.userId,
            'namatoko': widget.namaToko,
            'nama': _namaProdukController.text.trim(),
            'kategori': _selectedKategori ?? '',
            'deskripsi': _deskripsiController.text.trim(),
            'harga': int.tryParse(_hargaController.text.trim()) ?? 0,
            'berat': int.tryParse(_beratController.text.trim()) ?? 100,
            'daerah': _selectedDaerah ?? widget.daerah,
            'nowa': widget.noWa,
            // Ownership fields (clone pattern iswara_app, lihat ownership_helper.dart).
            'created_by': widget.userId,
            'created_by_nowa': widget.noWa,
          },
        );
      }

      setState(() => _isUploading = false);

      if (!mounted) return;

      // Callback dengan data produk (untuk refresh dashboard)
      final productData = {
        'id': result.id,
        'nama': _namaProdukController.text.trim(),
        'kategori': _selectedKategori,
        'deskripsi': _deskripsiController.text.trim(),
        'harga': _hargaController.text.trim(),
        'daerah': _selectedDaerah ?? widget.daerah,
      };
      widget.onProductAdded?.call(productData);

      // Tampilkan snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Produk berhasil ditambahkan!'),
            backgroundColor: AppTheme.successColor,
            duration: Duration(seconds: 2),
          ),
        );
        // Kembali ke halaman sebelumnya setelah 1 detik
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
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
        title: const Text('Tambah Produk'),
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
              const SizedBox(height: 16),

              // Info Batas Produk
              _buildProductLimitCard(),
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

              // Berat
              TextFormField(
                controller: _beratController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Berat (gram)',
                  hintText: 'Contoh: 500',
                  prefixIcon: Icon(Icons.scale_outlined),
                  helperText: 'Berat dalam gram, contoh: 500 = 500 gram',
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
                              'SIMPAN PRODUK',
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

              // Tips
              _buildTipsCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductLimitCard() {
    if (_isCheckingProductCount) {
      return const SizedBox.shrink();
    }

    final remaining = maxProductsPerUser - _currentProductCount;
    final isAtLimit = remaining <= 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAtLimit ? Colors.orange.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAtLimit ? Colors.orange.shade200 : Colors.blue.shade100,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isAtLimit ? Icons.warning_amber : Icons.info_outline,
            color: isAtLimit ? Colors.orange.shade700 : Colors.blue.shade700,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAtLimit
                      ? 'Batas Maksimal Tercapai'
                      : 'Kuota Produk',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isAtLimit ? Colors.orange.shade800 : Colors.blue.shade800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isAtLimit
                      ? 'Anda telah mencapai batas maksimal $maxProductsPerUser produk. Hapus produk yang ada untuk menambahkan yang baru.'
                      : 'Produk Ditambahkan: $_currentProductCount / $maxProductsPerUser\nSisa Kuota: $remaining produk',
                  style: TextStyle(
                    color: isAtLimit ? Colors.orange.shade700 : Colors.blue.shade700,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
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
              Icons.add_photo_alternate,
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
                  'Tambah Produk Baru',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Upload hingga 3 foto produk',
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
            'Minimal 1 foto, maksimal 3 foto',
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

          // Info Ukuran File
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
                    'Maks. 300 KB per foto. Kompres jika perlu.',
                    style: TextStyle(
                      color: Colors.blue.shade700,
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
    final hasImage = _selectedImages[index] != null;
    final bytes = _selectedImageBytes[index];

    return Expanded(
      child: GestureDetector(
        onTap: () => _showImageSourceDialog(index),
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasImage ? AppTheme.primaryColor : AppTheme.dividerColor,
              width: hasImage ? 2 : 1,
            ),
          ),
          child: hasImage
              ? Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Image.memory(
                        Uint8List.fromList(bytes!),
                        width: double.infinity,
                        height: 120,
                        fit: BoxFit.contain, // Tidak terpotong
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
              : Column(
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
                ),
        ),
      ),
    );
  }

  Widget _buildTipsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.orange.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Tips Foto Produk:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTipItem(Icons.compress, 'Kompres foto jadi 100-200 KB'),
          _buildTipItem(Icons.crop_free, 'Background polos & terang'),
          _buildTipItem(Icons.wb_sunny_outlined, 'Pencahayaan cukup'),
          _buildTipItem(Icons.center_focus_strong, 'Fokuskan pada produk'),
        ],
      ),
    );
  }

  Widget _buildTipItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.orange.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: Colors.orange.shade800,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
