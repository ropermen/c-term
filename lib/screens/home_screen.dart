import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connections_provider.dart';
import '../providers/terminal_provider.dart';
import '../models/ssh_connection.dart';
import 'connection_form_screen.dart';
import 'terminal_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConnectionsProvider>().loadConnections();
    });
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
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja excluir a conexão "${connection.name}"?'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D2D2D),
        title: const Row(
          children: [
            Icon(Icons.terminal, color: Color(0xFF4EC9B0)),
            SizedBox(width: 8),
            Text('c-term', style: TextStyle(color: Colors.white)),
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
                icon: const Icon(Icons.terminal, color: Color(0xFF4EC9B0)),
                label: Text(
                  '$sessionCount ativa${sessionCount > 1 ? 's' : ''}',
                  style: const TextStyle(color: Color(0xFF4EC9B0)),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<ConnectionsProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF4EC9B0)),
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
                    'Nenhuma conexão cadastrada',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Toque no + para adicionar uma conexão SSH',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.connections.length,
            itemBuilder: (context, index) {
              final connection = provider.connections[index];
              return _ConnectionCard(
                connection: connection,
                onTap: () => _connectToServer(connection),
                onEdit: () => _editConnection(connection),
                onDelete: () => _deleteConnection(connection),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ConnectionFormScreen()),
          );
        },
        backgroundColor: const Color(0xFF4EC9B0),
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

  const _ConnectionCard({
    required this.connection,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<TerminalProvider>(
      builder: (context, terminalProvider, _) {
        final isConnected = terminalProvider.hasSession(connection.id);

        return Card(
          color: const Color(0xFF2D2D2D),
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isConnected
                          ? const Color(0xFF4EC9B0).withOpacity(0.2)
                          : Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.dns,
                      color: isConnected
                          ? const Color(0xFF4EC9B0)
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
                                  color: const Color(0xFF4EC9B0).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Conectado',
                                  style: TextStyle(
                                    color: Color(0xFF4EC9B0),
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
