import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../config/pocketbase_config.dart';
import '../../services/pocketbase_service.dart';
import '../../services/visitor_service.dart';
import '../../providers/cart_provider.dart';
import '../../utils/share_helper.dart';
import 'cart_screen.dart';

/// Helper untuk mendapatkan URL lengkap gambar dari PocketBase (single image).
///
/// PERUBAHAN 14 Agt 2026 (Fase 1):
/// - Tambah parameter `collectionName` untuk support Produk + ProdukMarketplace.
/// - Default ke `produkCollection` untuk backward compat dengan data existing.
String _getImageUrl(dynamic imageField, String recordId, {String? collectionName}) {
  if (imageField == null || imageField.toString().isEmpty) {
    return '';
  }

  final value = imageField.toString();

  if (value.isEmpty) {
    return '';
  }

  if (value.startsWith('http') &&
      !value.contains('vercel.app') &&
      !value.contains('localhost')) {
    return value;
  }

  final filename = value.split('/').last;
  final coll = collectionName ?? PocketBaseConfig.produkCollection;
  return '${PocketBaseConfig.pocketBaseUrl}/api/files/$coll/$recordId/$filename';
}

/// Helper untuk mendapatkan URL gambar dari list (multiple images)
List<String> _getImageUrls(dynamic imageField, String recordId, {String? collectionName}) {
  final urls = <String>[];

  if (imageField == null) {
    return urls;
  }

  // Handle List
  if (imageField is List) {
    for (var item in imageField) {
      if (item != null && item.toString().isNotEmpty) {
        final url = _getImageUrl(item, recordId, collectionName: collectionName);
        if (url.isNotEmpty) urls.add(url);
      }
    }
  }
  // Handle single value
  else if (imageField.toString().isNotEmpty) {
    final url = _getImageUrl(imageField, recordId, collectionName: collectionName);
    if (url.isNotEmpty) urls.add(url);
  }

  return urls;
}

/// Helper untuk mendapatkan URL gambar dari field terpisah (gambar1, gambar2, gambar3)
List<String> _getImageUrlsFromFields(Map<String, dynamic> data, String recordId, {String? collectionName}) {
  final urls = <String>[];

  // Cek field 'gambar' sebagai array
  if (data.containsKey('gambar')) {
    final gambar = data['gambar'];
    if (gambar is List) {
      for (var item in gambar) {
        if (item != null && item.toString().isNotEmpty) {
          final url = _getImageUrl(item, recordId, collectionName: collectionName);
          if (url.isNotEmpty && !urls.contains(url)) {
            urls.add(url);
          }
        }
      }
    } else if (gambar != null && gambar.toString().isNotEmpty) {
      final url = _getImageUrl(gambar, recordId, collectionName: collectionName);
      if (url.isNotEmpty && !urls.contains(url)) {
        urls.add(url);
      }
    }
  }

  // Cek field terpisah
  final fieldNames = ['gambar1', 'gambar2', 'gambar3'];
  for (final field in fieldNames) {
    if (data.containsKey(field) && data[field] != null && data[field].toString().isNotEmpty) {
      final url = _getImageUrl(data[field], recordId, collectionName: collectionName);
      if (url.isNotEmpty && !urls.contains(url)) {
        urls.add(url);
      }
    }
  }

  return urls;
}

class KatalogScreen extends StatefulWidget {
  const KatalogScreen({super.key});

  @override
  State<KatalogScreen> createState() => _KatalogScreenState();
}

