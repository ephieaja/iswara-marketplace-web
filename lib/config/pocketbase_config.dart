/// Konfigurasi PocketBase untuk ISWARA Marketplace
///
/// PERUBAHAN ARSITEKTUR 14 Agt 2026:
/// - PB DIGABUNG dengan iswara_app di `pb.iswarajatim.com` (satu instance shared)
/// - Marketplace pakai 5 collection TERPISAH dari iswara_app (sesuai diskusi 14 Agt):
///   * `users_auth` — untuk login marketplace (bukan anggota iswara_app)
///   * `SellersMarketplace` — extension data seller non-anggota
///   * `ProdukMarketplace` — produk non-anggota
///   * `produk_varian_marketplace` — varian produk non-anggota
///   * `PesananMarketplace` — pesanan marketplace
///
/// Collection existing iswara_app (Produk, Kategori, users, produk_varian, Pesanan, dll)
/// tetap dipakai oleh iswara_app, TIDAK diganggu marketplace.
class PocketBaseConfig {
  /// Production PB (shared dengan iswara_app).
  /// Backup ada di VPS Domainesia 202.155.132.150.
  static const String pocketBaseUrl = 'https://pb.iswarajatim.com';

  // ============================================
  // Collection names — MARKETPLACE (non-anggota)
  // ============================================
  /// Auth collection untuk login marketplace (bukan untuk anggota iswara_app).
  /// 1 no WA = 1 akun cross-collection (dicek di app layer).
  static const String usersAuthCollection = 'users_auth';

  /// Extension data seller non-anggota (linked ke users_auth via `user` field).
  /// Berisi profil toko, alamat, status verifikasi, social media (privat).
  /// NIK & foto_ktp DEFERRED (alasan keamanan data KTP).
  static const String sellersMarketplaceCollection = 'SellersMarketplace';

  /// Produk dari seller non-anggota (linked ke SellersMarketplace via `seller` field).
  /// Berisi cover (max 15 file, 200KB each), kategori, harga, dll.
  /// Varian ada di collection terpisah.
  static const String produkMarketplaceCollection = 'ProdukMarketplace';

  /// Varian produk non-anggota (linked ke ProdukMarketplace via `produk` field).
  /// Max 3 foto per varian, 200KB each. Total foto per produk max 15 (cover+varian).
  static const String produkVarianMarketplaceCollection =
      'produk_varian_marketplace';

  /// Pesanan marketplace (linked ke users_auth `buyer` & SellersMarketplace `seller`).
  /// Berisi items, ongkir, total, status pesanan, no resi.
  static const String pesananMarketplaceCollection = 'PesananMarketplace';

  // ============================================
  // Collection names — SHARED (dipakai iswara_app & marketplace)
  // ============================================
  /// Kategori produk (shared, sama untuk anggota & non-anggota).
  static const String kategoriCollection = 'Kategori';

  // ============================================
  // Legacy collection names (Fase 3 — akan direfactor)
  // ============================================
  /// Legacy collection — akan dihapus saat ProfileScreen & visitor/katalog direfactor.
  /// Untuk saat ini masih dipakai Fase 0.
  static const String interaksiCollection = 'Interaksi';
  static const String penjualCollection = 'penjual';
  static const String visitorsCollection = 'visitors';
  static const String pemilikUsahaCollection = 'Pemilik_Usaha';
  static const String productViewsCollection = 'productViews';

  // ============================================
  // Collection names — ISWARA_APP (legacy, untuk sementara)
  // ============================================
  /// ⚠️ LEGACY: dipakai iswara_app untuk ANGGOTA. Collection ini BUKAN untuk
  /// marketplace app — marketplace pakai collection terpisah (lihat MARKETPLACE
  /// section di atas). Disini didefinisikan untuk backward compatibility
  /// selama transisi. Akan dihapus di Fase 3 setelah semua screen dimigrasi.
  ///
  /// Produk anggota iswara_app auto-sync ke marketplace (per memory
  /// `iswara-app-seller-auto-sync-to-marketplace`).
  static const String usersCollection = 'users'; // ANGGOTA, BUKAN AUTH
  static const String produkCollection = 'Produk'; // PRODUK ANGGOTA
  static const String produkVarianCollection = 'produk_varian'; // VARIAN ANGGOTA
  static const String pesananCollection = 'Pesanan'; // PESANAN ANGGOTA
}