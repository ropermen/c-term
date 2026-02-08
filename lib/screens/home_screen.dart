import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connections_provider.dart';
import '../providers/terminal_provider.dart';
import '../models/ssh_connection.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../services/update_service.dart';
import '../services/api_service.dart';
import 'connection_form_screen.dart';
import 'terminal_screen.dart';
import 'login_screen.dart';
import 'user_management_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

  List<Connection> _filterConnections(List<Connection> connections) {
    if (_searchQuery.isEmpty) return connections;
    final query = _searchQuery.toLowerCase();
    return connections.where((c) {
      return c.name.toLowerCase().contains(query) ||
          c.host.toLowerCase().contains(query) ||
          c.username.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _connectToServer(Connection connection) async {
    final terminalProvider = context.read<TerminalProvider>();

    if (connection.type == ConnectionType.rdp && !kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conexoes RDP so estao disponiveis na versao web do koder.'),
          backgroundColor: Color(0xFFE5A00D),
        ),
      );
      return;
    }

    if (connection.type == ConnectionType.vnc) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Suporte a VNC sera adicionado em breve.'),
          backgroundColor: Color(0xFF0DBC79),
        ),
      );
      return;
    }

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

  void _onReorder(int oldIndex, int newIndex) {
    final provider = context.read<ConnectionsProvider>();
    provider.reorderConnections(oldIndex, newIndex);
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        title: const Text('Sair', style: TextStyle(color: Colors.white)),
        content: const Text('Deseja sair do koder?', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ApiService().logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    }
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF2C2C2E),
          title: const Text('Alterar senha', style: TextStyle(color: Colors.white)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: currentPasswordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Senha atual',
                    labelStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    prefixIcon: Icon(Icons.lock_outline, color: Colors.grey.shade400, size: 20),
                    filled: true,
                    fillColor: const Color(0xFF3A3A3C),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Informe a senha atual' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: newPasswordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Nova senha',
                    labelStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    prefixIcon: Icon(Icons.lock_reset, color: Colors.grey.shade400, size: 20),
                    filled: true,
                    fillColor: const Color(0xFF3A3A3C),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Informe a nova senha' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Confirmar nova senha',
                    labelStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    prefixIcon: Icon(Icons.lock_reset, color: Colors.grey.shade400, size: 20),
                    filled: true,
                    fillColor: const Color(0xFF3A3A3C),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Confirme a nova senha';
                    if (v != newPasswordController.text) return 'As senhas nao coincidem';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancelar', style: TextStyle(color: Colors.grey.shade400)),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => saving = true);
                      try {
                        await ApiService().changePassword(
                          currentPasswordController.text,
                          newPasswordController.text,
                        );
                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text('Senha alterada com sucesso'),
                              backgroundColor: Color(0xFF0DBC79),
                            ),
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(e.toString().replaceFirst('Exception: ', '')),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        if (ctx.mounted) setDialogState(() => saving = false);
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B8DEF)),
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Text('Alterar', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSettingsDialog() async {
    final storageService = StorageService();
    final authService = AuthService();
    final apiService = ApiService();
    bool biometricEnabled = await storageService.isBiometricEnabled();
    bool biometricAvailable = await authService.isBiometricAvailable();
    final isAdmin = apiService.currentUser?.isAdmin ?? false;

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
              if (isAdmin) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.people, color: Color(0xFF5B8DEF)),
                  title: const Text('Gerenciar Usuarios'),
                  subtitle: const Text('Criar, editar e excluir usuarios'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(this.context).push(
                      MaterialPageRoute(builder: (_) => const UserManagementScreen()),
                    );
                  },
                ),
              ],
              const Divider(),
              ListTile(
                leading: const Icon(Icons.lock_reset, color: Color(0xFF5B8DEF)),
                title: const Text('Alterar senha'),
                subtitle: const Text('Trocar a senha da sua conta'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showChangePasswordDialog();
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Sair', style: TextStyle(color: Colors.red)),
                subtitle: Text(
                  'Logado como ${apiService.currentUser?.username ?? ""}',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _logout();
                },
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

  void _showNewConnectionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2C2C2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nova conexao',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _ConnectionTypeOption(
                icon: Icons.terminal,
                label: 'SSH',
                subtitle: 'Terminal remoto seguro',
                color: const Color(0xFF5B8DEF),
                onTap: () {
                  Navigator.of(ctx).pop();
                  showDialog(
                    context: context,
                    builder: (_) => const ConnectionFormScreen(
                      connectionType: ConnectionType.ssh,
                      asDialog: true,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              _ConnectionTypeOption(
                icon: Icons.desktop_windows,
                label: 'RDP',
                subtitle: 'Area de trabalho remota',
                color: const Color(0xFFE5A00D),
                onTap: () {
                  Navigator.of(ctx).pop();
                  showDialog(
                    context: context,
                    builder: (_) => const ConnectionFormScreen(
                      connectionType: ConnectionType.rdp,
                      asDialog: true,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              _ConnectionTypeOption(
                icon: Icons.connected_tv,
                label: 'VNC',
                subtitle: 'Em breve',
                color: const Color(0xFF0DBC79),
                enabled: false,
                onTap: () {},
              ),
            ],
          ),
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
                    'Toque no + para adicionar uma conexao',
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
        onPressed: _showNewConnectionSheet,
        backgroundColor: const Color(0xFF5B8DEF),
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}

class _ConnectionTypeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;

  const _ConnectionTypeOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  final Connection connection;
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
                          ? typeColor.withOpacity(0.2)
                          : Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _iconForType(connection.type),
                      color: isConnected ? typeColor : Colors.grey,
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
                                  color: typeColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Conectado',
                                  style: TextStyle(
                                    color: typeColor,
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
