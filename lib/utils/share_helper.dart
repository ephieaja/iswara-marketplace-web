import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

class ShareHelper {
  /// Share app link to other people
  static Future<void> shareApp() async {
    const appUrl = 'https://iswara-jawa-timur-5f32c.web.app';

    final message = '''
🛒 *MARKETPLACE AISYIYAH JAWA TIMUR*

Tangguh Berdaya Berkemajuan

Kunjungi toko online produk Islami dari Keluarga Muhammadiyah se-Jawa Timur!

📱 Kunjungi: $appUrl

_Marketplace Aisyiyah Jawa Timur_
PW Jawa Timur
''';

    await Share.share(message, subject: 'Marketplace Aisyiyah Jawa Timur');
  }

  /// Share product to other people
  static Future<void> shareProduct({
    required String productName,
    required String price,
    required String sellerName,
    required String daerah,
    String? productLink,
  }) async {
    final message = '''
🛍️ *PRODUK AISYIYAH JATIM*

*$productName*

💰 Harga: Rp $price

🏪 Penjual: $sellerName
📍 Daerah: $daerah

${productLink != null ? '🔗 Link: $productLink\n' : ''}
_Marketplace Aisyiyah Jawa Timur_
Tangguh Berdaya Berkemajuan
''';

    await Share.share(message, subject: 'Produk: $productName');
  }

  /// Share store link
  static Future<void> shareStore({
    required String storeName,
    required String sellerName,
    required String daerah,
    required String noWa,
    String? storeLink,
  }) async {
    final message = '''
🏪 *TOKO AISYIYAH JATIM*

*$storeName*

👤 Pemilik: $sellerName
📍 Lokasi: $daerah
📱 WA: $noWa

${storeLink != null ? '🔗 Kunjungi Toko: $storeLink\n' : ''}
_Marketplace Aisyiyah Jawa Timur_
Tangguh Berdaya Berkemajuan
''';

    await Share.share(message, subject: 'Toko: $storeName');
  }

  /// Share order info
  static Future<void> shareOrder({
    required String orderId,
    required String totalAmount,
    required String status,
  }) async {
    final message = '''
📦 *INFO PESANAN*

Order ID: #$orderId
Total: Rp $totalAmount
Status: $status

_Marketplace Aisyiyah Jawa Timur_
Tangguh Berdaya Berkemajuan
''';

    await Share.share(message, subject: 'Pesanan #$orderId');
  }

  /// Open WhatsApp with pre-filled message
  static Future<void> openWhatsApp({
    required String phone,
    String? message,
  }) async {
    String formattedNumber = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (formattedNumber.startsWith('0')) {
      formattedNumber = '62${formattedNumber.substring(1)}';
    }

    final encodedMessage = message != null
        ? Uri.encodeComponent(message)
        : '';

    final url = Uri.parse(
      'https://wa.me/$formattedNumber${message != null ? '?text=$encodedMessage' : ''}'
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}

/// Share button widget for reuse
class ShareButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onPressed;

  const ShareButton({
    super.key,
    required this.icon,
    required this.label,
    this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color ?? Theme.of(context).primaryColor,
        side: BorderSide(color: color ?? Theme.of(context).primaryColor),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

/// Floating share button
class FloatingShareButton extends StatelessWidget {
  final VoidCallback onPressed;

  const FloatingShareButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: Theme.of(context).primaryColor,
      child: const Icon(Icons.share, color: Colors.white),
    );
  }
}
