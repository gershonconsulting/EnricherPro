import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService _service = AuthService();

  AuthStatus _status = AuthStatus.unknown;
  User? _user;
  String? _error;

  AuthStatus get status => _status;
  User? get user => _user;
  String? get error => _error;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  // Called once at startup to restore session
  Future<void> init() async {
    final hasToken = await AuthService.hasToken();
    if (!hasToken) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    final profile = await _service.fetchProfile();
    if (profile != null) {
      _user = profile;
      _status = AuthStatus.authenticated;
    } else {
      await AuthService.clearToken();
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> register({
    required String firstName,
    required String lastName,
    required String company,
    required String title,
    required String email,
    required String password,
  }) async {
    _error = null;
    final result = await _service.register(
      firstName: firstName,
      lastName: lastName,
      company: company,
      title: title,
      email: email,
      password: password,
    );
    if (result['success'] == true) {
      _user = User.fromJson(result['user'] as Map<String, dynamic>);
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    }
    _error = result['error'] as String?;
    notifyListeners();
    return false;
  }

  Future<bool> login({required String email, required String password}) async {
    _error = null;
    final result = await _service.login(email: email, password: password);
    if (result['success'] == true) {
      _user = User.fromJson(result['user'] as Map<String, dynamic>);
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    }
    _error = result['error'] as String?;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    await AuthService.clearToken();
    _user = null;
    _status = AuthStatus.unauthenticated;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
