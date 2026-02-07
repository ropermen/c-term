import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/ssh_connection.dart';
import '../models/keyboard_key.dart';

class StorageService {
  static const String _legacyConnectionsKey = 'ssh_connections';
  static const String _connectionsKey = 'connections_v2';
  static const String _keyboardKeysKey = 'keyboard_keys';
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _terminalFontSizeKey = 'terminal_font_size';
  static const double defaultFontSize = 14.0;

  final FlutterSecureStorage _storage;

  StorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(
            encryptedSharedPreferences: true,
          ),
        );

  Future<void> migrateConnectionsIfNeeded() async {
    final String? v2Data = await _storage.read(key: _connectionsKey);
    if (v2Data != null) return;

    final String? legacyData = await _storage.read(key: _legacyConnectionsKey);
    if (legacyData == null || legacyData.isEmpty) return;

    try {
      final List<dynamic> jsonList = jsonDecode(legacyData) as List<dynamic>;
      final migrated = jsonList.map((json) {
        final map = json as Map<String, dynamic>;
        if (!map.containsKey('type')) {
          map['type'] = 'ssh';
        }
        return map;
      }).toList();

      await _storage.write(key: _connectionsKey, value: jsonEncode(migrated));
    } catch (_) {}
  }

  Future<List<Connection>> getConnections() async {
    final String? data = await _storage.read(key: _connectionsKey);
    if (data == null || data.isEmpty) {
      return [];
    }

    final List<dynamic> jsonList = jsonDecode(data) as List<dynamic>;
    return jsonList
        .map((json) => Connection.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveConnections(List<Connection> connections) async {
    final String data = jsonEncode(
      connections.map((c) => c.toJson()).toList(),
    );
    await _storage.write(key: _connectionsKey, value: data);
  }

  Future<void> addConnection(Connection connection) async {
    final connections = await getConnections();
    connections.add(connection);
    await saveConnections(connections);
  }

  Future<void> updateConnection(Connection connection) async {
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

  Future<Connection?> getConnection(String id) async {
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

  Future<double> getTerminalFontSize() async {
    final String? value = await _storage.read(key: _terminalFontSizeKey);
    if (value == null) return defaultFontSize;
    return double.tryParse(value) ?? defaultFontSize;
  }

  Future<void> setTerminalFontSize(double size) async {
    await _storage.write(key: _terminalFontSizeKey, value: size.toString());
  }
}
