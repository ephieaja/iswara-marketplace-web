import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../config/theme.dart';
import '../../config/pocketbase_config.dart';
import '../../services/pocketbase_service.dart';
import '../../utils/ownership_helper.dart';
import 'welcome_screen.dart';
import 'profile_screen.dart';
import 'katalog_screen.dart';
import 'orders_screen.dart';
import 'add_product_screen.dart';
import 'edit_product_screen.dart';

class DashboardScreen extends StatefulWidget {
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
  final String sellerStatus;
  final String? instagram;
  final String? facebook;
  final String? tiktok;
  final String? website;

  const DashboardScreen({
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
    this.sellerStatus = 'approved',
    this.instagram,
    this.facebook,
    this.tiktok,
    this.website,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  DateTime? _lastBackPress;

  /// Apakah user yang sedang login punya role super_admin?
  /// Field ini akan ditambah di Tahap 2 schema marketplace (`users.is_super_admin`).
  /// Untuk sekarang default false sampai ada admin yang di-set.
  bool get _isSuperAdmin => isSuperAdmin(
        PocketBaseService.instance.authStore.record,
      );

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
  }

  Future<bool> _onWillPop() async {
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      return false;
    }

    if (_lastBackPress != null &&
        DateTime.now().difference(_lastBackPress!) < const Duration(seconds: 2)) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
      return false;
    }

    _lastBackPress = DateTime.now();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tekan lagi untuk keluar'),
        duration: Duration(seconds: 2),
      ),
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            // Tab 1: Beranda - Katalog Produk
            const KatalogScreen(),
            // Tab 2: Toko Saya - Dashboard with Statistik, Interaksi, Produk, Pesanan
            _SellerHomeTab(
              namaToko: widget.namaToko,
              userId: widget.userId,
              daerah: widget.daerah,
              namaLengkap: widget.namaLengkap,
              noWa: widget.noWa,
              noAnggota: widget.noAnggota,
            ),
            // Tab 3: Pesanan Saya - Buyer orders
            OrdersScreen(),
            // Tab 4: Profil
            ProfileScreen(
              username: widget.username,
              namaToko: widget.namaToko,
              daerah: widget.daerah,
              noWa: widget.noWa,
              userId: widget.userId,
              noAnggota: widget.noAnggota,
              namaLengkap: widget.namaLengkap,
              jabatan: widget.jabatan,
              sebagai: widget.sebagai,
              alamat: widget.alamat,
              instagram: widget.instagram,
              facebook: widget.facebook,
              tiktok: widget.tiktok,
              website: widget.website,
            ),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Beranda',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.store_outlined),
                activeIcon: Icon(Icons.store),
                label: 'Toko Saya',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long_outlined),
                activeIcon: Icon(Icons.receipt_long),
                label: 'Pesanan',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Profil',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Tab 2: Toko Saya - with Statistik, Interaksi, Produk, Pesanan Masuk
class _SellerHomeTab extends StatefulWidget {
  final String namaToko;
  final String userId;
  final String daerah;
  final String namaLengkap;
  final String noWa;
  final String noAnggota;

  const _SellerHomeTab({
    required this.namaToko,
    required this.userId,
    required this.daerah,
    required this.namaLengkap,
    required this.noWa,
    required this.noAnggota,
  });

  @override
  State<_SellerHomeTab> createState() => _SellerHomeTabState();
}

