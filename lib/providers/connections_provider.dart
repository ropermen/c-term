import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/ssh_connection.dart';
import '../services/storage_service.dart';

class ConnectionsProvider extends ChangeNotifier {
  final StorageService _storageService;
  final Uuid _uuid = const Uuid();

  List<Connection> _connections = [];
  bool _isLoading = false;
  String? _error;

  ConnectionsProvider({StorageService? storageService})
      : _storageService = storageService ?? StorageService();

  List<Connection> get connections => List.unmodifiable(_connections);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadConnections() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _storageService.migrateConnectionsIfNeeded();
      _connections = await _storageService.getConnections();
    } catch (e) {
      _error = 'Erro ao carregar conexões: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addConnection({
    required String name,
    required String host,
    int port = 22,
    required String username,
    String? password,
    String? privateKey,
    ConnectionType type = ConnectionType.ssh,
    String? domain,
    RdpScaleMode rdpScaleMode = RdpScaleMode.fit,
  }) async {
    final connection = Connection(
      id: _uuid.v4(),
      name: name,
      host: host,
      port: port,
      username: username,
      password: password,
      privateKey: privateKey,
      type: type,
      domain: domain,
      rdpScaleMode: rdpScaleMode,
    );

    try {
      await _storageService.addConnection(connection);
      _connections.add(connection);
      notifyListeners();
    } catch (e) {
      _error = 'Erro ao adicionar conexão: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateConnection(Connection connection) async {
    try {
      await _storageService.updateConnection(connection);
      final index = _connections.indexWhere((c) => c.id == connection.id);
      if (index != -1) {
        _connections[index] = connection;
        notifyListeners();
      }
    } catch (e) {
      _error = 'Erro ao atualizar conexão: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteConnection(String id) async {
    try {
      await _storageService.deleteConnection(id);
      _connections.removeWhere((c) => c.id == id);
      notifyListeners();
    } catch (e) {
      _error = 'Erro ao remover conexão: $e';
      notifyListeners();
      rethrow;
    }
  }

  Connection? getConnection(String id) {
    try {
      return _connections.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> reorderConnections(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final connection = _connections.removeAt(oldIndex);
    _connections.insert(newIndex, connection);
    notifyListeners();

    try {
      await _storageService.saveConnections(_connections);
    } catch (e) {
      _error = 'Erro ao salvar ordem: $e';
      notifyListeners();
    }
  }
}
