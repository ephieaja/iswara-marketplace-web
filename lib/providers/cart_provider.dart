import 'package:flutter/foundation.dart';

class CartItem {
  final String productId;
  final String productName;
  final String productImage;
  final int price;
  final String sellerId;
  final String sellerName;
  final String sellerWa;
  final String daerah;
  int quantity;

  CartItem({
    required this.productId,
    required this.productName,
    required this.productImage,
    required this.price,
    required this.sellerId,
    required this.sellerName,
    required this.sellerWa,
    required this.daerah,
    this.quantity = 1,
  });

  int get subtotal => price * quantity;

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'productName': productName,
    'productImage': productImage,
    'price': price,
    'sellerId': sellerId,
    'sellerName': sellerName,
    'sellerWa': sellerWa,
    'daerah': daerah,
    'quantity': quantity,
  };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
    productId: json['productId'] ?? '',
    productName: json['productName'] ?? '',
    productImage: json['productImage'] ?? '',
    price: json['price'] ?? 0,
    sellerId: json['sellerId'] ?? '',
    sellerName: json['sellerName'] ?? '',
    sellerWa: json['sellerWa'] ?? '',
    daerah: json['daerah'] ?? '',
    quantity: json['quantity'] ?? 1,
  );
}

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  int get itemCount => _items.length;

  int get totalAmount => _items.fold(0, (sum, item) => sum + item.subtotal);

  int get uniqueSellerCount {
    final sellerIds = _items.map((e) => e.sellerId).toSet();
    return sellerIds.length;
  }

  bool isInCart(String productId) {
    return _items.any((item) => item.productId == productId);
  }

  void addItem(CartItem item) {
    final existingIndex = _items.indexWhere((i) => i.productId == item.productId);

    if (existingIndex >= 0) {
      _items[existingIndex].quantity += 1;
    } else {
      _items.add(item);
    }

    notifyListeners();
  }

  void removeItem(String productId) {
    _items.removeWhere((item) => item.productId == productId);
    notifyListeners();
  }

  void updateQuantity(String productId, int quantity) {
    final index = _items.indexWhere((item) => item.productId == productId);

    if (index >= 0) {
      if (quantity <= 0) {
        _items.removeAt(index);
      } else {
        _items[index].quantity = quantity;
      }
      notifyListeners();
    }
  }

  void incrementQuantity(String productId) {
    final index = _items.indexWhere((item) => item.productId == productId);
    if (index >= 0) {
      _items[index].quantity += 1;
      notifyListeners();
    }
  }

  void decrementQuantity(String productId) {
    final index = _items.indexWhere((item) => item.productId == productId);
    if (index >= 0) {
      if (_items[index].quantity <= 1) {
        _items.removeAt(index);
      } else {
        _items[index].quantity -= 1;
      }
      notifyListeners();
    }
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  /// Get items grouped by seller
  Map<String, List<CartItem>> get itemsBySeller {
    final Map<String, List<CartItem>> grouped = {};

    for (final item in _items) {
      if (!grouped.containsKey(item.sellerId)) {
        grouped[item.sellerId] = [];
      }
      grouped[item.sellerId]!.add(item);
    }

    return grouped;
  }
}
