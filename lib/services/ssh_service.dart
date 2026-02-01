import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import '../models/ssh_connection.dart';

class SSHSession {
  final String id;
  final SSHConnection connection;
  final SSHClient client;
  final SSHSession? shell;
  final StreamController<Uint8List> _outputController;
  bool _isConnected = false;

  SSHSession._({
    required this.id,
    required this.connection,
    required this.client,
    this.shell,
  }) : _outputController = StreamController<Uint8List>.broadcast();

  Stream<Uint8List> get output => _outputController.stream;
  bool get isConnected => _isConnected;

  void _markConnected() => _isConnected = true;
  void _markDisconnected() => _isConnected = false;

  StreamController<Uint8List> get outputController => _outputController;

  void dispose() {
    _markDisconnected();
    _outputController.close();
    client.close();
  }
}

class SSHService {
  final Map<String, SSHSession> _sessions = {};

  Map<String, SSHSession> get sessions => Map.unmodifiable(_sessions);

  Future<SSHSession> connect(SSHConnection connection) async {
    final socket = await SSHSocket.connect(
      connection.host,
      connection.port,
      timeout: const Duration(seconds: 30),
    );

    SSHClient client;

    if (connection.privateKey != null && connection.privateKey!.isNotEmpty) {
      final keyPair = SSHKeyPair.fromPem(connection.privateKey!);
      client = SSHClient(
        socket,
        username: connection.username,
        identities: [keyPair],
      );
    } else if (connection.password != null) {
      client = SSHClient(
        socket,
        username: connection.username,
        onPasswordRequest: () => connection.password!,
      );
    } else {
      throw Exception('No authentication method provided');
    }

    final session = SSHSession._(
      id: connection.id,
      connection: connection,
      client: client,
    );

    session._markConnected();
    _sessions[connection.id] = session;

    return session;
  }

  Future<void> startShell(
    SSHSession session, {
    required void Function(Uint8List data) onData,
    int width = 80,
    int height = 24,
  }) async {
    final shell = await session.client.shell(
      pty: SSHPtyConfig(
        width: width,
        height: height,
      ),
    );

    shell.stdout.listen((data) {
      session.outputController.add(data);
      onData(data);
    });

    shell.stderr.listen((data) {
      session.outputController.add(data);
      onData(data);
    });

    shell.done.then((_) {
      session._markDisconnected();
    });
  }

  Future<void> write(SSHSession session, String data) async {
    final shell = await session.client.shell();
    shell.write(utf8.encode(data) as Uint8List);
  }

  Future<void> writeToShell(SSHClient client, String data) async {
    // This will be handled by the terminal widget directly
  }

  void resize(SSHSession session, int width, int height) {
    // PTY resize is handled at shell creation
  }

  void disconnect(String sessionId) {
    final session = _sessions[sessionId];
    if (session != null) {
      session.dispose();
      _sessions.remove(sessionId);
    }
  }

  void disconnectAll() {
    for (final session in _sessions.values) {
      session.dispose();
    }
    _sessions.clear();
  }

  bool isConnected(String sessionId) {
    return _sessions[sessionId]?.isConnected ?? false;
  }
}
