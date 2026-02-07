import 'dart:convert';

enum ConnectionType {
  ssh,
  rdp,
  vnc;

  String toJson() => name;

  static ConnectionType fromJson(String? value) {
    switch (value) {
      case 'rdp':
        return ConnectionType.rdp;
      case 'vnc':
        return ConnectionType.vnc;
      default:
        return ConnectionType.ssh;
    }
  }

  int get defaultPort {
    switch (this) {
      case ConnectionType.ssh:
        return 22;
      case ConnectionType.rdp:
        return 3389;
      case ConnectionType.vnc:
        return 5900;
    }
  }

  String get label {
    switch (this) {
      case ConnectionType.ssh:
        return 'SSH';
      case ConnectionType.rdp:
        return 'RDP';
      case ConnectionType.vnc:
        return 'VNC';
    }
  }
}

class Connection {
  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final String? password;
  final String? privateKey;
  final String? domain;
  final ConnectionType type;
  final RdpScaleMode rdpScaleMode;
  final DateTime createdAt;
  final DateTime updatedAt;

  Connection({
    required this.id,
    required this.name,
    required this.host,
    int? port,
    required this.username,
    this.password,
    this.privateKey,
    this.domain,
    this.type = ConnectionType.ssh,
    this.rdpScaleMode = RdpScaleMode.fit,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : port = port ?? type.defaultPort,
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Connection copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? username,
    String? password,
    String? privateKey,
    String? domain,
    ConnectionType? type,
    RdpScaleMode? rdpScaleMode,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Connection(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      privateKey: privateKey ?? this.privateKey,
      domain: domain ?? this.domain,
      type: type ?? this.type,
      rdpScaleMode: rdpScaleMode ?? this.rdpScaleMode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'host': host,
      'port': port,
      'username': username,
      'password': password,
      'privateKey': privateKey,
      'domain': domain,
      'type': type.toJson(),
      'rdpScaleMode': rdpScaleMode.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Connection.fromJson(Map<String, dynamic> json) {
    final type = ConnectionType.fromJson(json['type'] as String?);
    return Connection(
      id: json['id'] as String,
      name: json['name'] as String,
      host: json['host'] as String,
      port: json['port'] as int? ?? type.defaultPort,
      username: json['username'] as String? ?? '',
      password: json['password'] as String?,
      privateKey: json['privateKey'] as String?,
      domain: json['domain'] as String?,
      type: type,
      rdpScaleMode: RdpScaleMode.fromJson(json['rdpScaleMode'] as String?),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory Connection.fromJsonString(String jsonString) {
    return Connection.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  @override
  String toString() {
    return 'Connection(id: $id, name: $name, type: ${type.label}, host: $host, port: $port, username: $username)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Connection && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

enum RdpScaleMode {
  fit,
  stretch,
  clientResolution;

  String toJson() => name;

  static RdpScaleMode fromJson(String? value) {
    switch (value) {
      case 'stretch':
        return RdpScaleMode.stretch;
      case 'clientResolution':
        return RdpScaleMode.clientResolution;
      default:
        return RdpScaleMode.fit;
    }
  }

  String get label {
    switch (this) {
      case RdpScaleMode.fit:
        return 'Ajustar';
      case RdpScaleMode.stretch:
        return 'Esticar';
      case RdpScaleMode.clientResolution:
        return 'Resolução do cliente';
    }
  }

  String get description {
    switch (this) {
      case RdpScaleMode.fit:
        return 'Mantém proporção, com barras laterais se necessário';
      case RdpScaleMode.stretch:
        return 'Preenche toda a área, pode distorcer a imagem';
      case RdpScaleMode.clientResolution:
        return 'Usa a resolução real do painel como resolução RDP';
    }
  }
}

typedef SSHConnection = Connection;
