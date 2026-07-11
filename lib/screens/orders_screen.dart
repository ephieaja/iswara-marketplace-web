import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../config/theme.dart';
import '../services/pocketbase_service.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
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
      final pbUser = pb.authStore.record;

      if (pbUser == null) {
        setState(() {
          _isLoading = false;
          _orders = [];
        });
        return;
      }

      final result = await pb.collection('pesanan').getList(
        filter: 'buyerId = "${pbUser.id}"',
        sort: '-created',
        perPage: 200,
      );

      setState(() {
        _orders = result.items;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading orders: $e');
      setState(() {
        _isLoading = false;
        _orders = [];
      });
    }
  }

  List<RecordModel> _filterOrders(List<String>? statuses) {
    if (statuses == null) return _orders;
    return _orders.where((order) {
      final status = order.data['status'] ?? '';
      return statuses.contains(status);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pesanan Saya'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Semua'),
            Tab(text: 'Diproses'),
            Tab(text: 'Selesai'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrdersList(null),
          _buildOrdersList(['pending', 'paid', 'processing', 'shipped']),
          _buildOrdersList(['completed']),
        ],
      ),
    );
  }

  Widget _buildOrdersList(List<String>? statusFilter) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredOrders = _filterOrders(statusFilter);

    if (filteredOrders.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredOrders.length,
        itemBuilder: (context, index) {
          final order = filteredOrders[index];
          return _OrderCard(order: order);
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
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 80,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Belum Ada Pesanan',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Mulai belanja produk\ndari Seller!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final RecordModel order;

  const _OrderCard({required this.order});

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
      child: InkWell(
        onTap: () {
          final pbUser = PocketBaseService.instance.authStore.record;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderDetailScreen(
                orderId: order.id,
                userId: pbUser?.id ?? '',
                isSeller: false,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getStatusIcon(status),
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${order.id.substring(0, 8).toUpperCase()}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDateFromString(order.created),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
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
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'paid':
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
      case 'paid': return Icons.payments;
      case 'processing': return Icons.inventory;
      case 'shipped': return Icons.local_shipping;
      case 'completed': return Icons.check_circle;
      case 'cancelled': return Icons.cancel;
      default: return Icons.help;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending': return 'Menunggu';
      case 'paid': return 'Dibayar';
      case 'processing': return 'Diproses';
      case 'shipped': return 'Dikirim';
      case 'completed': return 'Selesai';
      case 'cancelled': return 'Batal';
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
}
