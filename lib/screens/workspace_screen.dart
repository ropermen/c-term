import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ssh_connection.dart';
import '../providers/connections_provider.dart';
import '../providers/terminal_provider.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../services/update_service.dart';
import 'connection_form_screen.dart';
import 'terminal_screen.dart';
import '../widgets/rdp_view_panel.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  final TextEditingController _searchController = TextEditingController();
  final UpdateService _updateService = UpdateService();
  final StorageService _storageService = StorageService();
  String _searchQuery = '';
  double _fontSize = StorageService.defaultFontSize;

  @override
  void initState() {
    super.initState();
    _loadFontSize();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final connProvider = context.read<ConnectionsProvider>();
      await connProvider.loadConnections();
      if (mounted) {
        await context.read<TerminalProvider>().restoreSessions(connProvider.connections);
      }
      _checkForUpdates();
    });
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

  Future<void> _checkForUpdates() async {
    final updateInfo = await _updateService.checkForUpdate();
    if (updateInfo != null && mounted) {
      _showUpdateDialog(updateInfo);
    }
  }

  void _showUpdateDialog(UpdateInfo updateInfo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        title: const Row(
          children: [
            Icon(Icons.system_update, color: Color(0xFF5B8DEF)),
            SizedBox(width: 8),
            Text('Atualizacao disponivel', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Versao ${updateInfo.version}',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text('Novidades:', style: TextStyle(color: Colors.grey.shade400, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(updateInfo.changelog, style: TextStyle(color: Colors.grey.shade300, fontSize: 14)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Depois', style: TextStyle(color: Colors.grey.shade400)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _updateService.openDownloadUrl(updateInfo.downloadUrl);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B8DEF)),
            child: const Text('Atualizar', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Connection> _filterConnections(List<Connection> connections) {
    if (_searchQuery.isEmpty) return connections;
    final query = _searchQuery.toLowerCase();
    return connections.where((c) {
      return c.name.toLowerCase().contains(query) ||
          c.host.toLowerCase().contains(query) ||
          c.username.toLowerCase().contains(query);
    }).toList();
  }

  void _openConnectionForm(ConnectionType type) {
    showDialog(
      context: context,
      builder: (_) => ConnectionFormScreen(connectionType: type, asDialog: true),
    );
  }

  void _editConnection(Connection connection) {
    showDialog(
      context: context,
      builder: (_) => ConnectionFormScreen(connection: connection, asDialog: true),
    );
  }

  Future<void> _deleteConnection(Connection connection) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusao'),
        content: Text('Deseja excluir a conexao "${connection.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final terminalProvider = context.read<TerminalProvider>();
      if (terminalProvider.hasSession(connection.id)) {
        terminalProvider.closeSession(connection.id);
      }
      await context.read<ConnectionsProvider>().deleteConnection(connection.id);
    }
  }

  Future<void> _connectToServer(Connection connection) async {
    final terminalProvider = context.read<TerminalProvider>();

    if (terminalProvider.hasSession(connection.id)) {
      terminalProvider.setActiveSession(connection.id);
      return;
    }

    await terminalProvider.createSession(connection);
  }

  Future<void> _showSettingsDialog() async {
    final storageService = StorageService();
    final authService = AuthService();
    bool biometricEnabled = await storageService.isBiometricEnabled();
    bool biometricAvailable = await authService.isBiometricAvailable();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Configuracoes'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Autenticacao biometrica'),
                subtitle: Text(
                  biometricAvailable
                      ? 'Exigir biometria ao abrir o app'
                      : 'Nao disponivel neste dispositivo',
                ),
                value: biometricEnabled,
                onChanged: biometricAvailable
                    ? (value) async {
                        await storageService.setBiometricEnabled(value);
                        setDialogState(() => biometricEnabled = value);
                      }
                    : null,
              ),
              const Divider(),
              ListTile(
                title: const Text('Tamanho da fonte'),
                subtitle: Text('${_fontSize.toInt()} pt'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: _fontSize > 8
                          ? () {
                              final newSize = _fontSize - 1;
                              setDialogState(() {});
                              _setFontSize(newSize);
                            }
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: _fontSize < 32
                          ? () {
                              final newSize = _fontSize + 1;
                              setDialogState(() {});
                              _setFontSize(newSize);
                            }
                          : null,
                    ),
                  ],
                ),
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
      builder: (context, terminalProvider, _) {
        final activeSession = terminalProvider.activeSession;
        final isMaximized = activeSession?.windowState == TabWindowState.maximized;

        return Scaffold(
          backgroundColor: const Color(0xFF1C1C1E),
          body: Row(
            children: [
              if (!isMaximized) _buildSidebar(),
              if (!isMaximized)
                const VerticalDivider(width: 1, thickness: 1, color: Color(0xFF3A3A3C)),
              Expanded(child: _buildContentPanel(terminalProvider)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebar() {
    return SizedBox(
      width: 260,
      child: Column(
        children: [
          // Header
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            color: const Color(0xFF2C2C2E),
            child: Row(
              children: [
                Image.asset('assets/app_icon.png', width: 20, height: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'koder',
                    style: TextStyle(
                      fontFamily: 'Expansiva',
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.settings, size: 18, color: Colors.white),
                  tooltip: 'Configuracoes',
                  onPressed: _showSettingsDialog,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),

          // New connection buttons
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                _NewConnectionButton(
                  label: '+ SSH',
                  color: const Color(0xFF5B8DEF),
                  onTap: () => _openConnectionForm(ConnectionType.ssh),
                ),
                const SizedBox(width: 4),
                _NewConnectionButton(
                  label: '+ RDP',
                  color: const Color(0xFFE5A00D),
                  onTap: () => _openConnectionForm(ConnectionType.rdp),
                ),
                const SizedBox(width: 4),
                _NewConnectionButton(
                  label: '+ VNC',
                  color: const Color(0xFF0DBC79),
                  onTap: () => _openConnectionForm(ConnectionType.vnc),
                ),
              ],
            ),
          ),

          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Filtrar...',
                  hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade500, size: 18),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey.shade500, size: 16),
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF2C2C2E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Connection list
          Expanded(
            child: Consumer<ConnectionsProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF5B8DEF)),
                  );
                }

                if (provider.connections.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Nenhuma conexao.\nUse os botoes acima\npara adicionar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                      ),
                    ),
                  );
                }

                final filtered = _filterConnections(provider.connections);
                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      'Nenhuma conexao encontrada',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final conn = filtered[index];
                    return _SidebarConnectionItem(
                      connection: conn,
                      onTap: () => _connectToServer(conn),
                      onEdit: () => _editConnection(conn),
                      onDelete: () => _deleteConnection(conn),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentPanel(TerminalProvider terminalProvider) {
    final sessions = terminalProvider.sessionList;
    final activeSession = terminalProvider.activeSession;

    return Column(
      children: [
        // Tab bar
        if (sessions.isNotEmpty)
          Container(
            height: 36,
            color: const Color(0xFF2C2C2E),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                final isActive = session.id == terminalProvider.activeSessionId;

                return InkWell(
                  onTap: () => terminalProvider.setActiveSession(session.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFF1C1C1E) : Colors.transparent,
                      border: Border(
                        bottom: BorderSide(
                          color: isActive ? const Color(0xFF5B8DEF) : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _sessionIcon(session),
                          color: isActive ? const Color(0xFF5B8DEF) : Colors.grey,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          session.connection.name,
                          style: TextStyle(
                            color: isActive ? Colors.white : Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Window control buttons
                        _TabControlButton(
                          icon: Icons.minimize,
                          tooltip: 'Minimizar',
                          onTap: () => terminalProvider.toggleMinimize(session.id),
                          size: 14,
                        ),
                        _TabControlButton(
                          icon: session.windowState == TabWindowState.maximized
                              ? Icons.filter_none
                              : Icons.crop_square,
                          tooltip: session.windowState == TabWindowState.maximized
                              ? 'Restaurar'
                              : 'Maximizar',
                          onTap: () => terminalProvider.toggleMaximize(session.id),
                          size: 14,
                        ),
                        _TabControlButton(
                          icon: Icons.close,
                          tooltip: 'Fechar',
                          onTap: () => terminalProvider.closeSession(session.id),
                          size: 14,
                          hoverColor: Colors.red,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

        // Content area
        Expanded(
          child: _buildSessionContent(activeSession),
        ),
      ],
    );
  }

  Widget _buildSessionContent(TerminalSession? session) {
    if (session == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.terminal, size: 48, color: Colors.grey.shade700),
            const SizedBox(height: 16),
            Text(
              'Clique em uma conexao para iniciar',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
            ),
          ],
        ),
      );
    }

    if (session.windowState == TabWindowState.minimized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.minimize, size: 48, color: Colors.grey.shade700),
            const SizedBox(height: 16),
            Text(
              'Sessao minimizada: ${session.connection.name}',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => context.read<TerminalProvider>().toggleMinimize(session.id),
              icon: const Icon(Icons.open_in_full),
              label: const Text('Restaurar'),
            ),
          ],
        ),
      );
    }

    if (session.connection.type == ConnectionType.rdp) {
      return RdpViewPanel(session: session);
    }

    if (session.connection.type == ConnectionType.vnc) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.connected_tv, size: 48, color: Colors.grey.shade700),
            const SizedBox(height: 16),
            Text(
              'VNC — em breve',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Suporte a VNC sera adicionado em uma atualizacao futura.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return TerminalViewPanel(session: session, fontSize: _fontSize);
  }

  IconData _sessionIcon(TerminalSession session) {
    if (session.isConnecting) return Icons.hourglass_empty;
    if (session.error != null && !session.isConnected) return Icons.error_outline;
    switch (session.connection.type) {
      case ConnectionType.ssh:
        return Icons.terminal;
      case ConnectionType.rdp:
        return Icons.desktop_windows;
      case ConnectionType.vnc:
        return Icons.connected_tv;
    }
  }
}

