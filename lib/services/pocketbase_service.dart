import 'package:pocketbase/pocketbase.dart';
import '../config/pocketbase_config.dart';

class PocketBaseService {
  static PocketBase? _instance;

  PocketBaseService._();

  static PocketBase get instance {
    _instance ??= PocketBase(PocketBaseConfig.pocketBaseUrl);
    return _instance!;
  }

  // Convenience getters
  static PocketBase get pb => instance;

  // Collection references
  static RecordService get users => instance.collection(PocketBaseConfig.usersCollection);
  static RecordService get produk => instance.collection(PocketBaseConfig.produkCollection);
  static RecordService get kategori => instance.collection(PocketBaseConfig.kategoriCollection);
  static RecordService get pesanan => instance.collection(PocketBaseConfig.pesananCollection);
  static RecordService get pemilikUsaha => instance.collection(PocketBaseConfig.pemilikUsahaCollection);
  static RecordService get interaksi => instance.collection(PocketBaseConfig.interaksiCollection);
}
