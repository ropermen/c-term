import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connections_provider.dart';
import '../providers/terminal_provider.dart';
import '../models/ssh_connection.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../services/update_service.dart';
import 'connection_form_screen.dart';
import 'terminal_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final UpdateService _updateService = UpdateService();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConnectionsProvider>().loadConnections();
      _checkForUpdates();
    });
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
            Text(
              'Atualizacao disponivel',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Versao ${updateInfo.version}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Novidades:',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              updateInfo.changelog,
              style: TextStyle(
                color: Colors.grey.shade300,
                fontSize: 14,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Depois',
              style: TextStyle(color: Colors.grey.shade400),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _updateService.openDownloadUrl(updateInfo.downloadUrl);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B8DEF),
            ),
            child: const Text(
              'Atualizar',
              style: TextStyle(color: Colors.black),
            ),
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

  List<SSHConnection> _filterConnections(List<SSHConnection> connections) {
    if (_searchQuery.isEmpty) return connections;
    final query = _searchQuery.toLowerCase();
    return connections.where((c) {
      return c.name.toLowerCase().contains(query) ||
          c.host.toLowerCase().contains(query) ||
          c.username.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _connectToServer(SSHConnection connection) async {
    final terminalProvider = context.read<TerminalProvider>();

    if (terminalProvider.hasSession(connection.id)) {
      terminalProvider.setActiveSession(connection.id);
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TerminalScreen()),
        );
      }
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Conectando...'),
              ],
            ),
          ),
        ),
      ),
    );

    await terminalProvider.createSession(connection);

    if (mounted) {
      Navigator.of(context).pop();
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const TerminalScreen()),
      );
    }
  }

  void _editConnection(SSHConnection connection) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConnectionFormScreen(connection: connection),
      ),
    );
  }

  Future<void> _deleteConnection(SSHConnection connection) async {
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
      await context.read<ConnectionsProvider>().deleteConnection(connection.id);
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    final provider = context.read<ConnectionsProvider>();
    provider.reorderConnections(oldIndex, newIndex);
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
          content: SwitchListTile(
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
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        toolbarHeight: 36,
        backgroundColor: const Color(0xFF2C2C2E),
        title: Row(
          children: [
            Image.asset('assets/app_icon.png', width: 16, height: 16),
            const SizedBox(width: 6),
            const Text('koder', style: TextStyle(fontFamily: 'Expansiva', fontSize: 14, color: Colors.white)),
          ],
        ),
        actions: [
          Consumer<TerminalProvider>(
            builder: (context, provider, _) {
              final sessionCount = provider.sessions.length;
              if (sessionCount == 0) return const SizedBox.shrink();
              return TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TerminalScreen()),
                  );
                },
                icon: Image.asset('assets/app_icon.png', width: 16, height: 16),
                label: Text(
                  '$sessionCount ativa${sessionCount > 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF5B8DEF)),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, size: 20, color: Colors.white),
            tooltip: 'Configuracoes',
            onPressed: () => _showSettingsDialog(),
          ),
        ],
      ),
      body: Consumer<ConnectionsProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF5B8DEF)),
            );
          }

          if (provider.connections.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.dns_outlined,
                    size: 64,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhuma conexao cadastrada',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Toque no + para adicionar uma conexao SSH',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          final filteredConnections = _filterConnections(provider.connections);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Filtrar conexoes...',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey.shade400),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFF2C2C2E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
              ),
              if (_searchQuery.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.drag_handle, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        'Arraste para reordenar',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: filteredConnections.isEmpty
                    ? Center(
                        child: Text(
                          'Nenhuma conexao encontrada',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      )
                    : _searchQuery.isNotEmpty
                        ? ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: filteredConnections.length,
                            itemBuilder: (context, index) {
                              final connection = filteredConnections[index];
                              return _ConnectionCard(
                                key: ValueKey(connection.id),
                                connection: connection,
                                onTap: () => _connectToServer(connection),
                                onEdit: () => _editConnection(connection),
                                onDelete: () => _deleteConnection(connection),
                                showDragHandle: false,
                              );
                            },
                          )
                        : ReorderableListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: provider.connections.length,
                            onReorder: _onReorder,
                            proxyDecorator: (child, index, animation) {
                              return AnimatedBuilder(
                                animation: animation,
                                builder: (context, child) {
                                  return Material(
                                    elevation: 4,
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    child: child,
                                  );
                                },
                                child: child,
                              );
                            },
                            itemBuilder: (context, index) {
                              final connection = provider.connections[index];
                              return _ConnectionCard(
                                key: ValueKey(connection.id),
                                connection: connection,
                                onTap: () => _connectToServer(connection),
                                onEdit: () => _editConnection(connection),
                                onDelete: () => _deleteConnection(connection),
                                showDragHandle: true,
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ConnectionFormScreen()),
          );
        },
        backgroundColor: const Color(0xFF5B8DEF),
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  final SSHConnection connection;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool showDragHandle;

  const _ConnectionCard({
    super.key,
    required this.connection,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.showDragHandle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<TerminalProvider>(
      builder: (context, terminalProvider, _) {
        final isConnected = terminalProvider.hasSession(connection.id);

        return Card(
          color: const Color(0xFF2C2C2E),
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (showDragHandle)
                    ReorderableDragStartListener(
                      index: 0,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Icon(
                          Icons.drag_handle,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isConnected
                          ? const Color(0xFF5B8DEF).withOpacity(0.2)
                          : Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.dns,
                      color: isConnected
                          ? const Color(0xFF5B8DEF)
                          : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                connection.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (isConnected)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF5B8DEF).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Conectado',
                                  style: TextStyle(
                                    color: Color(0xFF5B8DEF),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${connection.username}@${connection.host}:${connection.port}',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Colors.grey.shade400),
                    color: const Color(0xFF3D3D3D),
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEdit();
                      } else if (value == 'delete') {
                        onDelete();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text('Editar', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red, size: 20),
                            SizedBox(width: 8),
                            Text('Excluir', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
