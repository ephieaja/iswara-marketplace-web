import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../config/theme.dart';
import '../../config/pocketbase_config.dart';
import '../../services/pocketbase_service.dart';
import 'edit_product_screen.dart';

/// Helper untuk mendapatkan URL lengkap gambar dari PocketBase (single image).
///
/// PERUBAHAN 14 Agt 2026 (Fase 1):
/// - Tambah parameter `collectionName` untuk support Produk + ProdukMarketplace.
/// - Default ke `produkMarketplaceCollection` (Fase 1 default untuk marketplace).
String _getProductImageUrl(dynamic imageField, String recordId, {String? collectionName}) {
  if (imageField == null || imageField.toString().isEmpty) {
    return '';
  }

  final value = imageField.toString();

  if (value.isEmpty) {
    return '';
  }

  // Jika sudah URL lengkap dan valid
  if (value.startsWith('http') &&
      !value.contains('vercel.app') &&
      !value.contains('localhost')) {
    return value;
  }

  // Ambil nama file saja dari path
  String filename;
  if (value.contains('/')) {
    filename = value.split('/').last;
  } else {
    filename = value;
  }

  // Collection name PocketBase
  final coll = collectionName ?? PocketBaseConfig.produkMarketplaceCollection;
  return '${PocketBaseConfig.pocketBaseUrl}/api/files/$coll/$recordId/$filename';
}

/// Helper untuk mendapatkan URL gambar dari list (multiple images)
List<String> _getProductImageUrls(dynamic imageField, String recordId, {String? collectionName}) {
  final urls = <String>[];

  if (imageField == null) {
    return urls;
  }

  // Handle List
  if (imageField is List) {
    for (var item in imageField) {
      if (item != null && item.toString().isNotEmpty) {
        final url = _getProductImageUrl(item, recordId, collectionName: collectionName);
        if (url.isNotEmpty) urls.add(url);
      }
    }
  }
  // Handle single value
  else if (imageField.toString().isNotEmpty) {
    final url = _getProductImageUrl(imageField, recordId, collectionName: collectionName);
    if (url.isNotEmpty) urls.add(url);
  }

  return urls;
}

/// Helper untuk mendapatkan URL gambar dari field terpisah (gambar1, gambar2, gambar3)
List<String> _getProductImageUrlsFromFields(Map<String, dynamic> data, String recordId, {String? collectionName}) {
  final urls = <String>[];

  // Cek field 'gambar' sebagai array
  if (data.containsKey('gambar')) {
    final gambar = data['gambar'];
    if (gambar is List) {
      for (var item in gambar) {
        if (item != null && item.toString().isNotEmpty) {
          final url = _getProductImageUrl(item, recordId, collectionName: collectionName);
          if (url.isNotEmpty && !urls.contains(url)) {
            urls.add(url);
          }
        }
      }
    } else if (gambar != null && gambar.toString().isNotEmpty) {
      final url = _getProductImageUrl(gambar, recordId, collectionName: collectionName);
      if (url.isNotEmpty && !urls.contains(url)) {
        urls.add(url);
      }
    }
  }

  // Cek field terpisah
  final fieldNames = ['gambar1', 'gambar2', 'gambar3'];
  for (final field in fieldNames) {
    if (data.containsKey(field) && data[field] != null && data[field].toString().isNotEmpty) {
      final url = _getProductImageUrl(data[field], recordId, collectionName: collectionName);
      if (url.isNotEmpty && !urls.contains(url)) {
        urls.add(url);
      }
    }
  }

  return urls;
}

class MyProductsScreen extends StatefulWidget {
  final String userId;

  const MyProductsScreen({super.key, required this.userId});

  @override
  State<MyProductsScreen> createState() => _MyProductsScreenState();
}

class _MyProductsScreenState extends State<MyProductsScreen> {
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final pb = PocketBaseService.instance;
      // Fase 1: marketplace pakai `users_auth` collection (bukan `users` legacy)
      final doc = await pb
          .collection(PocketBaseConfig.usersAuthCollection)
          .getOne(widget.userId);

