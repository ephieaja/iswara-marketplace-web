import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../config/pocketbase_config.dart';
import '../../services/pocketbase_service.dart';
import '../../providers/cart_provider.dart';
import '../../utils/share_helper.dart';
import 'cart_screen.dart';

class KatalogScreen extends StatefulWidget {
  const KatalogScreen({super.key});

  @override
  State<KatalogScreen> createState() => _KatalogScreenState();
}

class _KatalogScreenState extends State<KatalogScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedKategori;
  String? _selectedDaerah;
  bool _showFilters = false;
  bool _isLoading = true;
  List<RecordModel> _allProducts = [];

  // List kategori
  final List<String> _kategoriList = [
    'Semua',
    'Makanan_dan_Minum',
    'Fashion',
    'Kecantikan_dan_Skincare',
    'Kerajinan_Tangan',
    'Elektronik_dan_Gadget',
    'Hobi',
    'Jasa_dan_Layanan',
    'Travel',
    'Buku',
    'Lainnya',
  ];

  // List daerah
  final List<String> _daerahList = [
    'Semua',
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
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final pb = PocketBaseService.instance;
      final result = await pb.collection(PocketBaseConfig.produkCollection).getList(
        perPage: 200,
      );

      if (mounted) {
        setState(() {
          _allProducts = result.items;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading products: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<RecordModel> get _filteredProducts {
    return _allProducts.where((doc) {
      final data = doc.data;
      final searchQuery = _searchController.text.toLowerCase();

      final matchSearch = searchQuery.isEmpty ||
          (data['nama']?.toString().toLowerCase().contains(searchQuery) ?? false) ||
          (data['NamaToko']?.toString().toLowerCase().contains(searchQuery) ?? false);

      final matchKategori = _selectedKategori == null ||
          _selectedKategori == 'Semua' ||
          data['kategori'] == _selectedKategori;

      final matchDaerah = _selectedDaerah == null ||
          _selectedDaerah == 'Semua' ||
          data['Daerah'] == _selectedDaerah;

      return matchSearch && matchKategori && matchDaerah;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Katalog Produk'),
        actions: [
          // Cart Button
          Consumer<CartProvider>(
            builder: (context, cart, child) {
              return IconButton(
                icon: Badge(
                  isLabelVisible: cart.itemCount > 0,
                  label: Text(
                    cart.itemCount.toString(),
                    style: const TextStyle(fontSize: 10),
                  ),
                  child: const Icon(Icons.shopping_cart),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CartScreen()),
                  );
                },
              );
            },
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: _selectedKategori != null || _selectedDaerah != null,
              child: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list),
            ),
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          _buildSearchBar(),

          // Filter Chips
          if (_showFilters) _buildFilterSection(),

          // Active Filters
          if (_selectedKategori != null || _selectedDaerah != null)
            _buildActiveFilters(),

          // Products Grid
          Expanded(
            child: _buildProductsGrid(),
          ),
        ],
      ),
      // Floating Cart Button
      floatingActionButton: Consumer<CartProvider>(
        builder: (context, cart, child) {
          if (cart.itemCount == 0) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CartScreen()),
              );
            },
            backgroundColor: AppTheme.primaryColor,
            icon: Badge(
              isLabelVisible: true,
              label: Text(
                cart.itemCount.toString(),
                style: const TextStyle(fontSize: 10, color: Colors.white),
              ),
              child: const Icon(Icons.shopping_cart, color: Colors.white),
            ),
            label: Text(
              'Rp ${_formatNumber(cart.totalAmount)}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppTheme.primaryColor,
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Cari produk atau toko...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.7)),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white.withOpacity(0.2),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kategori Filter
          const Text(
            'Kategori',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _kategoriList.length,
              itemBuilder: (context, index) {
                final kategori = _kategoriList[index];
                final isSelected = _selectedKategori == kategori ||
                    (kategori == 'Semua' && _selectedKategori == null);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(kategori),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedKategori = selected && kategori != 'Semua'
                            ? kategori
                            : null;
                      });
                    },
                    backgroundColor: Colors.white,
                    selectedColor: AppTheme.primaryLight.withOpacity(0.2),
                    checkmarkColor: AppTheme.primaryColor,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.dividerColor,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Daerah Filter
          const Text(
            'Daerah',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _daerahList.length,
              itemBuilder: (context, index) {
                final daerah = _daerahList[index];
                final isSelected = _selectedDaerah == daerah ||
                    (daerah == 'Semua' && _selectedDaerah == null);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(daerah),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedDaerah = selected && daerah != 'Semua'
                            ? daerah
                            : null;
                      });
                    },
                    backgroundColor: Colors.white,
                    selectedColor: AppTheme.accentColor.withOpacity(0.2),
                    checkmarkColor: AppTheme.accentColor,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? AppTheme.accentColor
                          : AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? AppTheme.accentColor
                          : AppTheme.dividerColor,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.backgroundColor,
      child: Row(
        children: [
          const Icon(Icons.filter_alt, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Text(
            'Filter aktif: ',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          if (_selectedKategori != null)
            _buildFilterChip(
              label: _selectedKategori!,
              onRemove: () => setState(() => _selectedKategori = null),
              color: AppTheme.primaryColor,
            ),
          if (_selectedDaerah != null) ...[
            const SizedBox(width: 8),
            _buildFilterChip(
              label: _selectedDaerah!,
              onRemove: () => setState(() => _selectedDaerah = null),
              color: AppTheme.accentColor,
            ),
          ],
          const Spacer(),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedKategori = null;
                _selectedDaerah = null;
              });
            },
            child: const Text(
              'Reset',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required VoidCallback onRemove,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 14, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsGrid() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredProducts = _filteredProducts;

    if (filteredProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: AppTheme.textLight,
            ),
            const SizedBox(height: 16),
            const Text(
              'Produk Tidak Ditemukan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Coba ubah kata kunci atau filter Anda',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProducts,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.75,
        ),
        itemCount: filteredProducts.length,
        itemBuilder: (context, index) {
          final product = filteredProducts[index];
          return _ProductGridCard(
            product: product,
            onTap: () => _showProductDetail(product),
          );
        },
      ),
    );
  }

  void _showProductDetail(RecordModel product) {
    final data = product.data;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Product Image
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _buildProductImage(data['gambar'], 200),
                  ),
                ),
                const SizedBox(height: 20),

                // Product Name
                Text(
                  data['nama'] ?? '',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),

                // Kategori Badge
                if (data['harga'] != null && data['harga'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Rp ${_formatNumber((data['harga'] as num?)?.toInt() ?? 0)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    data['kategori'] ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Store Info with WA
                GestureDetector(
                  onTap: () => _openWhatsApp(data['NoWa']),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.successColor.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.successColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.store,
                            color: AppTheme.successColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['NamaToko'] ?? '',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    data['Daerah'] ?? '',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: AppTheme.successColor,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Description
                const Text(
                  'Deskripsi',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  data['deskripsi'] ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),

                // Add to Cart Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () => _addToCart(product),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.shopping_cart, size: 24),
                    label: const Text(
                      'Tambah ke Keranjang',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // WA Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton.icon(
                    onPressed: () => _showInteraksiForm(product),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.successColor,
                      side: const BorderSide(color: AppTheme.successColor, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.chat, size: 24),
                    label: const Text(
                      'Hubungi via WhatsApp',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Share Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ShareHelper.shareProduct(
                        productName: data['nama'] ?? 'Produk',
                        price: _formatNumber((data['harga'] as num?)?.toInt() ?? 0),
                        sellerName: data['NamaToko'] ?? '',
                        daerah: data['Daerah'] ?? '',
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: const BorderSide(color: AppTheme.primaryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.share, size: 20),
                    label: const Text(
                      'Bagikan Produk',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
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

  void _showInteraksiForm(RecordModel product) {
    final namaController = TextEditingController();
    final noHpController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Icon & Title
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chat,
                    color: AppTheme.successColor,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Hubungi Penjual',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Isi data di bawah untuk melanjutkan via WhatsApp',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),

                // Nama Field
                TextFormField(
                  controller: namaController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nama Lengkap',
                    hintText: 'Masukkan nama Anda',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Nama wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // No HP Field
                TextFormField(
                  controller: noHpController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'No. HP / WhatsApp',
                    hintText: 'Contoh: 081234567890',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 8),

                // Info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No. HP opsional, bisa langsung diisi nanti via WA',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Tombol Lanjut
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(context);
                      await _saveInteraksi(
                        product: product,
                        namaPeminat: namaController.text.trim(),
                        noHpPeminat: noHpController.text.trim(),
                        isAnonim: false,
                      );
                      _openWhatsApp(product.data['NoWa']);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat),
                      SizedBox(width: 8),
                      Text(
                        'LANJUT KE WHATSAPP',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Tombol Lewati
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _saveInteraksi(
                      product: product,
                      namaPeminat: null,
                      noHpPeminat: null,
                      isAnonim: true,
                    );
                    _openWhatsApp(product.data['NoWa']);
                  },
                  child: const Text(
                    'LEWATI - Chat Langsung',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveInteraksi({
    required RecordModel product,
    String? namaPeminat,
    String? noHpPeminat,
    required bool isAnonim,
  }) async {
    try {
      final pb = PocketBaseService.instance;
      await pb.collection('interaksi').create(
        body: {
          'idProduk': product.id,
          'namaProduk': product.data['nama'] ?? '',
          'idPenjual': product.data['SellerId'] ?? '',
          'NamaToko': product.data['NamaToko'] ?? '',
          'daerahPenjual': product.data['Daerah'] ?? '',
          'namaPeminat': namaPeminat,
          'noHpPeminat': noHpPeminat,
          'isAnonim': isAnonim,
          'status': 'pending',
        },
      );
    } catch (e) {
      // Silent fail - don't interrupt user flow
      debugPrint('Error saving interaksi: $e');
    }
  }

  void _openWhatsApp(String? noWa) async {
    if (noWa == null || noWa.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nomor WhatsApp tidak tersedia'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Format nomor WA (hapus karakter non-angka)
    String formattedNumber = noWa.replaceAll(RegExp(r'[^\d]'), '');
    if (formattedNumber.startsWith('0')) {
      formattedNumber = '62${formattedNumber.substring(1)}';
    }

    final url = Uri.parse('https://wa.me/$formattedNumber');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak dapat membuka WhatsApp'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _addToCart(RecordModel product) {
    final cart = context.read<CartProvider>();
    final data = product.data;

    // Get harga, default to 0 if not set
    int harga = 0;
    if (data['harga'] != null) {
      harga = (data['harga'] as num?)?.toInt() ?? 0;
    }

    final cartItem = CartItem(
      productId: product.id,
      productName: data['nama'] ?? '',
      productImage: data['gambar']?.toString() ?? '',
      price: harga,
      sellerId: data['SellerId'] ?? '',
      sellerName: data['NamaToko'] ?? '',
      sellerWa: data['NoWa']?.toString() ?? '',
      daerah: data['Daerah'] ?? '',
    );

    cart.addItem(cartItem);

    // Show success snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text('${data['nama']} ditambahkan ke keranjang'),
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'LIHAT',
          textColor: Colors.white,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CartScreen()),
            );
          },
        ),
      ),
    );

    // Close bottom sheet
    Navigator.pop(context);
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}Jt';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(0)}Rb';
    }
    return number.toString();
  }

  /// Helper untuk menampilkan gambar produk dengan fallback
  Widget _buildProductImage(dynamic fotoUrl, [double? height]) {
    final url = fotoUrl?.toString();
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: height ?? 200,
        placeholder: (context, url) => SizedBox(
          height: height ?? 200,
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (context, url, error) => SizedBox(
          height: height ?? 200,
          child: const Center(
            child: Icon(Icons.broken_image, size: 64, color: AppTheme.textLight),
          ),
        ),
      );
    }
    return SizedBox(
      height: height ?? 200,
      child: const Center(
        child: Icon(Icons.image, size: 64, color: AppTheme.textLight),
      ),
    );
  }
}

class _ProductGridCard extends StatelessWidget {
  final RecordModel product;
  final VoidCallback onTap;

  const _ProductGridCard({
    required this.product,
    required this.onTap,
  });

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}Jt';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(0)}Rb';
    }
    return number.toString();
  }

  /// Helper untuk menampilkan gambar di grid card
  Widget _buildGridImage(dynamic fotoUrl) {
    final url = fotoUrl?.toString();
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (context, url, error) => const Center(
          child: Icon(Icons.broken_image, size: 48, color: AppTheme.textLight),
        ),
      );
    }
    return const Center(
      child: Icon(Icons.image, size: 48, color: AppTheme.textLight),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = product.data;
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
            // Image
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: _buildGridImage(data['gambar']),
                ),
              ),
            ),
            // Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['nama'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (data['harga'] != null && data['harga'].toString().isNotEmpty)
                      Text(
                        'Rp ${_formatNumber((data['harga'] as num?)?.toInt() ?? 0)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.store,
                          size: 12,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            data['NamaToko'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 11,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 2),
                        Text(
                          data['Daerah'] ?? '',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            Icons.chat,
                            size: 12,
                            color: AppTheme.accentColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
