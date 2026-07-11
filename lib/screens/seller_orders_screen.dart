import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../config/theme.dart';
import '../config/pocketbase_config.dart';
import '../services/pocketbase_service.dart';

class SellerOrdersScreen extends StatefulWidget {
  final String userId;
  final String namaToko;
  final String noWa;

  const SellerOrdersScreen({
    super.key,
    required this.userId,
    required this.namaToko,
    required this.noWa,
  });

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<RecordModel> _orders = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final pb = PocketBaseService.instance;
      final result = await pb.collection(PocketBaseConfig.pesananCollection).getList(
        filter: 'sellerId = "${widget.userId}"',
        sort: '-created',
        perPage: 200,
      );

      setState(() {
        _orders = result.items;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading orders: $e');
      setState(() => _isLoading = false);
    }
  }

  List<RecordModel> _filterOrders(String status) {
    return _orders.where((order) {
      final orderStatus = order.data['status'] ?? '';
      return orderStatus == status;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pesanan Masuk'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Baru'),
            Tab(text: 'Diproses'),
            Tab(text: 'Selesai'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrdersList('pending'),
          _buildOrdersList('processing'),
          _buildOrdersList('completed'),
        ],
      ),
    );
  }

  Widget _buildOrdersList(String status) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final orders = _filterOrders(status);

    if (orders.isEmpty) {
      return _buildEmptyState(status);
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          return _SellerOrderCard(
            order: order,
            onStatusChange: _loadOrders,
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String status) {
    String title;
    IconData icon;

    switch (status) {
      case 'pending':
        title = 'Belum Ada Pesanan Baru';
        icon = Icons.inbox_outlined;
        break;
      case 'processing':
        title = 'Belum Ada Pesanan Diproses';
        icon = Icons.inventory_2_outlined;
        break;
      case 'completed':
        title = 'Belum Ada Pesanan Selesai';
        icon = Icons.check_circle_outline;
        break;
      default:
        title = 'Tidak Ada Pesanan';
        icon = Icons.inbox_outlined;
    }

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
              child: Icon(icon, size: 80, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SellerOrderCard extends StatelessWidget {
  final RecordModel order;
  final VoidCallback onStatusChange;

  const _SellerOrderCard({
    required this.order,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    final data = order.data;
    final status = data['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_getStatusIcon(status), color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${order.id.substring(0, 8).toUpperCase()}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _formatDateFromString(order.created),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getStatusLabel(status),
                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Items
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ...((data['items'] as List<dynamic>?)?.map((item) {
                  final itemMap = item as Map<String, dynamic>;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: itemMap['productImage']?.toString().isNotEmpty == true
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: itemMap['productImage'],
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => const Icon(Icons.image),
                                  ),
                                )
                              : const Icon(Icons.image),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                itemMap['productName'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${itemMap['quantity'] ?? 1}x Rp ${_formatNumber(itemMap['price'] ?? 0)}',
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }) ?? []),
              ],
            ),
          ),

          const Divider(height: 1),

          // Buyer Info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person, size: 16, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Text('Pembeli: ${data['buyerName'] ?? ''}'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.phone, size: 16, color: AppTheme.successColor),
                    const SizedBox(width: 8),
                    Text(data['buyerPhone'] ?? ''),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on, size: 16, color: AppTheme.accentColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        data['buyerAddress'] ?? '',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Actions
          if (status == 'pending')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _updateStatus(context, 'cancelled'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorColor,
                        side: const BorderSide(color: AppTheme.errorColor),
                      ),
                      child: const Text('Tolak'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _updateStatus(context, 'processing'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                      child: const Text('Terima'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(BuildContext context, String newStatus) async {
    try {
      final pb = PocketBaseService.instance;
      await pb.collection(PocketBaseConfig.pesananCollection).update(
        order.id,
        body: {'status': newStatus},
      );

      onStatusChange();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pesanan ${newStatus == 'completed' ? 'selesai' : 'ditolak'}'),
            backgroundColor: newStatus == 'completed' ? AppTheme.successColor : AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'processing': return Colors.blue;
      case 'shipped': return Colors.purple;
      case 'completed': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending': return Icons.access_time;
      case 'processing': return Icons.inventory;
      case 'shipped': return Icons.local_shipping;
      case 'completed': return Icons.check_circle;
      case 'cancelled': return Icons.cancel;
      default: return Icons.help;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending': return 'Baru';
      case 'processing': return 'Diproses';
      case 'shipped': return 'Dikirim';
      case 'completed': return 'Selesai';
      case 'cancelled': return 'Ditolak';
      default: return status;
    }
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
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
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }
}
