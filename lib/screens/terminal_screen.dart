import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';
import '../providers/terminal_provider.dart';
import '../services/storage_service.dart';
import '../widgets/terminal_keyboard.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final _storageService = StorageService();
  double _fontSize = StorageService.defaultFontSize;

  @override
  void initState() {
    super.initState();
    _loadFontSize();
  }

  Future<void> _loadFontSize() async {
    final size = await _storageService.getTerminalFontSize();
    if (mounted) {
      setState(() => _fontSize = size);
    }
  }

  Future<void> _setFontSize(double size) async {
    await _storageService.setTerminalFontSize(size);
    if (mounted) {
      setState(() => _fontSize = size);
    }
  }

  void _showFontSizeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tamanho da fonte'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _fontSize > 8
                        ? () {
                            final newSize = _fontSize - 1;
                            setDialogState(() {});
                            _setFontSize(newSize);
                          }
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Container(
                    width: 60,
                    alignment: Alignment.center,
                    child: Text(
                      '${_fontSize.toInt()}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _fontSize < 32
                        ? () {
                            final newSize = _fontSize + 1;
                            setDialogState(() {});
                            _setFontSize(newSize);
                          }
                        : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Slider(
                value: _fontSize,
                min: 8,
                max: 32,
                divisions: 24,
                label: '${_fontSize.toInt()}',
                onChanged: (value) {
                  setDialogState(() {});
                  _setFontSize(value.roundToDouble());
                },
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [10, 12, 14, 16, 18, 20].map((size) {
                  final isSelected = _fontSize.toInt() == size;
                  return ChoiceChip(
                    label: Text('$size'),
                    selected: isSelected,
                    onSelected: (_) {
                      setDialogState(() {});
                      _setFontSize(size.toDouble());
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Fechar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TerminalProvider>(
      builder: (context, provider, _) {
        if (provider.sessions.isEmpty) {
          return Scaffold(
            backgroundColor: const Color(0xFF1C1C1E),
            appBar: AppBar(
              backgroundColor: const Color(0xFF2C2C2E),
              title: const Text('Terminal', style: TextStyle(color: Colors.white)),
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            body: const Center(
              child: Text(
                'Nenhuma sessao ativa',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        final activeSession = provider.activeSession;
        return Scaffold(
          backgroundColor: const Color(0xFF1C1C1E),
          appBar: AppBar(
            backgroundColor: const Color(0xFF2C2C2E),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    activeSession?.connection.host ?? 'Terminal',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (activeSession != null) ...[
                  Text(
                    activeSession.isConnected
                        ? 'Conectado'
                        : activeSession.isConnecting
                            ? 'Conectando...'
                            : 'Desconectado',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: activeSession.isConnected
                          ? Colors.green
                          : activeSession.isConnecting
                              ? Colors.orange
                              : Colors.red,
                    ),
                  ),
                ],
              ],
            ),
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: const Icon(Icons.text_fields, color: Colors.white),
                tooltip: 'Tamanho da fonte',
                onPressed: () => _showFontSizeDialog(context),
              ),
              IconButton(
                icon: const Icon(Icons.clear_all, color: Colors.white),
                tooltip: 'Fechar todas as sessoes',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Fechar todas as sessoes?'),
                      content: const Text(
                        'Todas as conexoes SSH serao encerradas.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () {
                            provider.closeAllSessions();
                            Navigator.of(ctx).pop();
                            Navigator.of(context).pop();
                          },
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Fechar todas'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
            bottom: provider.sessions.length > 1
                ? PreferredSize(
                    preferredSize: const Size.fromHeight(48),
                    child: _TabBar(provider: provider),
                  )
                : null,
          ),
          body: provider.activeSession != null
              ? _TerminalView(session: provider.activeSession!, fontSize: _fontSize)
              : const Center(
                  child: Text(
                    'Selecione uma sessao',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
        );
      },
    );
  }
}

class _TabBar extends StatelessWidget {
  final TerminalProvider provider;

  const _TabBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      color: const Color(0xFF252528),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: provider.sessionList.length,
        itemBuilder: (context, index) {
          final session = provider.sessionList[index];
          final isActive = session.id == provider.activeSessionId;

          return InkWell(
            onTap: () => provider.setActiveSession(session.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF1C1C1E) : Colors.transparent,
                border: Border(
                  bottom: BorderSide(
                    color: isActive
                        ? const Color(0xFF5B8DEF)
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    session.isConnected
                        ? Icons.terminal
                        : session.isConnecting
                            ? Icons.hourglass_empty
                            : Icons.error_outline,
                    color: isActive
                        ? const Color(0xFF5B8DEF)
                        : Colors.grey,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    session.connection.name,
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      provider.closeSession(session.id);
                      if (provider.sessions.isEmpty) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: Icon(
                      Icons.close,
                      color: Colors.grey.shade600,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TerminalView extends StatefulWidget {
  final TerminalSession session;
  final double fontSize;

  const _TerminalView({required this.session, required this.fontSize});

  @override
  State<_TerminalView> createState() => _TerminalViewState();
}

class _TerminalViewState extends State<_TerminalView> {
  final _terminalController = TerminalController();
  final _terminalFocusNode = FocusNode();

  @override
  void dispose() {
    _terminalController.dispose();
    _terminalFocusNode.dispose();
    super.dispose();
  }

  void _sendToTerminal(String data) {
    if (widget.session.shell != null && widget.session.isConnected) {
      widget.session.shell!.write(Uint8List.fromList(data.codeUnits));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.session.error != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.red.shade900,
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.session.error!,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        if (widget.session.isConnecting)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: const Color(0xFF5B8DEF).withOpacity(0.2),
            child: const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF5B8DEF),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Conectando...',
                  style: TextStyle(color: Color(0xFF5B8DEF), fontSize: 13),
                ),
              ],
            ),
          ),
        Expanded(
          child: TerminalView(
            widget.session.terminal,
            controller: _terminalController,
            focusNode: _terminalFocusNode,
            theme: _terminalTheme,
            padding: const EdgeInsets.all(8),
            autofocus: true,
            backgroundOpacity: 1.0,
            textStyle: TerminalStyle(
              fontSize: widget.fontSize,
              fontFamily: 'monospace',
            ),
          ),
        ),
        TerminalKeyboard(
          onKeyPressed: _sendToTerminal,
          terminalFocusNode: _terminalFocusNode,
        ),
      ],
    );
  }

  TerminalTheme get _terminalTheme => const TerminalTheme(
        cursor: Color(0xFFAEAFAD),
        selection: Color(0xFF264F78),
        foreground: Color(0xFFCCCCCC),
        background: Color(0xFF1C1C1E),
        black: Color(0xFF000000),
        red: Color(0xFFCD3131),
        green: Color(0xFF0DBC79),
        yellow: Color(0xFFE5E510),
        blue: Color(0xFF2472C8),
        magenta: Color(0xFFBC3FBC),
        cyan: Color(0xFF11A8CD),
        white: Color(0xFFE5E5E5),
        brightBlack: Color(0xFF666666),
        brightRed: Color(0xFFF14C4C),
        brightGreen: Color(0xFF23D18B),
        brightYellow: Color(0xFFF5F543),
        brightBlue: Color(0xFF3B8EEA),
        brightMagenta: Color(0xFFD670D6),
        brightCyan: Color(0xFF29B8DB),
        brightWhite: Color(0xFFFFFFFF),
        searchHitBackground: Color(0xFFFFDF5D),
        searchHitBackgroundCurrent: Color(0xFFFF9632),
        searchHitForeground: Color(0xFF000000),
      );
}
