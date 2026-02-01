import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/ssh_connection.dart';

class StorageService {
  static const String _connectionsKey = 'ssh_connections';

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
}
