/// Konfigurasi PocketBase untuk ISWARA Marketplace
///
/// PERUBAHAN ARSITEKTUR 14 Agt 2026:
/// PB DIGABUNG dengan iswara_app di `pb.iswarajatim.com` (satu instance shared).
/// Sebelumnya marketplace pakai PB terpisah di Railway.
class PocketBaseConfig {
  /// Production PB (shared dengan iswara_app).
  /// Backup ada di VPS Domainesia 202.155.132.150.
  static const String pocketBaseUrl = 'https://pb.iswarajatim.com';

  /// Collection names — diselaraskan dengan iswara_app setelah PB digabung.
  static const String usersCollection = 'users';
  static const String produkCollection = 'Produk';
  static const String produkVarianCollection = 'produk_varian';
  static const String kategoriCollection = 'Kategori';
  static const String pesananCollection = 'Pesanan';

  /// Legacy collection names (masih dipakai Fase 0, akan direfactor di Fase 3).
  static const String interaksiCollection = 'Interaksi';
  static const String penjualCollection = 'penjual';
  static const String visitorsCollection = 'visitors';
  static const String pemilikUsahaCollection = 'Pemilik_Usaha';
  static const String productViewsCollection = 'productViews';
}
