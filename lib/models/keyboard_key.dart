import 'dart:convert';

class KeyboardKey {
  final String id;
  final String label;
  final String value;
  final bool isModifier;
  bool enabled;
  int order;
  int row;

  KeyboardKey({
    required this.id,
    required this.label,
    required this.value,
    this.isModifier = false,
    this.enabled = true,
    this.order = 0,
    this.row = 1,
  });

  KeyboardKey copyWith({
    String? id,
    String? label,
    String? value,
    bool? isModifier,
    bool? enabled,
    int? order,
    int? row,
  }) {
    return KeyboardKey(
      id: id ?? this.id,
      label: label ?? this.label,
      value: value ?? this.value,
      isModifier: isModifier ?? this.isModifier,
      enabled: enabled ?? this.enabled,
      order: order ?? this.order,
      row: row ?? this.row,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'value': value,
      'isModifier': isModifier,
      'enabled': enabled,
      'order': order,
      'row': row,
    };
  }

  factory KeyboardKey.fromJson(Map<String, dynamic> json) {
    return KeyboardKey(
      id: json['id'] as String,
      label: json['label'] as String,
      value: json['value'] as String,
      isModifier: json['isModifier'] as bool? ?? false,
      enabled: json['enabled'] as bool? ?? true,
      order: json['order'] as int? ?? 0,
      row: json['row'] as int? ?? 1,
    );
  }

  static List<KeyboardKey> defaultKeys() {
    return [
      // Modifiers
      KeyboardKey(id: 'ctrl', label: 'Ctrl', value: 'CTRL', isModifier: true, order: 0),
      KeyboardKey(id: 'alt', label: 'Alt', value: 'ALT', isModifier: true, order: 1),
      // Common keys
      KeyboardKey(id: 'tab', label: 'Tab', value: '\t', order: 2),
      KeyboardKey(id: 'esc', label: 'Esc', value: '\x1B', order: 3),
      // Arrow keys
      KeyboardKey(id: 'up', label: 'Up', value: '\x1B[A', order: 4),
      KeyboardKey(id: 'down', label: 'Down', value: '\x1B[B', order: 5),
      KeyboardKey(id: 'left', label: 'Left', value: '\x1B[D', order: 6),
      KeyboardKey(id: 'right', label: 'Right', value: '\x1B[C', order: 7),
      // Delete key
      KeyboardKey(id: 'del', label: 'Del', value: '\x1B[3~', order: 8),
      // Special characters
      KeyboardKey(id: 'pipe', label: '|', value: '|', order: 9),
      KeyboardKey(id: 'amp', label: '&', value: '&', order: 10),
      KeyboardKey(id: 'semicolon', label: ';', value: ';', order: 11),
      KeyboardKey(id: 'gt', label: '>', value: '>', order: 12),
      KeyboardKey(id: 'lt', label: '<', value: '<', order: 13),
      KeyboardKey(id: 'tilde', label: '~', value: '~', order: 14),
      KeyboardKey(id: 'slash', label: '/', value: '/', order: 15),
      KeyboardKey(id: 'backslash', label: '\\', value: '\\', order: 16),
      KeyboardKey(id: 'dash', label: '-', value: '-', order: 17),
      KeyboardKey(id: 'underscore', label: '_', value: '_', order: 18),
      KeyboardKey(id: 'dot', label: '.', value: '.', order: 19),
      KeyboardKey(id: 'asterisk', label: '*', value: '*', order: 20),
      KeyboardKey(id: 'question', label: '?', value: '?', order: 21),
      KeyboardKey(id: 'exclamation', label: '!', value: '!', order: 22),
      KeyboardKey(id: 'at', label: '@', value: '@', order: 23),
      KeyboardKey(id: 'dollar', label: '\$', value: '\$', order: 24),
      KeyboardKey(id: 'hash', label: '#', value: '#', order: 25),
      KeyboardKey(id: 'percent', label: '%', value: '%', order: 26),
      KeyboardKey(id: 'caret', label: '^', value: '^', order: 27),
      KeyboardKey(id: 'lparen', label: '(', value: '(', order: 28),
      KeyboardKey(id: 'rparen', label: ')', value: ')', order: 29),
      KeyboardKey(id: 'lbracket', label: '[', value: '[', order: 30),
      KeyboardKey(id: 'rbracket', label: ']', value: ']', order: 31),
      KeyboardKey(id: 'lbrace', label: '{', value: '{', order: 32),
      KeyboardKey(id: 'rbrace', label: '}', value: '}', order: 33),
      KeyboardKey(id: 'dquote', label: '"', value: '"', order: 34),
      KeyboardKey(id: 'squote', label: "'", value: "'", order: 35),
      KeyboardKey(id: 'backtick', label: '`', value: '`', order: 36),
      KeyboardKey(id: 'equals', label: '=', value: '=', order: 37),
      KeyboardKey(id: 'plus', label: '+', value: '+', order: 38),
      KeyboardKey(id: 'colon', label: ':', value: ':', order: 39),
    ];
  }

  static String keysToJson(List<KeyboardKey> keys) {
    return jsonEncode(keys.map((k) => k.toJson()).toList());
  }

  static List<KeyboardKey> keysFromJson(String json) {
    final List<dynamic> list = jsonDecode(json);
    return list.map((e) => KeyboardKey.fromJson(e as Map<String, dynamic>)).toList();
  }
}
