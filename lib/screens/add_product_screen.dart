import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

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

  String? _selectedKategori;
  String? _selectedDaerah;
  bool _isLoading = false;
  bool _isUploading = false;

  // Image handling
  File? _selectedImage;
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

  // List daerah (sama seperti registration)
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
        maxWidth: 600, // Resize untuk ukuran kecil
        maxHeight: 600,
        imageQuality: 50, // Compress lebih kuat
      );

      if (image != null) {
        // Cek ukuran file
        final fileSize = await File(image.path).length();

        if (fileSize > maxFileSizeBytes) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Ukuran file terlalu besar (${(fileSize / 1024).toStringAsFixed(1)} KB).\nMaksimum 300 KB.\n\nSaran: Kompres foto terlebih dahulu.',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
          return;
        }

        setState(() {
          _selectedImage = File(image.path);
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
        'SellerId': widget.userId,
        'NamaToko': widget.namaToko,
        'Nama': _namaProdukController.text.trim(),
        'Kategori': _selectedKategori,
        'Deskripsi': _deskripsiController.text.trim(),
        'Harga': int.tryParse(_hargaController.text.trim()) ?? 0,
        'Daerah': _selectedDaerah ?? widget.daerah,
        'NoWa': widget.noWa,
      };

      // Upload gambar dulu jika ada
      if (_selectedImage != null) {
        setState(() => _isUploading = true);

        final multipartFile = await http.MultipartFile.fromPath(
          'gambar',
          _selectedImage!.path,
        );

        final result = await pb.collection(PocketBaseConfig.produkCollection).create(
          body: data,
          files: [multipartFile],
        );

        setState(() => _isUploading = false);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Produk berhasil ditambahkan!'),
            backgroundColor: AppTheme.successColor,
          ),
        );

        final product = {
          'id': result.id,
          'nama': _namaProdukController.text.trim(),
          'kategori': _selectedKategori,
          'deskripsi': _deskripsiController.text.trim(),
          'harga': _hargaController.text.trim(),
          'Daerah': _selectedDaerah ?? widget.daerah,
          'gambar': result.data['gambar'] ?? '',
        };

        widget.onProductAdded?.call(product);
      } else {
        // Tanpa gambar
        final result = await pb.collection(PocketBaseConfig.produkCollection).create(
          body: data,
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Produk berhasil ditambahkan!'),
            backgroundColor: AppTheme.successColor,
          ),
        );

        final product = {
          'id': result.id,
          'nama': _namaProdukController.text.trim(),
          'kategori': _selectedKategori,
          'deskripsi': _deskripsiController.text.trim(),
          'harga': _hargaController.text.trim(),
          'Daerah': _selectedDaerah ?? widget.daerah,
        };

        widget.onProductAdded?.call(product);
      }

      // Clear form
      _formKey.currentState!.reset();
      _namaProdukController.clear();
      _deskripsiController.clear();
      _hargaController.clear();
      setState(() {
        _selectedKategori = null;
        _selectedDaerah = null;
        _selectedImage = null;
      });

      if (!mounted) return;
      setState(() => _isLoading = false);
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
                  'Lengkapi data produk Anda dengan lengkap',
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
                    : null,
              ),
              child: _selectedImage == null
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

          // Info Ukuran File
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Ukuran Maksimal: 300 KB',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Saran: Kompres foto terlebih dahulu\nke ukuran 100-200 KB.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Info ukuran file
          if (_selectedImage != null)
            FutureBuilder<int>(
              future: _selectedImage!.length(),
              builder: (context, snapshot) {
                final sizeKB = snapshot.hasData
                    ? (snapshot.data! / 1024).toStringAsFixed(1)
                    : '-';
                final isTooBig = snapshot.hasData && snapshot.data! > maxFileSizeBytes;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isTooBig ? Colors.red.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isTooBig ? Colors.red.shade200 : Colors.green.shade200,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isTooBig ? Icons.error_outline : Icons.check_circle,
                        color: isTooBig ? Colors.red.shade700 : Colors.green.shade700,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Ukuran: $sizeKB KB ${isTooBig ? "(Terlalu Besar!)" : "(OK - < 300KB)"}',
                        style: TextStyle(
                          color: isTooBig ? Colors.red.shade700 : Colors.green.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

          const SizedBox(height: 12),

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

          // Tombol hapus foto
          if (_selectedImage != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => setState(() {
                _selectedImage = null;
              }),
              icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
              label: const Text(
                'Hapus Foto',
                style: TextStyle(color: AppTheme.errorColor),
              ),
            ),
          ],
        ],
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
          _buildTipItem(Icons.compress, 'Kompres foto jadi 100-200 KB\n(App: Photo & Picture Resizer)'),
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
