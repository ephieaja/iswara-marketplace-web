import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';

import '../../config/theme.dart';
import '../../services/pocketbase_service.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  final String userId;
  final bool isSeller;

  const OrderDetailScreen({
    super.key,
    required this.orderId,
    required this.userId,
    this.isSeller = false,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final _ekspedisiController = TextEditingController();
  final _noResiController = TextEditingController();

  String _selectedEkspedisi = 'JNE';
  bool _isLoading = false;
  bool _hasShipping = false;
  RecordModel? _order;

  final List<String> _ekspedisiList = [
    'JNE', 'J&T Express', 'SiCepat', 'AnterAja',
    'Ninja Xpress', 'TIKI', 'Pos Indonesia',
    'GrabExpress', 'GoSend', 'Lion Parcel',
  ];

  @override
  void initState() {
    super.initState();
    _loadOrderData();
  }

  @override
  void dispose() {
    _ekspedisiController.dispose();
    _noResiController.dispose();
    super.dispose();
  }

  Future<void> _loadOrderData() async {
    try {
      final pb = PocketBaseService.instance;
      final doc = await pb.collection('pesanan').getOne(widget.orderId);

      if (mounted) {
        setState(() {
          _order = doc;
          final data = doc.data;
          if (data['ekspedisi'] != null) {
            _selectedEkspedisi = data['ekspedisi'];
          }
          if (data['noResi'] != null && data['noResi'].toString().isNotEmpty) {
            _noResiController.text = data['noResi'];
            _hasShipping = true;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading order: $e');
    }
  }

  Future<void> _saveShippingInfo() async {
    if (_noResiController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No. Resi wajib diisi'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final pb = PocketBaseService.instance;
      await pb.collection('pesanan').update(
        widget.orderId,
        body: {
          'ekspedisi': _selectedEkspedisi,
          'noResi': _noResiController.text.trim(),
          'status': 'shipped',
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Info pengiriman berhasil disimpan'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _hasShipping = true;
          _isLoading = false;
        });
        _loadOrderData();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Pesanan'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _order == null
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final data = _order!.data;
    final status = data['status'] ?? 'pending';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusCard(status),
          const SizedBox(height: 16),
          _buildSectionTitle('Info Pesanan'),
          const SizedBox(height: 8),
          _buildOrderInfoCard(status),
          const SizedBox(height: 16),
          _buildSectionTitle('Item Pesanan'),
          const SizedBox(height: 8),
          _buildItemsCard(data),
          const SizedBox(height: 16),
          if (widget.isSeller) ...[
            _buildSectionTitle('Info Pengiriman'),
            const SizedBox(height: 8),
            _buildShippingCard(status),
          ],
          _buildSectionTitle('Alamat Pengiriman'),
          const SizedBox(height: 8),
          _buildAddressCard(data),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String status) {
    Color color;
    IconData icon;
    String label;

    switch (status) {
      case 'pending':
        color = Colors.orange;
        icon = Icons.pending_actions;
        label = 'Menunggu Pembayaran';
        break;
      case 'paid':
        color = Colors.blue;
        icon = Icons.payment;
        label = 'Sudah Dibayar';
        break;
      case 'processing':
        color = Colors.purple;
        icon = Icons.inventory;
        label = 'Diproses';
        break;
      case 'shipped':
        color = Colors.cyan;
        icon = Icons.local_shipping;
        label = 'Dikirim';
        break;
      case 'completed':
        color = Colors.green;
        icon = Icons.check_circle;
        label = 'Selesai';
        break;
      default:
        color = Colors.grey;
        icon = Icons.help_outline;
        label = status;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 48),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Order ID: ${_order!.id.substring(0, 8)}...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimary,
      ),
    );
  }

  Widget _buildOrderInfoCard(String status) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _buildInfoRow('Tanggal', _formatDateFromString(_order!.created)),
          const Divider(),
          _buildInfoRow('Metode Pembayaran', _order!.data['paymentMethod'] ?? 'QRIS'),
          const Divider(),
          _buildInfoRow(
            'Total',
            'Rp ${_formatNumber(_order!.data['totalAmount'] ?? 0)}',
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              fontSize: 14,
              color: isBold ? AppTheme.primaryColor : AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsCard(Map<String, dynamic> data) {
    final items = data['items'] as List<dynamic>? ?? [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: items.map<Widget>((item) {
          final itemMap = item as Map<String, dynamic>;
          final quantity = itemMap['quantity'] ?? 1;
          final price = itemMap['price'] ?? 0;
          final subtotal = quantity * price;

          return ListTile(
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.image, color: Colors.grey),
            ),
            title: Text(
              itemMap['productName'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text('$quantity x Rp ${_formatNumber(price)}'),
            trailing: Text(
              'Rp ${_formatNumber(subtotal)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildShippingCard(String status) {
    final canEdit = status == 'paid' || status == 'processing';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_hasShipping)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
                  const SizedBox(width: 6),
                  Text(
                    'Sudah diinput',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _ekspedisiList.contains(_selectedEkspedisi) ? _selectedEkspedisi : 'JNE',
            decoration: const InputDecoration(
              labelText: 'Pilih Ekspedisi',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.local_shipping),
            ),
            items: _ekspedisiList.map((eks) {
              return DropdownMenuItem(value: eks, child: Text(eks));
            }).toList(),
            onChanged: canEdit ? (value) {
              setState(() => _selectedEkspedisi = value ?? 'JNE');
            } : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _noResiController,
            enabled: canEdit,
            decoration: const InputDecoration(
              labelText: 'No. Resi *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.qr_code),
            ),
          ),
          if (canEdit) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveShippingInfo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_isLoading ? 'MENYIMPAN...' : 'SIMPAN & KIRIM'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddressCard(Map<String, dynamic> data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                data['buyerName'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.phone, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                data['buyerPhone'] ?? '',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data['buyerAddress'] ?? '',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${date.day} ${months[date.month - 1]} ${date.year}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
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
