import 'package:flutter/foundation.dart';
import '../models/keyboard_key.dart';
import '../services/storage_service.dart';

class KeyboardProvider extends ChangeNotifier {
  final StorageService _storageService;
  List<KeyboardKey> _keys = [];
  bool _isLoading = false;

  KeyboardProvider({StorageService? storageService})
      : _storageService = storageService ?? StorageService();

  List<KeyboardKey> get keys => List.unmodifiable(_keys);
  List<KeyboardKey> get enabledKeys =>
      _keys.where((k) => k.enabled).toList()..sort((a, b) => a.order.compareTo(b.order));
  bool get isLoading => _isLoading;

  Future<void> loadKeys() async {
    _isLoading = true;
    notifyListeners();

    try {
      _keys = await _storageService.getKeyboardKeys();
      _keys.sort((a, b) => a.order.compareTo(b.order));
    } catch (e) {
      _keys = KeyboardKey.defaultKeys();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleKey(String keyId) async {
    final index = _keys.indexWhere((k) => k.id == keyId);
    if (index != -1) {
      _keys[index] = _keys[index].copyWith(enabled: !_keys[index].enabled);
      await _saveKeys();
      notifyListeners();
    }
  }

  Future<void> reorderKeys(int oldIndex, int newIndex) async {
    final enabledKeysList = enabledKeys;
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final movedKey = enabledKeysList.removeAt(oldIndex);
    enabledKeysList.insert(newIndex, movedKey);

    // Update order based on new positions
    for (int i = 0; i < enabledKeysList.length; i++) {
      final keyIndex = _keys.indexWhere((k) => k.id == enabledKeysList[i].id);
      if (keyIndex != -1) {
        _keys[keyIndex] = _keys[keyIndex].copyWith(order: i);
      }
    }

    await _saveKeys();
    notifyListeners();
  }

  Future<void> resetToDefaults() async {
    await _storageService.resetKeyboardKeys();
    _keys = KeyboardKey.defaultKeys();
    notifyListeners();
  }

  Future<void> _saveKeys() async {
    await _storageService.saveKeyboardKeys(_keys);
  }
}
