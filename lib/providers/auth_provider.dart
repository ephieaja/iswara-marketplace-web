import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  RecordModel? _user;
  bool _isLoading = false;
  String? _error;

  RecordModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;

  AuthProvider() {
    _checkAuthState();
  }

  void _checkAuthState() {
    final pb = PocketBaseService.instance;
    _user = pb.authStore.record as RecordModel?;

    pb.authStore.onChange.listen((event) {
      _user = event.record as RecordModel?;
      notifyListeners();
    });
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    AuthResult result = await _authService.loginWithEmail(
      email: email,
      password: password,
    );

    _isLoading = false;
    if (!result.isSuccess) {
      _error = result.error;
    } else {
      _user = result.user;
    }
    notifyListeners();

    return result.isSuccess;
  }

  Future<bool> register({
    required String email,
    required String password,
    String? name,
    Map<String, dynamic>? additionalData,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    AuthResult result = await _authService.registerWithEmail(
      email: email,
      password: password,
      name: name,
      additionalData: additionalData,
    );

    _isLoading = false;
    if (!result.isSuccess) {
      _error = result.error;
    } else {
      _user = result.user;
    }
    notifyListeners();

    return result.isSuccess;
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    await _authService.logout();
    _user = null;

    _isLoading = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
