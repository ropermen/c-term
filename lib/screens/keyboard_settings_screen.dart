import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/keyboard_provider.dart';
import '../models/keyboard_key.dart';

class KeyboardSettingsScreen extends StatefulWidget {
  const KeyboardSettingsScreen({super.key});

  @override
  State<KeyboardSettingsScreen> createState() => _KeyboardSettingsScreenState();
}

class _KeyboardSettingsScreenState extends State<KeyboardSettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KeyboardProvider>().loadKeys();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D2D2D),
        title: const Text('Configurar Teclado', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Restaurar padrao',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Restaurar padrao?'),
                  content: const Text('Todas as configuracoes de teclas serao restauradas.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Restaurar'),
                    ),
                  ],
                ),
              );
              if (confirmed == true && mounted) {
                await context.read<KeyboardProvider>().resetToDefaults();
              }
            },
          ),
        ],
      ),
      body: Consumer<KeyboardProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF4EC9B0)),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Arraste para reordenar. Toque para ativar/desativar.',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                ),
              ),
              const Divider(color: Color(0xFF3D3D3D), height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Teclas Ativas',
                  style: TextStyle(
                    color: Colors.grey.shade300,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: _EnabledKeysList(provider: provider),
              ),
              const Divider(color: Color(0xFF3D3D3D), height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Teclas Disponiveis',
                  style: TextStyle(
                    color: Colors.grey.shade300,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: _DisabledKeysList(provider: provider),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EnabledKeysList extends StatelessWidget {
  final KeyboardProvider provider;

  const _EnabledKeysList({required this.provider});

  @override
  Widget build(BuildContext context) {
    final enabledKeys = provider.enabledKeys;

    if (enabledKeys.isEmpty) {
      return Center(
        child: Text(
          'Nenhuma tecla ativa',
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: enabledKeys.length,
      onReorder: provider.reorderKeys,
      itemBuilder: (context, index) {
        final key = enabledKeys[index];
        return _KeyTile(
          key: ValueKey(key.id),
          keyData: key,
          onToggle: () => provider.toggleKey(key.id),
          showDragHandle: true,
        );
      },
    );
  }
}

class _DisabledKeysList extends StatelessWidget {
  final KeyboardProvider provider;

  const _DisabledKeysList({required this.provider});

  @override
  Widget build(BuildContext context) {
    final disabledKeys = provider.keys.where((k) => !k.enabled).toList();

    if (disabledKeys.isEmpty) {
      return Center(
        child: Text(
          'Todas as teclas estao ativas',
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: disabledKeys.length,
      itemBuilder: (context, index) {
        final key = disabledKeys[index];
        return _KeyTile(
          key: ValueKey(key.id),
          keyData: key,
          onToggle: () => provider.toggleKey(key.id),
          showDragHandle: false,
        );
      },
    );
  }
}

class _KeyTile extends StatelessWidget {
  final KeyboardKey keyData;
  final VoidCallback onToggle;
  final bool showDragHandle;

  const _KeyTile({
    super.key,
    required this.keyData,
    required this.onToggle,
    this.showDragHandle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF2D2D2D),
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: keyData.isModifier
                      ? const Color(0xFF4EC9B0).withOpacity(0.2)
                      : const Color(0xFF3D3D3D),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: keyData.isModifier
                        ? const Color(0xFF4EC9B0)
                        : const Color(0xFF4D4D4D),
                  ),
                ),
                child: Text(
                  keyData.label,
                  style: TextStyle(
                    color: keyData.isModifier
                        ? const Color(0xFF4EC9B0)
                        : Colors.white,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  keyData.isModifier ? 'Modificador' : _getKeyDescription(keyData.id),
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 13,
                  ),
                ),
              ),
              Icon(
                keyData.enabled ? Icons.check_circle : Icons.radio_button_unchecked,
                color: keyData.enabled ? const Color(0xFF4EC9B0) : Colors.grey.shade600,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getKeyDescription(String id) {
    switch (id) {
      case 'tab':
        return 'Tabulacao';
      case 'esc':
        return 'Escape';
      case 'up':
        return 'Seta para cima';
      case 'down':
        return 'Seta para baixo';
      case 'left':
        return 'Seta para esquerda';
      case 'right':
        return 'Seta para direita';
      case 'del':
        return 'Delete';
      case 'pipe':
        return 'Pipe (redirecionamento)';
      case 'amp':
        return 'E comercial';
      case 'semicolon':
        return 'Ponto e virgula';
      case 'gt':
        return 'Maior que';
      case 'lt':
        return 'Menor que';
      case 'tilde':
        return 'Til (home)';
      case 'slash':
        return 'Barra';
      case 'backslash':
        return 'Barra invertida';
      default:
        return 'Caractere especial';
    }
  }
}
