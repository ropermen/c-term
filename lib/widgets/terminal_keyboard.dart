import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/keyboard_provider.dart';
import '../models/keyboard_key.dart';
import '../screens/keyboard_settings_screen.dart';

class TerminalKeyboard extends StatefulWidget {
  final void Function(String) onKeyPressed;

  const TerminalKeyboard({
    super.key,
    required this.onKeyPressed,
  });

  @override
  State<TerminalKeyboard> createState() => _TerminalKeyboardState();
}

class _TerminalKeyboardState extends State<TerminalKeyboard> {
  bool _ctrlPressed = false;
  bool _altPressed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KeyboardProvider>().loadKeys();
    });
  }

  void _handleKeyPress(KeyboardKey key) {
    if (key.isModifier) {
      if (key.id == 'ctrl') {
        setState(() {
          _ctrlPressed = !_ctrlPressed;
          if (_ctrlPressed) _altPressed = false;
        });
      } else if (key.id == 'alt') {
        setState(() {
          _altPressed = !_altPressed;
          if (_altPressed) _ctrlPressed = false;
        });
      }
      return;
    }

    String output = key.value;

    if (_ctrlPressed) {
      // Convert to Ctrl sequence
      if (key.value.length == 1) {
        final char = key.value.toLowerCase();
        final ctrlMap = {
          'a': '\x01',
          'b': '\x02',
          'c': '\x03',
          'd': '\x04',
          'e': '\x05',
          'f': '\x06',
          'g': '\x07',
          'h': '\x08',
          'i': '\x09',
          'j': '\x0A',
          'k': '\x0B',
          'l': '\x0C',
          'm': '\x0D',
          'n': '\x0E',
          'o': '\x0F',
          'p': '\x10',
          'q': '\x11',
          'r': '\x12',
          's': '\x13',
          't': '\x14',
          'u': '\x15',
          'v': '\x16',
          'w': '\x17',
          'x': '\x18',
          'y': '\x19',
          'z': '\x1A',
          '[': '\x1B',
          '\\': '\x1C',
          ']': '\x1D',
          '^': '\x1E',
          '_': '\x1F',
        };
        output = ctrlMap[char] ?? key.value;
      }
      setState(() => _ctrlPressed = false);
    } else if (_altPressed) {
      // Alt sends ESC before the character
      output = '\x1B${key.value}';
      setState(() => _altPressed = false);
    }

    widget.onKeyPressed(output);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF252526),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const Divider(height: 1, color: Color(0xFF3D3D3D)),
            _buildKeyboard(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          if (_ctrlPressed || _altPressed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF4EC9B0),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _ctrlPressed ? 'Ctrl' : 'Alt',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.settings, size: 20, color: Colors.grey.shade400),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const KeyboardSettingsScreen()),
              );
            },
            tooltip: 'Configurar teclas',
          ),
        ],
      ),
    );
  }

  Widget _buildKeyboard() {
    return Consumer<KeyboardProvider>(
      builder: (context, provider, _) {
        final enabledKeys = provider.enabledKeys;

        if (enabledKeys.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Nenhuma tecla configurada. Toque em configuracoes.',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          );
        }

        // Split keys into two rows
        final midpoint = (enabledKeys.length / 2).ceil();
        final firstRowKeys = enabledKeys.take(midpoint).toList();
        final secondRowKeys = enabledKeys.skip(midpoint).toList();

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildKeyRow(firstRowKeys),
            if (secondRowKeys.isNotEmpty) ...[
              const SizedBox(height: 4),
              _buildKeyRow(secondRowKeys),
            ],
          ],
        );
      },
    );
  }

  Widget _buildKeyRow(List<KeyboardKey> keys) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: keys.length,
        itemBuilder: (context, index) => _buildKey(keys[index]),
      ),
    );
  }

  Widget _buildKey(KeyboardKey key) {
    final bool isActive = (key.id == 'ctrl' && _ctrlPressed) ||
        (key.id == 'alt' && _altPressed);

    IconData? icon;
    if (key.id == 'up') icon = Icons.arrow_upward;
    if (key.id == 'down') icon = Icons.arrow_downward;
    if (key.id == 'left') icon = Icons.arrow_back;
    if (key.id == 'right') icon = Icons.arrow_forward;

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Material(
        color: isActive
            ? const Color(0xFF4EC9B0)
            : key.isModifier
                ? const Color(0xFF3D5A5A)
                : const Color(0xFF3D3D3D),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: () => _handleKeyPress(key),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            constraints: const BoxConstraints(minWidth: 44),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Center(
              child: icon != null
                  ? Icon(
                      icon,
                      size: 16,
                      color: isActive ? Colors.black : Colors.white,
                    )
                  : Text(
                      key.label,
                      style: TextStyle(
                        color: isActive ? Colors.black : Colors.white,
                        fontSize: 12,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
