import 'package:pocketbase/pocketbase.dart';
import '../config/pocketbase_config.dart';
import 'pocketbase_service.dart';

class AuthService {
  final PocketBase _pb = PocketBaseService.instance;

  // Get current authenticated user
  RecordModel? get currentUser => _pb.authStore.record;

  // Check if user is authenticated
  bool get isAuthenticated => _pb.authStore.isValid;

  // Stream for auth state changes
  Stream<RecordModel?> get authStateChanges => _pb.authStore.onChange.map((event) => event.record as RecordModel?);

  // Register dengan email & password
  Future<AuthResult> registerWithEmail({
    required String email,
    required String password,
    String? name,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final data = {
        'email': email,
        'password': password,
        'passwordConfirm': password,
        'name': name ?? email.split('@').first,
        ...?additionalData,
      };

      final result = await _pb.collection(PocketBaseConfig.usersCollection).create(
        body: data,
      );

      // Auto login after registration
      await _pb.collection(PocketBaseConfig.usersCollection).authWithPassword(
        email,
        password,
      );

      return AuthResult.success(result);
    } on ClientException catch (e) {
      return AuthResult.error(_getErrorMessage(e));
    } catch (e) {
      return AuthResult.error('Terjadi kesalahan: $e');
    }
  }

  // Login dengan email & password
  Future<AuthResult> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _pb.collection(PocketBaseConfig.usersCollection).authWithPassword(
        email,
        password,
      );
      return AuthResult.success(result.record);
    } on ClientException catch (e) {
      return AuthResult.error(_getErrorMessage(e));
    } catch (e) {
      return AuthResult.error('Terjadi kesalahan: $e');
    }
  }

  // Logout
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

// Helper class untuk result
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
