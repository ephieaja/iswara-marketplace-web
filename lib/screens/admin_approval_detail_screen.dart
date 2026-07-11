import 'package:flutter/material.dart';
import '../../config/theme.dart';

class AdminApprovalDetailScreen extends StatelessWidget {
  final Map<String, dynamic> sellerData;
  final String sellerDocId;
  final VoidCallback? onStatusChanged;

  const AdminApprovalDetailScreen({
    super.key,
    required this.sellerData,
    required this.sellerDocId,
    this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Seller'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.info_outline,
                size: 64,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 24),
              const Text(
                'Fitur dalam pengembangan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Seller: ${sellerData['namaLengkap'] ?? '-'}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
