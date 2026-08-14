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

  // Collection references — sesuai PB digabung dengan iswara_app.
  static RecordService get users => instance.collection(PocketBaseConfig.usersCollection);
  static RecordService get produk => instance.collection(PocketBaseConfig.produkCollection);
  static RecordService get produkVarian => instance.collection(PocketBaseConfig.produkVarianCollection);
  static RecordService get kategori => instance.collection(PocketBaseConfig.kategoriCollection);
  static RecordService get pesanan => instance.collection(PocketBaseConfig.pesananCollection);

  // Legacy getters (Fase 0 — akan direfactor di Fase 3 saat katalog/visitor dihapus).
  static RecordService get interaksi => instance.collection(PocketBaseConfig.interaksiCollection);
  static RecordService get penjual => instance.collection(PocketBaseConfig.penjualCollection);
  static RecordService get visitors => instance.collection(PocketBaseConfig.visitorsCollection);
  static RecordService get pemilikUsaha => instance.collection(PocketBaseConfig.pemilikUsahaCollection);
  static RecordService get productViews => instance.collection(PocketBaseConfig.productViewsCollection);
}