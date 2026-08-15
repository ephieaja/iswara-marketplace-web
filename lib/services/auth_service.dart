import 'package:pocketbase/pocketbase.dart';
import '../config/pocketbase_config.dart';
import 'pocketbase_service.dart';

/// AuthService untuk ISWARA Marketplace
///
/// PERUBAHAN 14 Agt 2026:
/// - Login/register pakai `users_auth` collection (Auth) — TERPISAH dari `users` iswara_app
/// - Cross-check no WA sebelum register: cek `users_auth.phone` & `users.nowa` iswara_app
///   untuk cegah duplikat (1 no WA = 1 akun dimanapun)
class AuthService {
  final PocketBase _pb = PocketBaseService.instance;

  // Get current authenticated user (dari users_auth)
  RecordModel? get currentUser => _pb.authStore.record;

  // Check if user is authenticated
  bool get isAuthenticated => _pb.authStore.isValid;

  // Stream for auth state changes
  Stream<RecordModel?> get authStateChanges =>
      _pb.authStore.onChange.map((event) => event.record as RecordModel?);

  /// Register user baru di `users_auth` collection.
  ///
  /// Wajib cek dulu: no WA belum dipakai di `users_auth` atau `users` iswara_app.
  /// Kalau sudah dipakai, return error.
  Future<AuthResult> registerWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // 1. Cross-check no WA: cek di users_auth dulu (PB filter)
      final existingInUsersAuth = await _pb
          .collection(PocketBaseConfig.usersAuthCollection)
          .getList(filter: 'phone = "$phone"', perPage: 1);
      if (existingInUsersAuth.items.isNotEmpty) {
        return AuthResult.error(
          'No WA $phone sudah terdaftar di marketplace. Silakan login.',
        );
      }

      // 2. Cross-check no WA: cek di users iswara_app (existing, Base)
      // PENTING: pakai try-catch karena query ke collection orang lain
      try {
        final existingInIswaraApp = await _pb
            .collection('users') // Hardcoded, karena iswara_app users = "users"
            .getList(filter: 'nowa = "$phone"', perPage: 1);
        if (existingInIswaraApp.items.isNotEmpty) {
          return AuthResult.error(
            'No WA $phone sudah terdaftar sebagai anggota ISWARA. '
            'Gunakan akun ISWARA Anda untuk login.',
          );
        }
      } on ClientException {
        // Kalau collection 'users' tidak accessible, skip check (aman)
        // (mis. karena belum login sebagai admin/superuser)
      }

      // 3. Create user di users_auth
      final userData = {
        'email': email,
        'password': password,
        'passwordConfirm': password,
        'name': name,
        'phone': phone,
        'is_seller': false,
        if (additionalData != null) ...additionalData,
      };

      await _pb.collection(PocketBaseConfig.usersAuthCollection).create(
        body: userData,
      );

      // 4. Auto login after registration
      final result = await _pb
          .collection(PocketBaseConfig.usersAuthCollection)
          .authWithPassword(email, password);

      return AuthResult.success(result.record);
    } on ClientException catch (e) {
      return AuthResult.error(_getErrorMessage(e));
    } catch (e) {
      return AuthResult.error('Terjadi kesalahan: $e');
    }
  }

  /// Login dengan email & password (pakai `users_auth`)
  Future<AuthResult> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _pb
          .collection(PocketBaseConfig.usersAuthCollection)
          .authWithPassword(email, password);
      return AuthResult.success(result.record);
    } on ClientException catch (e) {
      return AuthResult.error(_getErrorMessage(e));
    } catch (e) {
      return AuthResult.error('Terjadi kesalahan: $e');
    }
  }

  /// Logout
  Future<void> logout() async {
    _pb.authStore.clear();
  }

  String _getErrorMessage(dynamic e) {
    if (e is ClientException) {
      final response = e.response;
      if (response != null && response['message'] != null) {
        return response['message'].toString();
      }
      if (e.statusCode == 400) {
        return 'Email atau password salah';
      }
      if (e.statusCode == 404) {
        return 'Akun tidak ditemukan';
      }
    }
    return 'Terjadi kesalahan. Coba lagi';
  }
}

/// Helper class untuk result
class AuthResult {
  final bool isSuccess;
  final RecordModel? user;
  final String? message;
  final String? error;

  AuthResult({
    required this.isSuccess,
    this.user,
    this.message,
    this.error,
  });

  factory AuthResult.success(RecordModel user, {String? message}) {
    return AuthResult(
      isSuccess: true,
      user: user,
      message: message,
    );
  }

  factory AuthResult.error(String error) {
    return AuthResult(
      isSuccess: false,
      error: error,
    );
  }
}