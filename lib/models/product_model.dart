/// Model untuk satu variant produk.
/// Mis. variant "Merah" untuk varian_label "Warna" di produk "Baju Batik".
/// Update 8 Agt 2026 sore: tambah field `gambar` (per Shopee pattern)
/// — tiap variant bisa punya foto sendiri (mis. kemeja merah pakai foto merah).
class ProductVariant {
  final String nama;
  final int harga;
  final int stok;
  final String? sku;
  final String? gambar;  // Filename gambar variant di PB (optional, fallback ke foto produk jika null)

  ProductVariant({
    required this.nama,
    required this.harga,
    this.stok = 0,
    this.sku,
    this.gambar,
  });

  Map<String, dynamic> toJson() => {
        'nama': nama,
        'harga': harga,
        'stok': stok,
        if (sku != null && sku!.isNotEmpty) 'sku': sku,
        if (gambar != null && gambar!.isNotEmpty) 'gambar': gambar,
      };

  factory ProductVariant.fromJson(Map<String, dynamic> json) => ProductVariant(
        nama: json['nama']?.toString() ?? '',
        harga: (json['harga'] as num?)?.toInt() ?? 0,
        stok: (json['stok'] as num?)?.toInt() ?? 0,
        sku: json['sku']?.toString().isNotEmpty == true ? json['sku'].toString() : null,
        gambar: json['gambar']?.toString().isNotEmpty == true ? json['gambar'].toString() : null,
      );

  /// Display text untuk variant — mis. "Merah" atau "Merah (Rp 100.000)"
  String displayLabel() => nama;

  /// Apakah variant ini punya gambar sendiri?
  bool get hasImage => gambar != null && gambar!.isNotEmpty;
}

class ProductModel {
  final String id;
  final String idPenjual;
  final String namaToko;
  final String namaProduk;
  final String kategori;
  final String deskripsi;
  final String fotoUrl;
  final String daerah;
  final String noWaPenjual;
  final DateTime createdAt;
  final int harga;

  // Varian fields (clone pattern diskuis 8 Agt 2026)
  // Tidak semua produk punya varian. Kalau varian_list kosong/null,
  // produk pakai harga utama. Kalau ada, tampil "Mulai dari Rp X.XXX".
  final String varianLabel;
  final List<ProductVariant> varianList;

  /// Source: 'anggota' (dari `Produk` iswara_app) atau 'non_anggota'
  /// (dari `ProdukMarketplace`). Untuk routing cart/checkout yang berbeda.
  /// Default 'anggota' untuk backward compatibility.
  final String source;

  /// ID seller record. Untuk ProdukMarketplace → id SellersMarketplace record.
  /// Untuk Produk existing → null (idPenjual = user.id langsung).
  final String? sellerRecordId;

  ProductModel({
    required this.id,
    required this.idPenjual,
    required this.namaToko,
    required this.namaProduk,
    required this.kategori,
    required this.deskripsi,
    required this.fotoUrl,
    required this.daerah,
    required this.noWaPenjual,
    required this.createdAt,
    this.harga = 0,
    this.varianLabel = '',
    this.varianList = const [],
    this.source = 'anggota',
    this.sellerRecordId,
  });

  bool get hasVariants => varianList.isNotEmpty;

  /// Harga termurah — fallback ke harga utama kalau tidak ada varian.
  int get hargaDisplay {
    if (varianList.isEmpty) return harga;
    final prices = varianList.map((v) => v.harga).toList();
    return prices.reduce((a, b) => a < b ? a : b);
  }

  /// Harga tertinggi — untuk display range.
  int get hargaMax {
    if (varianList.isEmpty) return harga;
    final prices = varianList.map((v) => v.harga).toList();
    return prices.reduce((a, b) => a > b ? a : b);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'idPenjual': idPenjual,
        'namaToko': namaToko,
        'namaProduk': namaProduk,
        'kategori': kategori,
        'deskripsi': deskripsi,
        'fotoUrl': fotoUrl,
        'daerah': daerah,
        'noWaPenjual': noWaPenjual,
        'createdAt': createdAt.toIso8601String(),
        'harga': harga,
        'varian_label': varianLabel,
        'varian_list': varianList.map((v) => v.toJson()).toList(),
      };

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final rawVarianList = json['varian_list'];
    List<ProductVariant> parsedVarianList = [];
    if (rawVarianList is List) {
      parsedVarianList = rawVarianList
          .whereType<Map>()
          .map((m) => ProductVariant.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    }

    return ProductModel(
      id: json['id'] ?? '',
      idPenjual: json['idPenjual'] ?? '',
      namaToko: json['namaToko'] ?? '',
      namaProduk: json['namaProduk'] ?? '',
      kategori: json['kategori'] ?? '',
      deskripsi: json['deskripsi'] ?? '',
      fotoUrl: json['fotoUrl'] ?? '',
      daerah: json['daerah'] ?? '',
      noWaPenjual: json['noWaPenjual'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      harga: (json['harga'] as num?)?.toInt() ?? 0,
      varianLabel: json['varian_label']?.toString() ?? '',
      varianList: parsedVarianList,
    );
  }
}