class _SellerHomeTabState extends State<_SellerHomeTab> {
  int _selectedSection = 0;
  List<RecordModel> _products = [];
  List<RecordModel> _interaksi = [];
  List<RecordModel> _orders = [];
  int _totalViews = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    try {
      final pb = PocketBaseService.instance;

      // Resolve SellersMarketplace record id untuk current user (Fase 1)
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

      // Load products dari ProdukMarketplace (Fase 1)
      // Filter by `seller` (relation id) = sellersMarketplace record id
      List<RecordModel> products = [];
      if (sellerId != null) {
        try {
          final productsResult = await pb
              .collection(PocketBaseConfig.produkMarketplaceCollection)
              .getList(
                filter: 'seller = "$sellerId"',
                sort: '-created',
                perPage: 50,
              );
          products = productsResult.items;
        } catch (e) {
          debugPrint('Error loading ProdukMarketplace: $e');
        }
      }

      // Load interactions (legacy, masih pakai Interaksi collection existing)
      List<RecordModel> interaksi = [];
      try {
        final interaksiResult = await pb
            .collection(PocketBaseConfig.interaksiCollection)
            .getList(
              filter: 'idpenjual = "${widget.userId}"',
              sort: '-created',
              perPage: 50,
            );
        interaksi = interaksiResult.items;
      } catch (e) {
        debugPrint('Error loading Interaksi: $e');
      }

      // Load orders (pesanan masuk) — pakai PesananMarketplace (Fase 1)
      List<RecordModel> orders = [];
      if (sellerId != null) {
        try {
          final ordersResult = await pb
              .collection(PocketBaseConfig.pesananMarketplaceCollection)
              .getList(
                filter: 'seller = "$sellerId"',
                sort: '-created',
                perPage: 50,
              );
          orders = ordersResult.items;
        } catch (e) {
          debugPrint('Error loading PesananMarketplace: $e');
        }
      }

      // Load views (legacy)
      int totalViews = 0;
      try {
        final viewsResult = await pb
            .collection(PocketBaseConfig.productViewsCollection)
            .getList(
              filter: 'sellerid = "${widget.userId}"',
              perPage: 1,
            );
        totalViews = viewsResult.totalItems;
      } catch (e) {
        debugPrint('Error loading productViews: $e');
      }

      if (mounted) {
        setState(() {
          _products = products;
          _interaksi = interaksi;
          _orders = orders;
          _totalViews = totalViews;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading seller data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Toko Saya',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Section Selector
          _buildSectionSelector(),
          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadAllData,
                    child: _buildSectionContent(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionSelector() {
    final sections = ['Statistik', 'Interaksi', 'Produk', 'Pesanan'];
    final icons = [Icons.bar_chart, Icons.chat, Icons.inventory_2, Icons.receipt];

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: List.generate(sections.length, (index) {
          final isSelected = _selectedSection == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedSection = index),
              child: Container(
                margin: EdgeInsets.only(right: index < sections.length - 1 ? 8 : 0),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryColor : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppTheme.primaryColor : AppTheme.dividerColor,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    Icon(
                      icons[index],
                      size: 20,
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sections[index],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.white : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSectionContent() {
    switch (_selectedSection) {
      case 0:
        return _buildStatistikContent();
      case 1:
        return _buildInteraksiContent();
      case 2:
        return _buildProdukContent();
      case 3:
        return _buildPesananContent();
      default:
        return _buildStatistikContent();
    }
  }

  Widget _buildStatistikContent() {
    final totalProduk = _products.length;
    final totalInteraksi = _interaksi.length;
    final totalPesanan = _orders.where((o) => o.data['status'] == 'confirmed' || o.data['status'] == 'shipped').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Summary Cards
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  'Statistik Toko',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.namaToko,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(Icons.visibility, _totalViews.toString(), 'Views'),
                    _buildStatItem(Icons.inventory_2, totalProduk.toString(), 'Produk'),
                    _buildStatItem(Icons.chat, totalInteraksi.toString(), 'Interaksi'),
                    _buildStatItem(Icons.receipt, totalPesanan.toString(), 'Pesanan'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Detailed Stats
          Row(
            children: [
              Expanded(
                child: _buildDetailStatCard(
                  'Total Views',
                  _totalViews.toString(),
                  Icons.visibility,
                  AppTheme.infoColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailStatCard(
                  'Total Produk',
                  totalProduk.toString(),
                  Icons.inventory_2,
                  AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDetailStatCard(
                  'Total Interaksi',
                  totalInteraksi.toString(),
                  Icons.chat,
                  AppTheme.successColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailStatCard(
                  'Pesanan Aktif',
                  totalPesanan.toString(),
                  Icons.receipt,
                  AppTheme.warningColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteraksiContent() {
    if (_interaksi.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              'Belum ada interaksi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Interaksi akan muncul ketika ada yang chat via WA',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _interaksi.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final data = _interaksi[index].data;
        final isAnonim = data['isanonim'] ?? true;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.dividerColor),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isAnonim
                      ? Colors.grey.withOpacity(0.1)
                      : AppTheme.successColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isAnonim ? Icons.person_outline : Icons.person,
                  color: isAnonim ? Colors.grey : AppTheme.successColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAnonim ? 'Anonim' : (data['namapeminat'] ?? 'Tidak diketahui'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isAnonim ? Colors.grey : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data['namaproduk'] ?? 'Produk',
                      style: const TextStyle(fontSize: 13),
                    ),
                    if (!isAnonim && data['nohppeminat'] != null)
                      Text(
                        data['nohppeminat'],
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
              Text(
                _formatDateFromString(_interaksi[index].created),
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProdukContent() {
    return Column(
      children: [
        // Tombol Tambah Produk
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddProductScreen(
                      userId: widget.userId,
                      namaToko: widget.namaToko,
                      daerah: widget.daerah,
                      noWa: widget.noWa,
                    ),
                  ),
                ).then((_) => _loadAllData());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text(
                'Tambah Produk',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        // List Produk
        Expanded(
          child: _buildProdukList(),
        ),
      ],
    );
  }

  Widget _buildProdukList() {
    if (_products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              'Belum ada produk',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tambahkan produk pertama Anda',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final product = _products[index];
        final data = product.data;

        // Get image URL - cek field 'gambar' (array) atau field terpisah
        String? imageUrl;
        if (data.containsKey('gambar')) {
          final gambar = data['gambar'];
          if (gambar is List && gambar.isNotEmpty) {
            imageUrl = '${PocketBaseConfig.pocketBaseUrl}/api/files/${PocketBaseConfig.produkMarketplaceCollection}/${product.id}/${gambar[0]}';
          } else if (gambar != null && gambar.toString().isNotEmpty) {
            imageUrl = '${PocketBaseConfig.pocketBaseUrl}/api/files/${PocketBaseConfig.produkMarketplaceCollection}/${product.id}/${gambar}';
          }
        }
        if (imageUrl == null) {
          for (final field in ['gambar1', 'gambar2', 'gambar3']) {
            if (data.containsKey(field) && data[field] != null && data[field].toString().isNotEmpty) {
              imageUrl = '${PocketBaseConfig.pocketBaseUrl}/api/files/${PocketBaseConfig.produkMarketplaceCollection}/${product.id}/${data[field]}';
              break;
            }
          }
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EditProductScreen(
                  productId: product.id,
                  productData: data,
                  userId: widget.userId,
                  namaToko: widget.namaToko,
                  daerah: widget.daerah,
                  noWa: widget.noWa,
                ),
              ),
            ).then((_) => _loadAllData());
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.dividerColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.contain,
                            placeholder: (_, __) => const Icon(Icons.image, color: AppTheme.textLight),
                            errorWidget: (_, __, ___) => const Icon(Icons.image, color: AppTheme.textLight),
                          ),
                        )
                      : const Icon(Icons.image, color: AppTheme.textLight),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['nama'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data['kategori'] ?? '',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      if (data['harga'] != null)
                        Text(
                          'Rp ${_formatNumber((data['harga'] as num?)?.toInt() ?? 0)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPesananContent() {
    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              'Belum ada pesanan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pesanan masuk akan muncul di sini',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final data = _orders[index].data;
        final status = data['status'] ?? 'pending';

        Color statusColor;
        String statusLabel;
        switch (status) {
          case 'pending':
            statusColor = Colors.orange;
            statusLabel = 'Menunggu';
            break;
          case 'confirmed':
            statusColor = Colors.blue;
            statusLabel = 'Dikonfirmasi';
            break;
          case 'shipped':
            statusColor = Colors.purple;
            statusLabel = 'Dikirim';
            break;
          case 'complete':
            statusColor = AppTheme.successColor;
            statusLabel = 'Selesai';
            break;
          case 'cancelled':
            statusColor = Colors.red;
            statusLabel = 'Batal';
            break;
          default:
            statusColor = AppTheme.infoColor;
            statusLabel = status;
        }

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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pesanan #${_orders[index].id.substring(0, 8)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                data['namaproduk'] ?? 'Produk',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                'Pembeli: ${data['namapembeli'] ?? 'Anonim'}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total: Rp ${_formatNumber((data['total'] as num?)?.toInt() ?? 0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  Text(
                    _formatDateFromString(_orders[index].created),
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m lalu';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}j lalu';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}h lalu';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatDateFromString(dynamic dateValue) {
    try {
      if (dateValue is DateTime) {
        return _formatDate(dateValue);
      }
      if (dateValue is String) {
        final date = DateTime.parse(dateValue);
        return _formatDate(date);
      }
    } catch (e) {
      return dateValue?.toString() ?? '-';
    }
    return dateValue?.toString() ?? '-';
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
