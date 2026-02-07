import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import '../providers/terminal_provider.dart';

@JS('IronRdpSession')
extension type IronRdpBridge._(JSObject _) implements JSObject {
  external IronRdpBridge();
  external JSPromise<JSAny?> init();
  external JSPromise<JSAny?> connect(JSObject opts);
  external void ctrlAltDel();
  external void shutdown();
  external void resize(int width, int height);
  external void onStatus(JSFunction callback);
  external void onError(JSFunction callback);
  external void onTerminate(JSFunction callback);
}

class RdpViewPanel extends StatefulWidget {
  final TerminalSession session;

  const RdpViewPanel({super.key, required this.session});

  @override
  State<RdpViewPanel> createState() => _RdpViewPanelState();
}

class _RdpViewPanelState extends State<RdpViewPanel> {
  static final _registeredViewTypes = <String>{};

  late final String _viewType;
  web.HTMLCanvasElement? _canvas;
  IronRdpBridge? _rdpSession;
  String _status = 'initializing';
  String? _error;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'rdp-canvas-${widget.session.id}';
    _setupView();
  }

  void _setupView() {
    if (_registeredViewTypes.contains(_viewType)) return;

    final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement;
    canvas.width = 1280;
    canvas.height = 720;
    canvas.style.width = '100%';
    canvas.style.height = '100%';
    canvas.style.backgroundColor = '#000';
    canvas.tabIndex = 0;
    _canvas = canvas;

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => canvas,
    );
    _registeredViewTypes.add(_viewType);

    WidgetsBinding.instance.addPostFrameCallback((_) => _initAndConnect());
  }

  Future<void> _initAndConnect() async {
    if (_disposed || _canvas == null) return;

    try {
      final rdp = IronRdpBridge();
      _rdpSession = rdp;

      rdp.onStatus(((JSAny? status) {
        final s = (status as JSString?)?.toDart ?? 'unknown';
        if (!_disposed && mounted) {
          setState(() => _status = s);
        }
      }).toJS);

      rdp.onError(((JSAny? error) {
        final e = (error as JSString?)?.toDart ?? 'Erro desconhecido';
        if (!_disposed && mounted) {
          setState(() {
            _error = e;
            _status = 'error';
          });
        }
      }).toJS);

      rdp.onTerminate(((JSAny? info) {
        if (!_disposed && mounted) {
          setState(() => _status = 'disconnected');
        }
      }).toJS);

      if (mounted) setState(() => _status = 'loading_wasm');
      await rdp.init().toDart;
      if (_disposed) return;

      if (mounted) setState(() => _status = 'connecting');

      // Derive proxy WebSocket URL from current page URL
      final loc = web.window.location;
      final wsProto = loc.protocol == 'https:' ? 'wss:' : 'ws:';
      final proxyAddress = '$wsProto//${loc.host}/rdp-proxy';

      final conn = widget.session.connection;
      final destination = '${conn.host}:${conn.port}';

      // Build options object for the JS bridge
      final opts = JSObject();
      opts['username'] = conn.username.toJS;
      opts['password'] = (conn.password ?? '').toJS;
      opts['destination'] = destination.toJS;
      opts['proxyAddress'] = proxyAddress.toJS;
      opts['canvas'] = _canvas!;
      opts['width'] = (1280 as num).toJS;
      opts['height'] = (720 as num).toJS;

      if (conn.domain != null && conn.domain!.isNotEmpty) {
        opts['domain'] = conn.domain!.toJS;
      }

      // This blocks until the session ends
      await rdp.connect(opts).toDart;

      if (!_disposed && mounted) {
        setState(() => _status = 'disconnected');
      }
    } catch (e) {
      if (!_disposed && mounted) {
        setState(() {
          _error = e.toString();
          _status = 'error';
        });
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _rdpSession?.shutdown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildStatusBar(),
        Expanded(
          child: HtmlElementView(viewType: _viewType),
        ),
        if (_status == 'connected') _buildToolbar(),
      ],
    );
  }

  Widget _buildStatusBar() {
    Color bgColor;
    String text;
    Widget leading;

    switch (_status) {
      case 'loading_wasm':
        bgColor = const Color(0xFF5B8DEF).withValues(alpha: 0.2);
        text = 'Carregando modulo RDP...';
        leading = const SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF5B8DEF)),
        );
      case 'connecting':
        bgColor = const Color(0xFF5B8DEF).withValues(alpha: 0.2);
        text = 'Conectando a ${widget.session.connection.host}...';
        leading = const SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF5B8DEF)),
        );
      case 'connected':
        return const SizedBox.shrink();
      case 'error':
        bgColor = Colors.red.shade900;
        text = _error ?? 'Erro desconhecido';
        leading = const Icon(Icons.error_outline, color: Colors.white, size: 16);
      case 'disconnected':
        bgColor = Colors.orange.shade900.withValues(alpha: 0.5);
        text = 'Sessao RDP encerrada';
        leading = const Icon(Icons.link_off, color: Colors.white, size: 16);
      default:
        bgColor = const Color(0xFF2C2C2E);
        text = _status;
        leading = const Icon(Icons.info_outline, color: Colors.white, size: 16);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: bgColor,
      child: Row(
        children: [
          leading,
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      height: 36,
      color: const Color(0xFF2C2C2E),
      child: Row(
        children: [
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => _rdpSession?.ctrlAltDel(),
            icon: const Icon(Icons.keyboard, size: 16),
            label: const Text('Ctrl+Alt+Del', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade400,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ],
      ),
    );
  }
}
