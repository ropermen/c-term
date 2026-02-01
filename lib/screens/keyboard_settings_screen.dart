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

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Toque para ativar/desativar. Use setas para reordenar. Use 1/2 para mudar de linha.',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              ),
              const SizedBox(height: 16),
              _buildSectionHeader('Linha 1 (Superior)'),
              const SizedBox(height: 8),
              _KeysRow(
                keys: provider.enabledKeysRow1,
                provider: provider,
                currentRow: 1,
              ),
              const SizedBox(height: 16),
              _buildSectionHeader('Linha 2 (Inferior)'),
              const SizedBox(height: 8),
              _KeysRow(
                keys: provider.enabledKeysRow2,
                provider: provider,
                currentRow: 2,
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFF3D3D3D)),
              const SizedBox(height: 8),
              _buildSectionHeader('Teclas Disponiveis'),
              const SizedBox(height: 8),
              _DisabledKeysList(provider: provider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.grey.shade300,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _KeysRow extends StatelessWidget {
  final List<KeyboardKey> keys;
  final KeyboardProvider provider;
  final int currentRow;

  const _KeysRow({
    required this.keys,
    required this.provider,
    required this.currentRow,
  });

  @override
  Widget build(BuildContext context) {
    if (keys.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D2D),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Nenhuma tecla nesta linha',
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(keys.length, (index) => _KeyChip(
        keyData: keys[index],
        provider: provider,
        currentRow: currentRow,
        isFirst: index == 0,
        isLast: index == keys.length - 1,
      )),
    );
  }
}

class _KeyChip extends StatelessWidget {
  final KeyboardKey keyData;
  final KeyboardProvider provider;
  final int currentRow;
  final bool isFirst;
  final bool isLast;

  const _KeyChip({
    required this.keyData,
    required this.provider,
    required this.currentRow,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final targetRow = currentRow == 1 ? 2 : 1;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Left arrow
          InkWell(
            onTap: isFirst ? null : () => provider.moveKeyLeft(keyData.id),
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Icon(
                Icons.chevron_left,
                size: 16,
                color: isFirst ? Colors.grey.shade700 : Colors.grey.shade400,
              ),
            ),
          ),
          // Key label
          InkWell(
            onTap: () => provider.toggleKey(keyData.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: keyData.isModifier
                    ? const Color(0xFF4EC9B0).withOpacity(0.2)
                    : const Color(0xFF3D3D3D),
              ),
              child: Text(
                keyData.label,
                style: TextStyle(
                  color: keyData.isModifier ? const Color(0xFF4EC9B0) : Colors.white,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          // Right arrow
          InkWell(
            onTap: isLast ? null : () => provider.moveKeyRight(keyData.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Icon(
                Icons.chevron_right,
                size: 16,
                color: isLast ? Colors.grey.shade700 : Colors.grey.shade400,
              ),
            ),
          ),
          // Row toggle
          InkWell(
            onTap: () => provider.setKeyRow(keyData.id, targetRow),
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Text(
                '$targetRow',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
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
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D2D),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Todas as teclas estao ativas',
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: disabledKeys.map((key) => InkWell(
        onTap: () => provider.toggleKey(key.id),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF3D3D3D),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF4D4D4D)),
          ),
          child: Text(
            key.label,
            style: const TextStyle(
              color: Colors.grey,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      )).toList(),
    );
  }
}
