class OrderItemModel {
  final String productId;
  final String productName;
  final String productImage;
  final int price;
  final int quantity;
  final String sellerId;
  final String sellerName;
  final String sellerWa;
  final String daerah;

  OrderItemModel({
    required this.productId,
    required this.productName,
    required this.productImage,
    required this.price,
    required this.quantity,
    required this.sellerId,
    required this.sellerName,
    required this.sellerWa,
    required this.daerah,
  });

  int get subtotal => price * quantity;

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'productName': productName,
    'productImage': productImage,
    'price': price,
    'quantity': quantity,
    'sellerId': sellerId,
    'sellerName': sellerName,
    'sellerWa': sellerWa,
    'daerah': daerah,
  };

  factory OrderItemModel.fromJson(Map<String, dynamic> json) => OrderItemModel(
    productId: json['productId'] ?? '',
    productName: json['productName'] ?? '',
    productImage: json['productImage'] ?? '',
    price: json['price'] ?? 0,
    quantity: json['quantity'] ?? 1,
    sellerId: json['sellerId'] ?? '',
    sellerName: json['sellerName'] ?? '',
    sellerWa: json['sellerWa'] ?? '',
    daerah: json['daerah'] ?? '',
  );
}

class OrderModel {
  final String id;
  final String buyerId;
  final String buyerName;
  final String buyerPhone;
  final String buyerAddress;
  final List<OrderItemModel> items;
  final int totalAmount;
  final String status; // pending, paid, processing, shipped, completed, cancelled
  final String paymentMethod; // QRIS
  final String paymentStatus; // unpaid, paid, refunded
  final DateTime createdAt;
  final DateTime? paidAt;

  // Shipping/Expedition fields
  final String? ekspedisi;        // Nama ekspedisi (JNE, J&T, SiCepat, dll)
  final String? noResi;           // Nomor resi pengiriman
  final String? shippingCost;    // Biaya ongkir
  final DateTime? shippedAt;      // Waktu pengiriman
  final DateTime? deliveredAt;    // Waktu diterima

  OrderModel({
    required this.id,
    required this.buyerId,
    required this.buyerName,
    required this.buyerPhone,
    required this.buyerAddress,
    required this.items,
    required this.totalAmount,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.createdAt,
    this.paidAt,
    this.ekspedisi,
    this.noResi,
    this.shippingCost,
    this.shippedAt,
    this.deliveredAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'buyerId': buyerId,
    'buyerName': buyerName,
    'buyerPhone': buyerPhone,
    'buyerAddress': buyerAddress,
    'items': items.map((e) => e.toJson()).toList(),
    'totalAmount': totalAmount,
    'status': status,
    'paymentMethod': paymentMethod,
    'paymentStatus': paymentStatus,
    'createdAt': createdAt.toIso8601String(),
    'paidAt': paidAt?.toIso8601String(),
    'ekspedisi': ekspedisi,
    'noResi': noResi,
    'shippingCost': shippingCost,
    'shippedAt': shippedAt?.toIso8601String(),
    'deliveredAt': deliveredAt?.toIso8601String(),
  };

  factory OrderModel.fromJson(Map<String, dynamic> json) => OrderModel(
    id: json['id'] ?? '',
    buyerId: json['buyerId'] ?? '',
    buyerName: json['buyerName'] ?? '',
    buyerPhone: json['buyerPhone'] ?? '',
    buyerAddress: json['buyerAddress'] ?? '',
    items: (json['items'] as List<dynamic>?)
        ?.map((e) => OrderItemModel.fromJson(e as Map<String, dynamic>))
        .toList() ?? [],
    totalAmount: json['totalAmount'] ?? 0,
    status: json['status'] ?? 'pending',
    paymentMethod: json['paymentMethod'] ?? 'QRIS',
    paymentStatus: json['paymentStatus'] ?? 'unpaid',
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'])
        : DateTime.now(),
    paidAt: json['paidAt'] != null
        ? DateTime.parse(json['paidAt'])
        : null,
    ekspedisi: json['ekspedisi'],
    noResi: json['noResi'],
    shippingCost: json['shippingCost'],
    shippedAt: json['shippedAt'] != null
        ? DateTime.parse(json['shippedAt'])
        : null,
    deliveredAt: json['deliveredAt'] != null
        ? DateTime.parse(json['deliveredAt'])
        : null,
  );

  /// Status display helpers
  static String getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Menunggu Pembayaran';
      case 'paid':
        return 'Sudah Dibayar';
      case 'processing':
        return 'Diproses';
      case 'shipped':
        return 'Dikirim';
      case 'completed':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status;
    }
  }

  /// Status colors
  static int getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return 0xFFFF9800; // Orange
      case 'paid':
        return 0xFF2196F3; // Blue
      case 'processing':
        return 0xFF9C27B0; // Purple
      case 'shipped':
        return 0xFF00BCD4; // Cyan
      case 'completed':
        return 0xFF4CAF50; // Green
      case 'cancelled':
        return 0xFFF44336; // Red
      default:
        return 0xFF757575; // Grey
    }
  }

  /// Check if order has shipping info
  bool get hasShipping => noResi != null && noResi!.isNotEmpty;
}
