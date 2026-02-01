import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:xterm/xterm.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/ssh_connection.dart';

class TerminalSession {
  final String id;
  final SSHConnection connection;
  final Terminal terminal;
  SSHClient? client;
  SSHSession? shell;
  bool isConnected;
  bool isConnecting;
  String? error;

  TerminalSession({
    required this.id,
    required this.connection,
    required this.terminal,
    this.client,
    this.shell,
    this.isConnected = false,
    this.isConnecting = false,
    this.error,
  });
}

class TerminalProvider extends ChangeNotifier {
  final Map<String, TerminalSession> _sessions = {};
  String? _activeSessionId;

  Map<String, TerminalSession> get sessions => Map.unmodifiable(_sessions);
  String? get activeSessionId => _activeSessionId;

  TerminalSession? get activeSession =>
      _activeSessionId != null ? _sessions[_activeSessionId] : null;

  List<TerminalSession> get sessionList => _sessions.values.toList();

  void _updateWakelock() {
    final connectedSessions = _sessions.values.where((s) => s.isConnected).length;
    if (connectedSessions > 0) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  Future<TerminalSession> createSession(SSHConnection connection) async {
    final terminal = Terminal(
      maxLines: 10000,
    );

    final session = TerminalSession(
      id: connection.id,
      connection: connection,
      terminal: terminal,
      isConnecting: true,
    );

    _sessions[connection.id] = session;
    _activeSessionId = connection.id;
    notifyListeners();

    try {
      terminal.write('Conectando a ${connection.host}:${connection.port}...\r\n');

      final socket = await SSHSocket.connect(
        connection.host,
        connection.port,
        timeout: const Duration(seconds: 30),
      );

      SSHClient client;

      if (connection.privateKey != null && connection.privateKey!.isNotEmpty) {
        final keyPairs = SSHKeyPair.fromPem(connection.privateKey!);
        client = SSHClient(
          socket,
          username: connection.username,
          identities: keyPairs,
        );
      } else if (connection.password != null) {
        client = SSHClient(
          socket,
          username: connection.username,
          onPasswordRequest: () => connection.password!,
        );
      } else {
        throw Exception('Nenhum metodo de autenticacao fornecido');
      }

      final shell = await client.shell(
        pty: SSHPtyConfig(
          type: 'xterm-256color',
          width: terminal.viewWidth,
          height: terminal.viewHeight,
        ),
      );

      session.client = client;
      session.shell = shell;
      session.isConnected = true;
      session.isConnecting = false;

      _updateWakelock();

      shell.stdout.listen((data) {
        terminal.write(String.fromCharCodes(data));
      });

      shell.stderr.listen((data) {
        terminal.write(String.fromCharCodes(data));
      });

      shell.done.then((_) {
        session.isConnected = false;
        _updateWakelock();
        closeSession(session.id);
      });

      terminal.onOutput = (data) {
        shell.write(Uint8List.fromList(data.codeUnits));
      };

      terminal.onResize = (width, height, pixelWidth, pixelHeight) {
        shell.resizeTerminal(width, height);
      };

      notifyListeners();
      return session;
    } catch (e) {
      session.isConnecting = false;
      session.error = e.toString();
      terminal.write('\r\n[Erro: ${e.toString()}]\r\n');
      _updateWakelock();
      notifyListeners();
      return session;
    }
  }

  void setActiveSession(String sessionId) {
    if (_sessions.containsKey(sessionId)) {
      _activeSessionId = sessionId;
      notifyListeners();
    }
  }

  void closeSession(String sessionId) {
    final session = _sessions[sessionId];
    if (session != null) {
      session.shell?.close();
      session.client?.close();
      _sessions.remove(sessionId);

      if (_activeSessionId == sessionId) {
        _activeSessionId = _sessions.isNotEmpty ? _sessions.keys.first : null;
      }

      _updateWakelock();
      notifyListeners();
    }
  }

  void closeAllSessions() {
    for (final session in _sessions.values) {
      session.shell?.close();
      session.client?.close();
    }
    _sessions.clear();
    _activeSessionId = null;
    _updateWakelock();
    notifyListeners();
  }

  bool hasSession(String connectionId) {
    return _sessions.containsKey(connectionId);
  }

  @override
  void dispose() {
    closeAllSessions();
    WakelockPlus.disable();
    super.dispose();
  }
}