      setState(() {
        _userData = doc.data;
      });
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Future<List<RecordModel>> _getMyProducts() async {
    try {
      final pb = PocketBaseService.instance;

      // Fase 1: lookup SellersMarketplace record dulu (untuk filter by `seller` relation)
      String? sellerId;
      try {
        final sellerResult = await pb
            .collection(PocketBaseConfig.sellersMarketplaceCollection)
            .getList(
              filter: 'user = "${widget.userId}"',
              perPage: 1,
            );
        if (sellerResult.items.isNotEmpty) {
          sellerId = sellerResult.items.first.id;
        }
      } catch (e) {
        debugPrint('Error fetching SellersMarketplace: $e');
      }

      if (sellerId == null) {
        // Belum jadi seller
        return [];
      }

      // Query ProdukMarketplace dengan filter seller = sellersMarketplace_id
      final result = await pb
          .collection(PocketBaseConfig.produkMarketplaceCollection)
          .getList(
            filter: 'seller = "$sellerId"',
            sort: '-created',
            perPage: 200,
          );
      return result.items;
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Produk Saya'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterOptions(),
          ),
        ],
      ),
      body: FutureBuilder<List<RecordModel>>(
        future: _getMyProducts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          }

          final products = snapshot.data ?? [];

          if (products.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return _ProductCard(
                  product: product,
                  onEdit: () => _editProduct(product),
                  onDelete: () => _deleteProduct(product),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 64,
                color: AppTheme.primaryColor.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Belum Ada Produk',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Mulai tambahkan produk pertama Anda\nuntuk ditampilkan di katalog',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter Produk',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.all_inclusive),
              title: const Text('Semua'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('Terbaru'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.sort_by_alpha),
              title: const Text('Nama A-Z'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.category),
              title: const Text('Per Kategori'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _editProduct(RecordModel product) {
    if (_userData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sedang memuat data...'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProductScreen(
          productId: product.id,
          productData: product.data,
          userId: widget.userId,
          // Fase 1: `_userData` berasal dari `users_auth` collection.
          // Field names:
          // - `users_auth.phone` (bukan `nowa`)
          // - `users_auth.daerah` (sama)
          // - `namatoko` TIDAK ada di users_auth — ambil dari SellersMarketplace.
          //    Untuk sekarang fallback ke `name` user. EditProductScreen akan
          //    cari SellersMarketplace.id via filter `user = userId`.
          namaToko: _userData!['namatoko']?.toString() ??
              _userData!['name']?.toString() ??
              '',
          daerah: _userData!['daerah']?.toString() ?? '',
          noWa: _userData!['phone']?.toString() ??
              _userData!['nowa']?.toString() ??
              '',
        ),
      ),
    );
  }

  void _deleteProduct(RecordModel product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: AppTheme.errorColor),
            SizedBox(width: 12),
            Text('Hapus Produk'),
          ],
        ),
        content: const Text(
            'Apakah Anda yakin ingin menghapus produk ini?'),
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
                // Fase 1: juga hapus varian record terkait di produk_varian_marketplace
                try {
                  final varianResult = await pb
                      .collection(PocketBaseConfig.produkVarianMarketplaceCollection)
                      .getList(
                        filter: 'produk = "${product.id}"',
                        perPage: 50,
                      );
                  for (final v in varianResult.items) {
                    try {
                      await pb
                          .collection(PocketBaseConfig.produkVarianMarketplaceCollection)
                          .delete(v.id);
                    } catch (e) {
                      debugPrint('Error delete varian ${v.id}: $e');
                    }
                  }
                } catch (e) {
                  debugPrint('Error fetching varian for delete: $e');
                }
                await pb
                    .collection(PocketBaseConfig.produkMarketplaceCollection)
                    .delete(product.id);

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Produk berhasil dihapus'),
                    backgroundColor: AppTheme.successColor,
                  ),
                );

                // Refresh list
                setState(() {});
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Gagal menghapus: $e'),
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
}

class _ProductCard extends StatelessWidget {
  final RecordModel product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductCard({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final data = product.data;
    final harga = (data['harga'] as num?)?.toInt() ?? 0;
    // Cek berbagai kemungkinan nama field gambar
    // Fase 1: ProdukMarketplace URL path (default untuk marketplace)
    final imageUrls = _getProductImageUrlsFromFields(
      data,
      product.id,
      collectionName: PocketBaseConfig.produkMarketplaceCollection,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          // Image Carousel
          _ProductImageCarousel(
            imageUrls: imageUrls,
            productId: product.id,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        data['nama'] ?? '',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        data['kategori'] ?? '',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                if (harga > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Rp ${_formatNumber(harga)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  data['deskripsi'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      data['daerah'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: onEdit,
                      color: AppTheme.primaryColor,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: onDelete,
                      color: AppTheme.errorColor,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}Jt';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(0)}Rb';
    }
    return number.toString();
  }
}

/// Carousel widget untuk menampilkan multiple foto produk
class _ProductImageCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final String productId;

  const _ProductImageCarousel({
    required this.imageUrls,
    required this.productId,
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
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Container(
            height: 180,
            width: double.infinity,
            color: AppTheme.backgroundColor,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemCount: widget.imageUrls.length,
              itemBuilder: (context, index) {
                return CachedNetworkImage(
                  imageUrl: widget.imageUrls[index],
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.contain, // Changed from cover to prevent cropping
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  errorWidget: (context, url, error) => _buildNoImagePlaceholder(),
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

  Widget _buildNoImagePlaceholder() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Container(
        height: 180,
        width: double.infinity,
        color: AppTheme.backgroundColor,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image, size: 48, color: AppTheme.textLight),
              SizedBox(height: 8),
              Text(
                'Tidak ada gambar',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
