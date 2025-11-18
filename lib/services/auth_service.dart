import 'package:flutter/foundation.dart';

import '../models/user.dart';
import 'api_client.dart';
import 'token_storage.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();
  final ApiClient _apiClient = ApiClient.instance;

  AppUser? currentUser;

  Future<AppUser> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final response = await _apiClient.post(
      '/api/auth/register',
      body: {
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'password': password,
      },
    );

    final token = response['token']?.toString();
    final userData = response['user'] as Map<String, dynamic>?;

    if (token == null || userData == null) {
      throw ApiException('Invalid registration response');
    }

    await TokenStorage.saveToken(token);
    currentUser = AppUser.fromJson(userData);
    return currentUser!;
  }

  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post(
      '/api/auth/login',
      body: {
        'email': email,
        'password': password,
      },
    );

    final token = response['token']?.toString();
    final userData = response['user'] as Map<String, dynamic>?;

    if (token == null || userData == null) {
      throw ApiException('Invalid login response');
    }

    await TokenStorage.saveToken(token);
    currentUser = AppUser.fromJson(userData);
    return currentUser!;
  }

  Future<AppUser?> fetchCurrentUser() async {
    try {
      final response = await _apiClient.get('/api/auth/me', authenticated: true);
      final userData = response['user'] as Map<String, dynamic>?;
      if (userData == null) return null;
      currentUser = AppUser.fromJson(userData);
      return currentUser;
    } catch (error, stackTrace) {
      debugPrint('fetchCurrentUser error: $error\n$stackTrace');
      return null;
    }
  }

  Future<void> logout() async {
    await TokenStorage.clearToken();
    currentUser = null;
  }

  Future<bool> hasToken() async {
    final token = await TokenStorage.getToken();
    return token != null;
  }
}

