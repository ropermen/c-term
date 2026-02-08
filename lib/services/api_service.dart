import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiUser {
  final String id;
  final String username;
  final String displayName;
  final String role;

  ApiUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.role,
  });

  factory ApiUser.fromJson(Map<String, dynamic> json) {
    return ApiUser(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: (json['display_name'] as String?) ?? '',
      role: (json['role'] as String?) ?? 'user',
    );
  }

  bool get isAdmin => role == 'admin';
}

class ApiService {
  static final ApiService _instance = ApiService._();
  factory ApiService() => _instance;
  ApiService._();

  static const _tokenKey = 'auth_token';
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String? _token;
  ApiUser? _currentUser;

  String? get token => _token;
  ApiUser? get currentUser => _currentUser;
  bool get isLoggedIn => _token != null;

  String get _baseUrl {
    if (kIsWeb) {
      // On web, API is served from the same origin
      return '';
    }
    return 'http://localhost:18884';
  }

  Map<String, String> get _headers {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (_token != null) {
      h['Authorization'] = 'Bearer $_token';
    }
    return h;
  }

  /// Try to restore a saved token on app startup.
  Future<bool> tryRestoreSession() async {
    final saved = await _storage.read(key: _tokenKey);
    if (saved == null || saved.isEmpty) return false;

    _token = saved;
    try {
      final user = await getMe();
      _currentUser = user;
      return true;
    } catch (_) {
      _token = null;
      await _storage.delete(key: _tokenKey);
      return false;
    }
  }

  /// Login and store the JWT token.
  Future<ApiUser> login(String username, String password) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (resp.statusCode != 200) {
      final body = jsonDecode(resp.body);
      throw Exception(body['error'] ?? 'Erro ao fazer login');
    }

    final data = jsonDecode(resp.body);
    _token = data['token'] as String;
    _currentUser = ApiUser.fromJson(data['user'] as Map<String, dynamic>);
    await _storage.write(key: _tokenKey, value: _token!);
    return _currentUser!;
  }

  /// Logout: clear token.
  Future<void> logout() async {
    _token = null;
    _currentUser = null;
    await _storage.delete(key: _tokenKey);
  }

  /// Get the current user profile.
  Future<ApiUser> getMe() async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/api/auth/me'),
      headers: _headers,
    );
    if (resp.statusCode != 200) throw Exception('Sessão expirada');
    return ApiUser.fromJson(jsonDecode(resp.body));
  }

  /// Change password.
  Future<void> changePassword(String currentPassword, String newPassword) async {
    final resp = await http.put(
      Uri.parse('$_baseUrl/api/auth/password'),
      headers: _headers,
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );
    if (resp.statusCode != 200) {
      final body = jsonDecode(resp.body);
      throw Exception(body['error'] ?? 'Erro ao alterar senha');
    }
  }

  // -- User management (admin) --

  Future<List<ApiUser>> listUsers() async {
    final resp = await http.get(
      Uri.parse('$_baseUrl/api/users'),
      headers: _headers,
    );
    if (resp.statusCode != 200) throw Exception('Erro ao listar usuários');
    final list = jsonDecode(resp.body) as List;
    return list.map((j) => ApiUser.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<ApiUser> createUser({
    required String username,
    required String password,
    String? displayName,
    String role = 'user',
  }) async {
    final resp = await http.post(
      Uri.parse('$_baseUrl/api/users'),
      headers: _headers,
      body: jsonEncode({
        'username': username,
        'password': password,
        'display_name': displayName ?? '',
        'role': role,
      }),
    );
    if (resp.statusCode != 201) {
      final body = jsonDecode(resp.body);
      throw Exception(body['error'] ?? 'Erro ao criar usuário');
    }
    return ApiUser.fromJson(jsonDecode(resp.body));
  }

  Future<ApiUser> updateUser(String id, {String? displayName, String? role, String? password}) async {
    final resp = await http.put(
      Uri.parse('$_baseUrl/api/users/$id'),
      headers: _headers,
      body: jsonEncode({
        if (displayName != null) 'display_name': displayName,
        if (role != null) 'role': role,
        if (password != null) 'password': password,
      }),
    );
    if (resp.statusCode != 200) {
      final body = jsonDecode(resp.body);
      throw Exception(body['error'] ?? 'Erro ao atualizar');
    }
    return ApiUser.fromJson(jsonDecode(resp.body));
  }

  Future<void> deleteUser(String id) async {
    final resp = await http.delete(
      Uri.parse('$_baseUrl/api/users/$id'),
      headers: _headers,
    );
    if (resp.statusCode != 200) {
      final body = jsonDecode(resp.body);
      throw Exception(body['error'] ?? 'Erro ao excluir');
    }
  }
}
