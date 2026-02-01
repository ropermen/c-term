import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/ssh_connection.dart';
import '../models/keyboard_key.dart';

class StorageService {
  static const String _connectionsKey = 'ssh_connections';
  static const String _keyboardKeysKey = 'keyboard_keys';
  static const String _biometricEnabledKey = 'biometric_enabled';

  final FlutterSecureStorage _storage;

  StorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(
            encryptedSharedPreferences: true,
          ),
        );

  Future<List<SSHConnection>> getConnections() async {
    final String? data = await _storage.read(key: _connectionsKey);
    if (data == null || data.isEmpty) {
      return [];
    }

    final List<dynamic> jsonList = jsonDecode(data) as List<dynamic>;
    return jsonList
        .map((json) => SSHConnection.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveConnections(List<SSHConnection> connections) async {
    final String data = jsonEncode(
      connections.map((c) => c.toJson()).toList(),
    );
    await _storage.write(key: _connectionsKey, value: data);
  }

  Future<void> addConnection(SSHConnection connection) async {
    final connections = await getConnections();
    connections.add(connection);
    await saveConnections(connections);
  }

  Future<void> updateConnection(SSHConnection connection) async {
    final connections = await getConnections();
    final index = connections.indexWhere((c) => c.id == connection.id);
    if (index != -1) {
      connections[index] = connection;
      await saveConnections(connections);
    }
  }

  Future<void> deleteConnection(String id) async {
    final connections = await getConnections();
    connections.removeWhere((c) => c.id == id);
    await saveConnections(connections);
  }

  Future<SSHConnection?> getConnection(String id) async {
    final connections = await getConnections();
    try {
      return connections.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  Future<List<KeyboardKey>> getKeyboardKeys() async {
    final String? data = await _storage.read(key: _keyboardKeysKey);
    if (data == null || data.isEmpty) {
      return KeyboardKey.defaultKeys();
    }
    try {
      return KeyboardKey.keysFromJson(data);
    } catch (e) {
      return KeyboardKey.defaultKeys();
    }
  }

  Future<void> saveKeyboardKeys(List<KeyboardKey> keys) async {
    final String data = KeyboardKey.keysToJson(keys);
    await _storage.write(key: _keyboardKeysKey, value: data);
  }

  Future<void> resetKeyboardKeys() async {
    await _storage.delete(key: _keyboardKeysKey);
  }

  Future<bool> isBiometricEnabled() async {
    final String? value = await _storage.read(key: _biometricEnabledKey);
    return value == 'true';
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _biometricEnabledKey, value: enabled.toString());
  }
}
