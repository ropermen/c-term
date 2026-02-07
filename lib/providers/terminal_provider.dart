import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:xterm/xterm.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/ssh_connection.dart';

/// Buffered UTF-8 decoder that handles partial multi-byte sequences
class Utf8StreamDecoder {
  final List<int> _buffer = [];

  String decode(Uint8List data) {
    _buffer.addAll(data);

    // Find the last complete UTF-8 sequence
    int validEnd = _buffer.length;

    // Check if the last bytes are incomplete UTF-8 sequences
    for (int i = 1; i <= 4 && i <= _buffer.length; i++) {
      final byte = _buffer[_buffer.length - i];
      if ((byte & 0xC0) == 0xC0) {
        // This is a leading byte, check if sequence is complete
        int expectedLength;
        if ((byte & 0xF8) == 0xF0) {
          expectedLength = 4;
        } else if ((byte & 0xF0) == 0xE0) {
          expectedLength = 3;
        } else if ((byte & 0xE0) == 0xC0) {
          expectedLength = 2;
        } else {
          continue;
        }

        final availableBytes = i;
        if (availableBytes < expectedLength) {
          // Incomplete sequence, don't decode these bytes yet
          validEnd = _buffer.length - i;
        }
        break;
      }
    }

    if (validEnd == 0) {
      return '';
    }

    final toDecodeBytes = _buffer.sublist(0, validEnd);
    final remaining = _buffer.sublist(validEnd);
    _buffer.clear();
    _buffer.addAll(remaining);

    return utf8.decode(toDecodeBytes, allowMalformed: true);
  }
}

enum TabWindowState { normal, minimized, maximized }

class TerminalSession {
  final String id;
  final Connection connection;
  final Terminal terminal;
  final Utf8StreamDecoder stdoutDecoder = Utf8StreamDecoder();
  final Utf8StreamDecoder stderrDecoder = Utf8StreamDecoder();
  SSHClient? client;
  SSHSession? shell;
  bool isConnected;
  bool isConnecting;
  String? error;
  TabWindowState windowState;

  TerminalSession({
    required this.id,
    required this.connection,
    required this.terminal,
    this.client,
    this.shell,
    this.isConnected = false,
    this.isConnecting = false,
    this.error,
    this.windowState = TabWindowState.normal,
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

  Future<TerminalSession> createSession(Connection connection) async {
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

    if (connection.type == ConnectionType.rdp) {
      // RDP connection is handled by RdpViewPanel widget
      session.isConnecting = false;
      session.isConnected = true;
      notifyListeners();
      return session;
    }

    if (connection.type == ConnectionType.vnc) {
      terminal.write('VNC — em breve\r\n');
      session.isConnecting = false;
      notifyListeners();
      return session;
    }

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
        terminal.write(session.stdoutDecoder.decode(data));
      });

      shell.stderr.listen((data) {
        terminal.write(session.stderrDecoder.decode(data));
      });

      shell.done.then((_) {
        session.isConnected = false;
        _updateWakelock();
        closeSession(session.id);
      });

      terminal.onOutput = (data) {
        shell.write(Uint8List.fromList(utf8.encode(data)));
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

  void toggleMinimize(String sessionId) {
    final session = _sessions[sessionId];
    if (session == null) return;
    session.windowState = session.windowState == TabWindowState.minimized
        ? TabWindowState.normal
        : TabWindowState.minimized;
    notifyListeners();
  }

  void toggleMaximize(String sessionId) {
    final session = _sessions[sessionId];
    if (session == null) return;
    session.windowState = session.windowState == TabWindowState.maximized
        ? TabWindowState.normal
        : TabWindowState.maximized;
    notifyListeners();
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
