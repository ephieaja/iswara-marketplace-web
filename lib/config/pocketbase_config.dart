/// Konfigurasi PocketBase untuk ISWARA Marketplace
/// Database terpisah dari iswara_app
class PocketBaseConfig {
  /// ============================================
  /// GANTI URL INI SESUAI ENVIRONMENT
  /// ============================================
  ///
  /// LOCAL DEVELOPMENT:
  ///   http://127.0.0.1:8091
  ///
  /// RAILWAY PRODUCTION:
  ///   https://iswara-pocketbase-marketplace.up.railway.app
  ///   (ganti dengan URL Railway kamu setelah deploy)
  ///
  /// RENDER PRODUCTION:
  ///   https://iswara-pocketbase-marketplace.onrender.com
  ///   (ganti dengan URL Render kamu setelah deploy)
  ///
  /// ============================================

  // TODO: Ganti URL ini setelah PocketBase di-deploy online
  // 
 static const String pocketBaseUrl = 'https://iswara-pocketbase-marketplace-production.up.railway.app';


  /// Collection names
  static const String usersCollection = 'users';
  static const String produkCollection = 'Produk';
  static const String kategoriCollection = 'Kategori';
  static const String pesananCollection = 'Pesanan';
  static const String pemilikUsahaCollection = 'Pemilik_Usaha';
  static const String interaksiCollection = 'Interaksi';
}