class _NewConnectionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _NewConnectionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 30,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarConnectionItem extends StatelessWidget {
  final Connection connection;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SidebarConnectionItem({
    required this.connection,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  IconData _iconForType(ConnectionType type) {
    switch (type) {
      case ConnectionType.ssh:
        return Icons.terminal;
      case ConnectionType.rdp:
        return Icons.desktop_windows;
      case ConnectionType.vnc:
        return Icons.connected_tv;
    }
  }

  Color _colorForType(ConnectionType type) {
    switch (type) {
      case ConnectionType.ssh:
        return const Color(0xFF5B8DEF);
      case ConnectionType.rdp:
        return const Color(0xFFE5A00D);
      case ConnectionType.vnc:
        return const Color(0xFF0DBC79);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TerminalProvider>(
      builder: (context, terminalProvider, _) {
        final isConnected = terminalProvider.hasSession(connection.id);
        final typeColor = _colorForType(connection.type);

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isConnected ? typeColor.withOpacity(0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  _iconForType(connection.type),
                  size: 16,
                  color: isConnected ? typeColor : Colors.grey.shade500,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        connection.name,
                        style: TextStyle(
                          color: isConnected ? Colors.white : Colors.grey.shade300,
                          fontSize: 13,
                          fontWeight: isConnected ? FontWeight.w500 : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${connection.host}:${connection.port}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isConnected)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: typeColor,
                    ),
                  ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: Colors.grey.shade600, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  color: const Color(0xFF3D3D3D),
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      height: 36,
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: Colors.white, size: 16),
                          SizedBox(width: 8),
                          Text('Editar', style: TextStyle(color: Colors.white, fontSize: 13)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      height: 36,
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 16),
                          SizedBox(width: 8),
                          Text('Excluir', style: TextStyle(color: Colors.red, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TabControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final double size;
  final Color? hoverColor;

  const _TabControlButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 14,
    this.hoverColor,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        hoverColor: hoverColor?.withOpacity(0.2),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(
            icon,
            size: size,
            color: Colors.grey.shade500,
          ),
        ),
      ),
    );
  }
}
