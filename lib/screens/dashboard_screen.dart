import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../config/theme.dart';
import '../../services/pocketbase_service.dart';
import '../../utils/share_helper.dart';
import 'welcome_screen.dart';
import 'profile_screen.dart';
import 'add_product_screen.dart';
import 'my_products_screen.dart';
import 'katalog_screen.dart';
import 'seller_orders_screen.dart';

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
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  DateTime? _lastBackPress;

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
            _HomeTab(
              namaToko: widget.namaToko,
              userId: widget.userId,
              daerah: widget.daerah,
              namaLengkap: widget.namaLengkap,
              noWa: widget.noWa,
              onTabTap: _onTabTapped,
            ),
            SellerOrdersScreen(
              userId: widget.userId,
              namaToko: widget.namaToko,
              noWa: widget.noWa,
            ),
            MyProductsScreen(userId: widget.userId),
            AddProductScreen(
              userId: widget.userId,
              namaToko: widget.namaToko,
              daerah: widget.daerah,
              noWa: widget.noWa,
            ),
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
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Beranda',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long_outlined),
                activeIcon: Icon(Icons.receipt_long),
                label: 'Pesanan',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.inventory_2_outlined),
                activeIcon: Icon(Icons.inventory_2),
                label: 'Produk',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.add_circle_outline),
                activeIcon: Icon(Icons.add_circle),
                label: 'Tambah',
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

class _HomeTab extends StatefulWidget {
  final String namaToko;
  final String userId;
  final String daerah;
  final String namaLengkap;
  final String noWa;
  final Function(int) onTabTap;

  const _HomeTab({
    required this.namaToko,
    required this.userId,
    required this.daerah,
    required this.namaLengkap,
    required this.noWa,
    required this.onTabTap,
  });

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  List<RecordModel> _recentProducts = [];
  List<RecordModel> _recentInteraksi = [];
  int _totalViews = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final pb = PocketBaseService.instance;

      // Load products
      final productsResult = await pb.collection('produk').getList(
        filter: 'sellerId = "${widget.userId}"',
        sort: '-created',
        perPage: 3,
      );

      // Load interactions
      final interaksiResult = await pb.collection('interaksi').getList(
        filter: 'idPenjual = "${widget.userId}"',
        sort: '-created',
        perPage: 5,
      );

      // Load views
      final viewsResult = await pb.collection('product_views').getList(
        filter: 'idPenjual = "${widget.userId}"',
        perPage: 1,
      );

      if (mounted) {
        setState(() {
          _recentProducts = productsResult.items;
          _recentInteraksi = interaksiResult.items;
          _totalViews = viewsResult.totalItems;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text(
              'MARKETPLACE',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            Text(
              widget.namaToko.isNotEmpty ? widget.namaToko : 'Toko Saya',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeCard(context),
                    const SizedBox(height: 24),
                    _buildStatistikSection(context),
                    const SizedBox(height: 24),
                    _buildInteraksiTerbaruSection(context),
                    const SizedBox(height: 24),
                    _buildQuickActions(context),
                    const SizedBox(height: 24),
                    _buildRecentProducts(context),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context) {
    return Container(
      width: double.infinity,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.storefront,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selamat Datang!',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.namaToko.isNotEmpty ? widget.namaToko : 'Toko Saya',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                const Text(
                  'Pemilik Usaha Terverifikasi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatistikSection(BuildContext context) {
    final totalInteraksi = _recentInteraksi.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Statistik Toko',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.visibility,
                title: 'Total Views',
                value: _totalViews.toString(),
                color: AppTheme.infoColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.chat,
                title: 'Interaksi WA',
                value: totalInteraksi.toString(),
                color: AppTheme.successColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInteraksiTerbaruSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Interaksi Terbaru',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        if (_recentInteraksi.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.dividerColor),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 48,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 12),
                Text(
                  'Belum ada interaksi',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Interaksi akan muncul ketika ada yang chat via WA',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.dividerColor),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentInteraksi.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: Colors.grey.shade200,
              ),
              itemBuilder: (context, index) {
                final data = _recentInteraksi[index].data;
                final isAnonim = data['isAnonim'] ?? true;

                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isAnonim
                          ? Colors.grey.withOpacity(0.1)
                          : AppTheme.successColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isAnonim ? Icons.person_outline : Icons.person,
                      color: isAnonim ? Colors.grey : AppTheme.successColor,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    isAnonim
                        ? 'Anonim'
                        : (data['namaPeminat'] ?? 'Tidak diketahui'),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isAnonim ? Colors.grey : AppTheme.textPrimary,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['namaProduk'] ?? 'Produk',
                        style: const TextStyle(fontSize: 12),
                      ),
                      if (!isAnonim && data['noHpPeminat'] != null)
                        Text(
                          data['noHpPeminat'],
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                  trailing: Text(
                    _formatDateFromString(_recentInteraksi[index].created),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[500],
                    ),
                  ),
                  isThreeLine: !isAnonim && data['noHpPeminat'] != null,
                );
              },
            ),
          ),
      ],
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

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Aksi Cepat',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.add_circle,
                title: 'Tambah Produk',
                color: AppTheme.primaryColor,
                onTap: () => widget.onTabTap(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.visibility,
                title: 'Lihat Katalog',
                color: AppTheme.accentColor,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const KatalogScreen()),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.edit,
                title: 'Edit Profil',
                color: AppTheme.warningColor,
                onTap: () => widget.onTabTap(3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.share,
                title: 'Bagikan Toko',
                color: AppTheme.infoColor,
                onTap: () {
                  ShareHelper.shareStore(
                    storeName: widget.namaToko.isNotEmpty ? widget.namaToko : 'Toko Saya',
                    sellerName: widget.namaLengkap,
                    daerah: widget.daerah,
                    noWa: widget.noWa,
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentProducts(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Produk Saya',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () => widget.onTabTap(1),
              child: const Text('Lihat Semua'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_recentProducts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.dividerColor),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 48,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 12),
                Text(
                  'Belum ada produk',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tambahkan produk pertama Anda',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: _recentProducts.map((doc) {
              final data = doc.data;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.dividerColor),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.image,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['nama'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            data['kategori'] ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.grey[400],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.dividerColor),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