class _KatalogScreenState extends State<KatalogScreen> with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedKategori;
  String? _selectedDaerah;
  bool _showFilters = false;
  bool _isLoading = true;
  List<RecordModel> _allProducts = [];

  /// Map recordId → nama collection ('produkCollection' atau 'produkMarketplaceCollection').
  /// Dipakai untuk konstruk URL gambar yang benar di kartu/detail produk.
  /// Fase 1: ProdukMarketplace URL path berbeda dari Produk legacy.
  final Map<String, String> _productCollection = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadProducts();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      _loadProducts();
    }
  }

  // List kategori (match dengan PocketBase - tanpa spasi)
  final List<String> _kategoriList = [
    'Semua',
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

  Future<void> _loadProducts() async {
    try {
      final pb = PocketBaseService.instance;

      // UNION query (Fase 1): Produk (legacy, anggota ISWARA) + ProdukMarketplace (non-anggota).
      final semua = <RecordModel>[];
      final collMap = <String, String>{};

      // Query Produk (legacy) — anggota ISWARA via auto-sync
      try {
        final produkResult = await pb
            .collection(PocketBaseConfig.produkCollection)
            .getList(
              perPage: 200,
              sort: '-created',
            );
        for (final r in produkResult.items) {
          semua.add(r);
          collMap[r.id] = PocketBaseConfig.produkCollection;
        }
      } catch (e) {
        debugPrint('Error loading Produk: $e');
      }

      // Query ProdukMarketplace (Fase 1, non-anggota), filter status='aktif'
      try {
        final mpResult = await pb
            .collection(PocketBaseConfig.produkMarketplaceCollection)
            .getList(
              perPage: 200,
              sort: '-created',
              filter: 'status = "aktif"',
            );
        for (final r in mpResult.items) {
          semua.add(r);
          collMap[r.id] = PocketBaseConfig.produkMarketplaceCollection;
        }
      } catch (e) {
        debugPrint('Error loading ProdukMarketplace: $e');
      }

      // Sort by created desc (combine)
      semua.sort((a, b) => b.created.compareTo(a.created));

      if (mounted) {
        setState(() {
          _allProducts = semua;
          _productCollection
            ..clear()
            ..addAll(collMap);
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

  Future<Map<String, dynamic>> _loadSellerData(RecordModel product) async {
    final data = product.data;

    // Deteksi source produk (Fase 1)
    // - Produk (legacy): field `sellerid` (string user id)
    // - ProdukMarketplace: field `seller` (relation id ke SellersMarketplace)
    final isMarketplace = _productCollection[product.id] ==
        PocketBaseConfig.produkMarketplaceCollection;

    String? sellerId;
    if (isMarketplace) {
      // ProdukMarketplace: ambil record SellersMarketplace → field `user`
      final sellerRelId = data['seller']?.toString();
      if (sellerRelId == null || sellerRelId.isEmpty) {
        return {};
      }
      try {
        final pb = PocketBaseService.instance;
        final sellerRecord = await pb
            .collection(PocketBaseConfig.sellersMarketplaceCollection)
            .getOne(sellerRelId);
        sellerId = sellerRecord.data['user']?.toString();
      } catch (e) {
        debugPrint('Error loading SellersMarketplace: $e');
        return {'nowa': data['nowa'] ?? ''};
      }
    } else {
      sellerId = data['sellerid']?.toString();
    }

    if (sellerId == null || sellerId.isEmpty) {
      return {};
    }

    try {
      final pb = PocketBaseService.instance;

      // Safely check auth store
      RecordModel? authRecord;
      try {
        if (pb.authStore.isValid) {
          authRecord = pb.authStore.record;
        }
      } catch (e) {
        debugPrint('Error accessing authStore: $e');
      }

      // If user is logged in and is this seller, return from auth store
      if (authRecord != null && authRecord.id == sellerId) {
        final authData = authRecord.data;
        // Merge with product data to ensure nowa is available
        return {
          ...authData,
          'nowa': authData['phone'] ?? authData['nowa'] ?? data['nowa'] ?? '',
        };
      }

      // Otherwise fetch from server
      // Untuk marketplace seller: pakai `users_auth` collection
      // Untuk legacy: pakai `users` collection
      final collectionName = isMarketplace
          ? PocketBaseConfig.usersAuthCollection
          : 'users';
      final seller = await pb.collection(collectionName).getOne(sellerId);
      final sellerData = seller.data;
      // Ensure nowa is available (phone untuk users_auth, nowa untuk users legacy)
      return {
        ...sellerData,
        'nowa': sellerData['phone'] ?? sellerData['nowa'] ?? data['nowa'] ?? '',
      };
    } catch (e) {
      debugPrint('Error loading seller data: $e');
      // Return product data as fallback
      return {
        'nowa': data['nowa'] ?? '',
        'instagram': data['instagram'],
        'facebook': data['facebook'],
        'tiktok': data['tiktok'],
        'website': data['website'],
      };
    }
  }

  List<RecordModel> get _filteredProducts {
    return _allProducts.where((doc) {
      final data = doc.data;
      final searchQuery = _searchController.text.toLowerCase();

      final matchSearch = searchQuery.isEmpty ||
          (data['nama']?.toString().toLowerCase().contains(searchQuery) ?? false) ||
          (data['namatoko']?.toString().toLowerCase().contains(searchQuery) ?? false);

      final matchKategori = _selectedKategori == null ||
          _selectedKategori == 'Semua' ||
          data['kategori'] == _selectedKategori;

      final matchDaerah = _selectedDaerah == null ||
          _selectedDaerah == 'Semua' ||
          data['daerah'] == _selectedDaerah;

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
            collectionName: _productCollection[product.id],
          );
        },
      ),
    );
  }

  void _showProductDetail(RecordModel product) {
    final data = product.data;

    // Tampilkan bottom sheet dengan loading state, lalu load data penjual
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _ProductDetailSheet(
        product: product,
        loadSellerData: _loadSellerData,
        onAddToCart: () => _addToCart(product),
        onContactWhatsApp: (sellerWa) => _showInteraksiForm(product, sellerWa: sellerWa),
        onShare: () => ShareHelper.shareProduct(
          productName: data['nama'] ?? 'Produk',
          price: _formatNumber((data['harga'] as num?)?.toInt() ?? 0),
          sellerName: data['namatoko'] ?? '',
          daerah: data['daerah'] ?? '',
        ),
        formatNumber: _formatNumber,
        collectionName: _productCollection[product.id],
      ),
    );
  }

  void _showInteraksiForm(RecordModel product, {String? sellerWa}) {
    final pb = PocketBaseService.instance;
    final isLoggedIn = pb.authStore.isValid;

    // Jika sudah login, langsung ke WA
    if (isLoggedIn) {
      _saveInteraksi(product: product);
      _openWhatsApp(sellerWa);
      return;
    }

    // Cek visitor yang sudah ada
    _checkAndProceedToWa(product, sellerWa: sellerWa);
  }

  Future<void> _checkAndProceedToWa(RecordModel product, {String? sellerWa}) async {
    try {
      // Cek apakah visitor sudah ada
      final existingVisitor = await VisitorService.getExistingVisitor();

      if (existingVisitor != null) {
        // Visitor sudah ada, tampilkan form sederhana (no wa saja)
        if (mounted) {
          _showVisitorFormExisting(product, sellerWa: sellerWa, existingVisitor: existingVisitor);
        }
      } else {
        // Visitor baru, tampilkan form lengkap
        if (mounted) {
          _showVisitorFormNew(product, sellerWa: sellerWa);
        }
      }
    } catch (e) {
      debugPrint('Error checking visitor: $e');
      // Fallback: tampilkan form baru
      if (mounted) {
        _showVisitorFormNew(product, sellerWa: sellerWa);
      }
    }
  }

  /// Form untuk pengunjung BARU (lengkap)
  void _showVisitorFormNew(RecordModel product, {String? sellerWa}) {
    final namaController = TextEditingController();
    final nohapeController = TextEditingController();
    String? selectedOrganisasi;
    bool isAnggota = false;
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
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
                      'Isi data Anda untuk melanjutkan via WhatsApp',
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

                    // No. HP Field
                    TextFormField(
                      controller: nohapeController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'No. HP / WhatsApp',
                        hintText: 'Contoh: 081234567890',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'No. HP wajib diisi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Anggota Persyarikatan?
                    const Text(
                      'Anggota Persyarikatan?',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('Ya'),
                            value: true,
                            groupValue: isAnggota,
                            onChanged: (v) {
                              setModalState(() => isAnggota = v!);
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('Tidak'),
                            value: false,
                            groupValue: isAnggota,
                            onChanged: (v) {
                              setModalState(() => isAnggota = v!);
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),

                    // Organisasi dropdown (if anggota)
                    if (isAnggota) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Organisasi',
                          prefixIcon: Icon(Icons.groups_outlined),
                        ),
                        items: VisitorService.organisasiList.map((org) {
                          return DropdownMenuItem(value: org, child: Text(org));
                        }).toList(),
                        onChanged: (value) {
                          selectedOrganisasi = value;
                        },
                        validator: isAnggota
                            ? (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Pilih organisasi';
                                }
                                return null;
                              }
                            : null,
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Tombol Lanjut
                    ElevatedButton(
                      onPressed: () async {
                        if (formKey.currentState!.validate()) {
                          Navigator.pop(context);

                          // Simpan visitor
                          final visitor = await VisitorService.createVisitor(
                            nohape: nohapeController.text.trim(),
                            nama: namaController.text.trim(),
                            notelp: nohapeController.text.trim(),
                            isAnggota: isAnggota,
                            organisasi: isAnggota ? selectedOrganisasi : null,
                          );

                          // Simpan interaksi
                          await _saveInteraksi(
                            product: product,
                            visitorId: visitor?.id,
                          );

                          if (mounted) {
                            _openWhatsApp(sellerWa);
                          }
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Form untuk pengunjung LAMA (hanya no wa)
  void _showVisitorFormExisting(RecordModel product, {String? sellerWa, RecordModel? existingVisitor}) {
    final nohapeController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
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
                    'Verifikasi No. WhatsApp',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Masukkan no. WhatsApp Anda untuk melanjutkan',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // No. HP Field
                  TextFormField(
                    controller: nohapeController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'No. WhatsApp',
                      hintText: 'Contoh: 081234567890',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'No. WhatsApp wajib diisi';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Tombol Lanjut
                  ElevatedButton(
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        final inputNo = nohapeController.text.trim();

                        // Cek apakah no wa cocok dengan data visitor
                        if (existingVisitor != null) {
                          final storedNo = existingVisitor.data['nohape']?.toString() ?? '';

                          // Normalisasi untuk comparison
                          final normalizeNo = (String no) => no.replaceAll(RegExp(r'[^\d]'), '');
                          final storedNoNormalized = normalizeNo(storedNo);
                          final inputNoNormalized = normalizeNo(inputNo);

                          if (storedNoNormalized == inputNoNormalized) {
                            // No wa cocok, lanjut ke WA
                            Navigator.pop(context);

                            // Simpan interaksi
                            await _saveInteraksi(
                              product: product,
                              visitorId: existingVisitor.id,
                            );

                            if (mounted) {
                              _openWhatsApp(sellerWa);
                            }
                          } else {
                            // No wa tidak cocok
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('No. WhatsApp tidak cocok dengan data Anda'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } else {
                          // Tidak ada existing visitor, buat baru
                          Navigator.pop(context);
                          await _saveInteraksi(
                            product: product,
                            visitorId: existingVisitor?.id,
                          );
                          if (mounted) {
                            _openWhatsApp(sellerWa);
                          }
                        }
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveInteraksi({
    required RecordModel product,
    String? visitorId,
  }) async {
    try {
      final pb = PocketBaseService.instance;

      // Safely check if user is logged in
      bool isLoggedIn = false;
      String? namapeminat;
      String? nohppeminat;
      bool isAnonim = true;

      try {
        isLoggedIn = pb.authStore.isValid;
      } catch (e) {
        debugPrint('Error checking auth: $e');
      }

      if (isLoggedIn) {
        try {
          final record = pb.authStore.record;
          if (record != null) {
            // User logged in
            namapeminat = record.data['name'] ?? '';
            nohppeminat = record.data['nowa'] ?? '';
            isAnonim = false;
          }
        } catch (e) {
          debugPrint('Error accessing auth record: $e');
        }
      } else if (visitorId != null) {
        // Visitor from Visitors collection
        try {
          final visitor = await VisitorService.getVisitorById(visitorId);
          if (visitor != null) {
            namapeminat = visitor.data['nama'] ?? '';
            nohppeminat = visitor.data['nohape'] ?? '';
            isAnonim = false;
          }
        } catch (e) {
          debugPrint('Error getting visitor for interaksi: $e');
        }
      }

      await pb.collection('Interaksi').create(
        body: {
          'idproduk': product.id,
          'namaproduk': product.data['nama'] ?? '',
          'idpenjual': product.data['sellerid'] ?? '',
          'namatoko': product.data['namatoko'] ?? '',
          'daerahpenjual': product.data['daerah'] ?? '',
          'namapeminat': namapeminat,
          'nohppeminat': nohppeminat,
          'isanonim': isAnonim,
          'status': 'Pending',
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

    // Langsung buka WhatsApp
    _launchWhatsApp(noWa);
  }

  void _launchWhatsApp(String noWa) async {
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

  bool _hasSocialMedia(Map<String, dynamic> data) {
    return (data['instagram'] != null && data['instagram'].toString().isNotEmpty) ||
        (data['facebook'] != null && data['facebook'].toString().isNotEmpty) ||
        (data['tiktok'] != null && data['tiktok'].toString().isNotEmpty) ||
        (data['website'] != null && data['website'].toString().isNotEmpty);
  }

  Widget _buildSocialButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }

  void _openSocialLink(String type, String value) async {
    String url;

    switch (type) {
      case 'instagram':
        // Format: https://instagram.com/username
        if (value.startsWith('http')) {
          url = value;
        } else {
          url = 'https://instagram.com/$value';
        }
        break;
      case 'facebook':
        // Format: https://facebook.com/page atau full URL
        if (value.startsWith('http')) {
          url = value;
        } else {
          url = 'https://facebook.com/search/top?q=$value';
        }
        break;
      case 'tiktok':
        // Format: https://tiktok.com/@username
        if (value.startsWith('http')) {
          url = value;
        } else {
          url = 'https://tiktok.com/@$value';
        }
        break;
      case 'website':
        if (!value.startsWith('http')) {
          url = 'https://$value';
        } else {
          url = value;
        }
        break;
      default:
        return;
    }

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tidak dapat membuka $type'),
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

  Future<Map<String, dynamic>?> _showVisitorFormDialog() async {
    final nohapeController = TextEditingController();
    final namaController = TextEditingController();
    final notelpController = TextEditingController();
    bool isAnggota = false;
    String? selectedOrganisasi;

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.person_add, color: AppTheme.primaryColor),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Data Pengunjung',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Silakan isi data Anda untuk melanjutkan chat via WhatsApp:',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),

                // No. HP
                TextField(
                  controller: nohapeController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'No. HP/WhatsApp *',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // Nama
                TextField(
                  controller: namaController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nama Lengkap *',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // No. Telepon (alternatif)
                TextField(
                  controller: notelpController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'No. Telepon Alternatif',
                    prefixIcon: Icon(Icons.phone_android),
                    border: OutlineInputBorder(),
                    hintText: 'Opsional',
                  ),
                ),
                const SizedBox(height: 16),

                // Anggota?
                SwitchListTile(
                  title: const Text('Anggota Muhammadiyah/Aisyiyah?'),
                  value: isAnggota,
                  onChanged: (v) => setState(() => isAnggota = v),
                  contentPadding: EdgeInsets.zero,
                ),

                // Organisasi (if anggota)
                if (isAnggota) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedOrganisasi,
                    decoration: const InputDecoration(
                      labelText: 'Organisasi',
                      prefixIcon: Icon(Icons.groups),
                      border: OutlineInputBorder(),
                    ),
                    items: VisitorService.organisasiList.map((org) {
                      return DropdownMenuItem(value: org, child: Text(org));
                    }).toList(),
                    onChanged: (v) => setState(() => selectedOrganisasi = v),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('BATAL'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Validasi
                if (nohapeController.text.trim().isEmpty ||
                    namaController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No. HP dan Nama wajib diisi'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                // Simpan visitor
                try {
                  final visitor = await VisitorService.createVisitor(
                    nohape: nohapeController.text.trim(),
                    nama: namaController.text.trim(),
                    notelp: notelpController.text.trim(),
                    isAnggota: isAnggota,
                    organisasi: selectedOrganisasi,
                  );

                  if (visitor != null) {
                    if (!context.mounted) return;
                    Navigator.pop(context, {
                      'nama': namaController.text.trim(),
                      'nohape': nohapeController.text.trim(),
                      'isAnggota': isAnggota,
                    });
                  } else {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Gagal menyimpan data'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              child: const Text('SIMPAN & CHAT'),
            ),
          ],
        ),
      ),
    );
  }

  void _addToCart(RecordModel product) {
    final cart = context.read<CartProvider>();
    final data = product.data;

    // Get harga, default to 0 if not set
    int harga = 0;
    if (data['harga'] != null) {
      harga = (data['harga'] as num?)?.toInt() ?? 0;
    }

    // Get berat, default to 100 gram if not set
    int berat = 100;
    if (data['berat'] != null) {
      berat = (data['berat'] as num?)?.toInt() ?? 100;
    }

    // Get image URLs
    final collName = _productCollection[product.id];
    final imageUrls = _getImageUrlsFromFields(data, product.id, collectionName: collName);
    final firstImageUrl = imageUrls.isNotEmpty ? imageUrls.first : '';

    final cartItem = CartItem(
      productId: product.id,
      productName: data['nama'] ?? '',
      productImage: firstImageUrl, // Use full URL from image helper
      price: harga,
      berat: berat,
      // Fase 1: Untuk ProdukMarketplace, `seller` field = SellersMarketplace record id.
      // Untuk Produk legacy, `sellerid` = users record id.
      // CartProvider.itemsBySeller grouping jalan regardless.
      sellerId: data['seller']?.toString() ??
          data['sellerid']?.toString() ??
          '',
      sellerName: data['namatoko'] ?? '',
      sellerWa: data['nowa']?.toString() ?? '',
      daerah: data['daerah'] ?? '',
      // Varian fields (clone pattern diskusi 8 Agt 2026)
      // Untuk sekarang, dari katalog belum pilih varian (default).
      // Variant selection ada di product detail screen (TODO).
      variantLabel: data['varian_label']?.toString() ?? '',
      variantName: '', // Default: tidak pilih varian
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

    // Bottom sheet sudah ditutup oleh _ProductDetailSheet, tidak perlu pop lagi
  }

  String _formatNumber(int number) {
    // Format Indonesia: ribuan pakai titik, contoh: 20.000
    final str = number.toString();
    final buffer = StringBuffer();
    final length = str.length;

    for (int i = 0; i < length; i++) {
      if (i > 0 && (length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }

    return buffer.toString();
  }
}

/// Grid image widget dengan page indicator untuk multiple images
class _GridImageWidget extends StatefulWidget {
  final List<String> imageUrls;
  final String productId;

  const _GridImageWidget({
    required this.imageUrls,
    required this.productId,
  });

  @override
  State<_GridImageWidget> createState() => _GridImageWidgetState();
}

class _GridImageWidgetState extends State<_GridImageWidget> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return const Center(
        child: Icon(Icons.image, size: 48, color: AppTheme.textLight),
      );
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemCount: widget.imageUrls.length,
            itemBuilder: (context, index) {
              return CachedNetworkImage(
                imageUrl: widget.imageUrls[index],
                fit: BoxFit.contain, // Changed to prevent cropping
                width: double.infinity,
                height: double.infinity,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(Icons.broken_image, size: 48, color: AppTheme.textLight),
                ),
              );
            },
          ),
        ),
        // Page indicator
        if (widget.imageUrls.length > 1)
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.photo, size: 10, color: Colors.white),
                  const SizedBox(width: 2),
                  Text(
                    '${_currentPage + 1}/${widget.imageUrls.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ProductGridCard extends StatelessWidget {
  final RecordModel product;
  final VoidCallback onTap;

  /// Nama collection record ini (Fase 1: 'Produk' atau 'ProdukMarketplace').
  /// Dipakai untuk konstruk URL file gambar yang benar.
  final String? collectionName;

  const _ProductGridCard({
    required this.product,
    required this.onTap,
    this.collectionName,
  });

  String _formatNumber(int number) {
    // Format Indonesia: ribuan pakai titik, contoh: 20.000
    final str = number.toString();
    final buffer = StringBuffer();
    final length = str.length;

    for (int i = 0; i < length; i++) {
      if (i > 0 && (length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final data = product.data;
    // Cek berbagai kemungkinan nama field gambar
    final imageUrls = _getImageUrlsFromFields(data, product.id, collectionName: collectionName);

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
            // Image dengan indicator
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
                child: _GridImageWidget(
                  imageUrls: imageUrls,
                  productId: product.id,
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
                    // Harga display (clone pattern diskusi 8 Agt 2026)
                    // - Tanpa varian: tampil harga utama biasa
                    // - Dengan varian: tampil "Mulai dari Rp X.XXX"
                    if (data['harga'] != null && data['harga'].toString().isNotEmpty) ...[
                      // Cek apakah ada varian_list
                      Builder(
                        builder: (context) {
                          final rawVarianList = data['varian_list'];
                          final hasVariants = rawVarianList is List && rawVarianList.isNotEmpty;

                          if (hasVariants) {
                            // Hitung harga termurah dari varian
                            int minHarga = (data['harga'] as num?)?.toInt() ?? 0;
                            for (final v in rawVarianList) {
                              if (v is Map && v['harga'] != null) {
                                final vh = (v['harga'] as num?)?.toInt() ?? 0;
                                if (vh > 0 && (minHarga == 0 || vh < minHarga)) {
                                  minHarga = vh;
                                }
                              }
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mulai dari',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  'Rp ${_formatNumber(minHarga)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ],
                            );
                          }
                          return Text(
                            'Rp ${_formatNumber((data['harga'] as num?)?.toInt() ?? 0)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          );
                        },
                      ),
                    ],
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
                            data['namatoko'] ?? '',
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
                          data['daerah'] ?? '',
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

/// Carousel widget untuk menampilkan multiple foto produk (digunakan di detail dan grid)
class _ProductImageCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final double height;

  const _ProductImageCarousel({
    required this.imageUrls,
    this.height = 200,
  });

  @override
  State<_ProductImageCarousel> createState() => _ProductImageCarouselState();
}

class _ProductImageCarouselState extends State<_ProductImageCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return _buildNoImagePlaceholder();
    }

    return Column(
      children: [
        // Image Carousel
        Container(
          height: widget.height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemCount: widget.imageUrls.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => _showFullScreenImage(context, widget.imageUrls, index),
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: CachedNetworkImage(
                      imageUrl: widget.imageUrls[index],
                      height: widget.height,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => Center(
                        child: SizedBox(
                          height: widget.height,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => _buildNoImagePlaceholder(),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        // Page Indicators
        if (widget.imageUrls.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.imageUrls.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? AppTheme.primaryColor
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showFullScreenImage(BuildContext context, List<String> imageUrls, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullScreenImageViewer(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Widget _buildNoImagePlaceholder() {
    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image, size: 48, color: AppTheme.textLight),
            const SizedBox(height: 8),
            Text(
              'Tidak ada gambar',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget untuk menampilkan detail produk dengan data penjual
class _ProductDetailSheet extends StatefulWidget {
  final RecordModel product;
  final Future<Map<String, dynamic>> Function(RecordModel product) loadSellerData;
  final VoidCallback onAddToCart;
  final void Function(String? sellerWa) onContactWhatsApp;
  final VoidCallback onShare;
  final String Function(int number) formatNumber;

  /// Nama collection record ini (Fase 1: 'Produk' atau 'ProdukMarketplace').
  final String? collectionName;

  const _ProductDetailSheet({
    required this.product,
    required this.loadSellerData,
    required this.onAddToCart,
    required this.onContactWhatsApp,
    required this.onShare,
    required this.formatNumber,
    this.collectionName,
  });

  @override
  State<_ProductDetailSheet> createState() => _ProductDetailSheetState();
}

class _ProductDetailSheetState extends State<_ProductDetailSheet> {
  Map<String, dynamic> _sellerData = {};
  bool _isLoadingSeller = true;

  @override
  void initState() {
    super.initState();
    _loadSeller();
  }

  Future<void> _loadSeller() async {
    try {
      final data = await widget.loadSellerData(widget.product);
      if (mounted) {
        setState(() {
          _sellerData = data;
          _isLoadingSeller = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading seller: $e');
      if (mounted) {
        setState(() {
          _sellerData = {};
          _isLoadingSeller = false;
        });
      }
    }
  }

  bool _hasSocialMedia() {
    return (_sellerData['instagram'] != null && _sellerData['instagram'].toString().isNotEmpty) ||
        (_sellerData['facebook'] != null && _sellerData['facebook'].toString().isNotEmpty) ||
        (_sellerData['tiktok'] != null && _sellerData['tiktok'].toString().isNotEmpty) ||
        (_sellerData['website'] != null && _sellerData['website'].toString().isNotEmpty);
  }

  /// Show seller detail in a popup/bottom sheet
  void _showSellerDetailSheet(BuildContext context, Map<String, dynamic> productData, Map<String, dynamic> sellerData) {
    final sellerName = sellerData['name']?.toString() ?? productData['namatoko']?.toString() ?? 'Seller';
    final sellerToko = productData['namatoko']?.toString() ?? '';
    final sellerDaerah = productData['daerah']?.toString() ?? '';
    final sellerWa = sellerData['nowa']?.toString() ?? productData['nowa']?.toString() ?? '';
    final sellerAlamat = sellerData['alamat']?.toString() ?? '';
    final sellerInstagram = sellerData['instagram']?.toString() ?? '';
    final sellerFacebook = sellerData['facebook']?.toString() ?? '';
    final sellerTiktok = sellerData['tiktok']?.toString() ?? '';
    final sellerWebsite = sellerData['website']?.toString() ?? '';
    final sellerJabatan = sellerData['jabatan']?.toString() ?? '';
    final sellerNoAnggota = sellerData['noanggota']?.toString() ?? '';
    final sellerDeskripsiBisnis = sellerData['deskripsi_bisnis']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 20),

            // Header - Seller Name
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.store,
                    color: AppTheme.primaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sellerToko,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (sellerName.isNotEmpty && sellerName != sellerToko)
                        Text(
                          sellerName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Info Items
            if (sellerDaerah.isNotEmpty)
              _buildInfoItem(Icons.location_on, 'Daerah', sellerDaerah),
            if (sellerJabatan.isNotEmpty)
              _buildInfoItem(Icons.work, 'Jabatan', sellerJabatan),
            if (sellerNoAnggota.isNotEmpty)
              _buildInfoItem(Icons.badge, 'No. Anggota', sellerNoAnggota),
            if (sellerAlamat.isNotEmpty)
              _buildInfoItem(Icons.home, 'Alamat', sellerAlamat),

            // Deskripsi Bisnis
            if (sellerDeskripsiBisnis.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.description, size: 16, color: AppTheme.primaryColor),
                        const SizedBox(width: 8),
                        const Text(
                          'Deskripsi Bisnis',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      sellerDeskripsiBisnis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // WhatsApp Button
            if (sellerWa.isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _launchWhatsApp(sellerWa);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.chat, color: Colors.white),
                  label: Text(
                    'Chat WA: $sellerWa',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],

            // Social Media Section
            if (sellerInstagram.isNotEmpty || sellerFacebook.isNotEmpty || sellerTiktok.isNotEmpty || sellerWebsite.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                'Media Sosial',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              // Social buttons in row
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (sellerInstagram.isNotEmpty)
                    _buildSocialButton(
                      icon: Icons.camera_alt,
                      color: const Color(0xFFE1306C),
                      label: 'Instagram',
                      onTap: () => _openSocialLink('instagram', sellerInstagram),
                    ),
                  if (sellerFacebook.isNotEmpty)
                    _buildSocialButton(
                      icon: Icons.facebook,
                      color: const Color(0xFF1877F2),
                      label: 'Facebook',
                      onTap: () => _openSocialLink('facebook', sellerFacebook),
                    ),
                  if (sellerTiktok.isNotEmpty)
                    _buildSocialButton(
                      icon: Icons.music_note,
                      color: Colors.black,
                      label: 'TikTok',
                      onTap: () => _openSocialLink('tiktok', sellerTiktok),
                    ),
                  if (sellerWebsite.isNotEmpty)
                    _buildSocialButton(
                      icon: Icons.language,
                      color: AppTheme.primaryColor,
                      label: 'Website',
                      onTap: () => _openSocialLink('website', sellerWebsite),
                    ),
                ],
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
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

  Widget _buildSocialButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _launchWhatsApp(String noWa) async {
    String formattedNumber = noWa.replaceAll(RegExp(r'[^\d]'), '');
    if (formattedNumber.startsWith('0')) {
      formattedNumber = '62${formattedNumber.substring(1)}';
    }

    final url = Uri.parse('https://wa.me/$formattedNumber');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching WhatsApp: $e');
    }
  }

  void _openSocialLink(String type, String value) async {
    String url;

    switch (type) {
      case 'instagram':
        // Format: https://instagram.com/username
        if (value.startsWith('http')) {
          url = value;
        } else {
          url = 'https://instagram.com/$value';
        }
        break;
      case 'facebook':
        // Format: https://facebook.com/page atau full URL
        if (value.startsWith('http')) {
          url = value;
        } else {
          url = 'https://facebook.com/$value';
        }
        break;
      case 'tiktok':
        // Format: https://tiktok.com/@username
        if (value.startsWith('http')) {
          url = value;
        } else {
          url = 'https://tiktok.com/@$value';
        }
        break;
      case 'website':
        if (!value.startsWith('http')) {
          url = 'https://$value';
        } else {
          url = value;
        }
        break;
      default:
        return;
    }

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        // Buka di tab baru dengan mode externalApplication
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tidak dapat membuka $type'),
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

  @override
  Widget build(BuildContext context) {
    final data = widget.product.data;

    return DraggableScrollableSheet(
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

              // Product Image Carousel
              _ProductImageCarousel(
                imageUrls: _getImageUrlsFromFields(data, widget.product.id, collectionName: widget.collectionName),
                height: 200,
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

              // Harga
              if (data['harga'] != null && data['harga'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Rp ${widget.formatNumber((data['harga'] as num?)?.toInt() ?? 0)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),

              // Kategori Badge
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

              // Store Info - Clickable
              GestureDetector(
                onTap: () => _showSellerDetailSheet(context, data, _sellerData),
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
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    data['namatoko'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.touch_app,
                                  size: 16,
                                  color: AppTheme.successColor,
                                ),
                              ],
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
                                Expanded(
                                  child: Text(
                                    data['daerah'] ?? '',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Klik untuk lihat profil seller',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.successColor,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Social Media Buttons - Always visible below store info
              if (!_isLoadingSeller && _hasSocialMedia()) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Media Sosial & Kontak',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                // Social Media Icons Row
                _SellerSocialButtons(
                  sellerData: _sellerData,
                  openSocialLink: _openSocialLink,
                ),
              ],

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
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onAddToCart();
                  },
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

              // WA Button - Get WhatsApp from seller data or product
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Use seller data WA if available, otherwise use product WA
                    final waNumber = _sellerData['nowa']?.toString().isNotEmpty == true
                        ? _sellerData['nowa']
                        : widget.product.data['nowa']?.toString();
                    widget.onContactWhatsApp(waNumber);
                  },
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
                  onPressed: widget.onShare,
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
    );
  }
}

/// Full Screen Image Viewer with pinch-to-zoom
class _FullScreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const _FullScreenImageViewer({
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1} / ${widget.imageUrls.length}',
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        itemCount: widget.imageUrls.length,
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 1.0,
            maxScale: 5.0,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: widget.imageUrls[index],
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (context, url, error) => const Icon(
                  Icons.broken_image,
                  color: Colors.white,
                  size: 64,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Seller info social buttons widget
class _SellerSocialButtons extends StatelessWidget {
  final Map<String, dynamic> sellerData;
  final Function(String type, String value) openSocialLink;

  const _SellerSocialButtons({
    required this.sellerData,
    required this.openSocialLink,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        if (sellerData['instagram'] != null && sellerData['instagram'].toString().isNotEmpty)
          _buildSocialButton(
            icon: Icons.camera_alt,
            color: const Color(0xFFE1306C),
            label: 'Instagram',
            onTap: () => openSocialLink('instagram', sellerData['instagram'].toString()),
          ),
        if (sellerData['facebook'] != null && sellerData['facebook'].toString().isNotEmpty)
          _buildSocialButton(
            icon: Icons.facebook,
            color: const Color(0xFF1877F2),
            label: 'Facebook',
            onTap: () => openSocialLink('facebook', sellerData['facebook'].toString()),
          ),
        if (sellerData['tiktok'] != null && sellerData['tiktok'].toString().isNotEmpty)
          _buildSocialButton(
            icon: Icons.music_note,
            color: Colors.black,
            label: 'TikTok',
            onTap: () => openSocialLink('tiktok', sellerData['tiktok'].toString()),
          ),
        if (sellerData['website'] != null && sellerData['website'].toString().isNotEmpty)
          _buildSocialButton(
            icon: Icons.language,
            color: AppTheme.primaryColor,
            label: 'Website',
            onTap: () => openSocialLink('website', sellerData['website'].toString()),
          ),
      ],
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
