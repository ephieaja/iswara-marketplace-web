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
  });

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
      };

  factory ProductModel.fromJson(Map<String, dynamic> json) => ProductModel(
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
      );
}
