import 'package:pocketbase/pocketbase.dart';
import '../config/pocketbase_config.dart';

class PocketBaseService {
  static PocketBase? _instance;

  PocketBaseService._();

  static PocketBase get instance {
    _instance ??= PocketBase(PocketBaseConfig.pocketBaseUrl);
    return _instance!;
  }

  static PocketBase get pb => instance;

  // ============================================
  // Collection references — MARKETPLACE (non-anggota)
  // ============================================
  static RecordService get usersAuth =>
      instance.collection(PocketBaseConfig.usersAuthCollection);
  static RecordService get sellersMarketplace =>
      instance.collection(PocketBaseConfig.sellersMarketplaceCollection);
  static RecordService get produkMarketplace =>
      instance.collection(PocketBaseConfig.produkMarketplaceCollection);
  static RecordService get produkVarianMarketplace => instance
      .collection(PocketBaseConfig.produkVarianMarketplaceCollection);
  static RecordService get pesananMarketplace =>
      instance.collection(PocketBaseConfig.pesananMarketplaceCollection);

  // ============================================
  // Collection references — SHARED
  // ============================================
  static RecordService get kategori =>
      instance.collection(PocketBaseConfig.kategoriCollection);

  // ============================================
  // Legacy getters (Fase 3 — akan direfactor)
  // ============================================
  static RecordService get interaksi =>
      instance.collection(PocketBaseConfig.interaksiCollection);
  static RecordService get penjual =>
      instance.collection(PocketBaseConfig.penjualCollection);
  static RecordService get visitors =>
      instance.collection(PocketBaseConfig.visitorsCollection);
  static RecordService get pemilikUsaha =>
      instance.collection(PocketBaseConfig.pemilikUsahaCollection);
  static RecordService get productViews =>
      instance.collection(PocketBaseConfig.productViewsCollection);
}