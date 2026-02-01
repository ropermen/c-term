import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/ssh_connection.dart';
import '../services/storage_service.dart';

class ConnectionsProvider extends ChangeNotifier {
  final StorageService _storageService;
  final Uuid _uuid = const Uuid();

  List<SSHConnection> _connections = [];
  bool _isLoading = false;
  String? _error;

  ConnectionsProvider({StorageService? storageService})
      : _storageService = storageService ?? StorageService();

  List<SSHConnection> get connections => List.unmodifiable(_connections);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadConnections() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
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
  }) async {
    final connection = SSHConnection(
      id: _uuid.v4(),
      name: name,
      host: host,
      port: port,
      username: username,
      password: password,
      privateKey: privateKey,
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

  Future<void> updateConnection(SSHConnection connection) async {
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

  SSHConnection? getConnection(String id) {
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
