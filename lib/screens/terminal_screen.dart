import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';
import '../providers/terminal_provider.dart';
import '../widgets/terminal_keyboard.dart';
import 'keyboard_settings_screen.dart';

class TerminalScreen extends StatelessWidget {
  const TerminalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TerminalProvider>(
      builder: (context, provider, _) {
        if (provider.sessions.isEmpty) {
          return Scaffold(
            backgroundColor: const Color(0xFF1E1E1E),
            appBar: AppBar(
              backgroundColor: const Color(0xFF2D2D2D),
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
          backgroundColor: const Color(0xFF1E1E1E),
          appBar: AppBar(
            backgroundColor: const Color(0xFF2D2D2D),
            title: Row(
              children: [
                const Text('Terminal', style: TextStyle(color: Colors.white)),
                const Spacer(),
                if (activeSession != null) ...[
                  Text(
                    activeSession.isConnected
                        ? 'Conectado'
                        : activeSession.isConnecting
                            ? 'Conectando...'
                            : 'Desconectado',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 10,
                    height: 10,
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
              IconButton(
                icon: const Icon(Icons.keyboard, color: Colors.white),
                tooltip: 'Configurar teclado',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const KeyboardSettingsScreen()),
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
              ? _TerminalView(session: provider.activeSession!)
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
      color: const Color(0xFF252526),
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
                color: isActive ? const Color(0xFF1E1E1E) : Colors.transparent,
                border: Border(
                  bottom: BorderSide(
                    color: isActive
                        ? const Color(0xFF4EC9B0)
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
                        ? const Color(0xFF4EC9B0)
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

  const _TerminalView({required this.session});

  @override
  State<_TerminalView> createState() => _TerminalViewState();
}

class _TerminalViewState extends State<_TerminalView> {
  final _terminalController = TerminalController();

  @override
  void dispose() {
    _terminalController.dispose();
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
            color: const Color(0xFF4EC9B0).withOpacity(0.2),
            child: const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF4EC9B0),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Conectando...',
                  style: TextStyle(color: Color(0xFF4EC9B0), fontSize: 13),
                ),
              ],
            ),
          ),
        Expanded(
          child: TerminalView(
            widget.session.terminal,
            controller: _terminalController,
            theme: _terminalTheme,
            padding: const EdgeInsets.all(8),
            autofocus: true,
            backgroundOpacity: 1.0,
            textStyle: const TerminalStyle(
              fontSize: 14,
              fontFamily: 'monospace',
            ),
          ),
        ),
        TerminalKeyboard(
          onKeyPressed: _sendToTerminal,
        ),
      ],
    );
  }

  TerminalTheme get _terminalTheme => const TerminalTheme(
        cursor: Color(0xFFAEAFAD),
        selection: Color(0xFF264F78),
        foreground: Color(0xFFCCCCCC),
        background: Color(0xFF1E1E1E),
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
