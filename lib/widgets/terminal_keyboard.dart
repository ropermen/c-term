import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/keyboard_provider.dart';
import '../models/keyboard_key.dart';
import '../screens/keyboard_settings_screen.dart';

class TerminalKeyboard extends StatefulWidget {
  final void Function(String) onKeyPressed;
  final VoidCallback onToggleKeyboard;

  const TerminalKeyboard({
    super.key,
    required this.onKeyPressed,
    required this.onToggleKeyboard,
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
        child: _buildKeyboard(),
      ),
    );
  }

  Widget _buildKeyboard() {
    return Consumer<KeyboardProvider>(
      builder: (context, provider, _) {
        final enabledKeys = provider.enabledKeys;

        // Split keys into two rows
        final midpoint = (enabledKeys.length / 2).ceil();
        final firstRowKeys = enabledKeys.take(midpoint).toList();
        final secondRowKeys = enabledKeys.skip(midpoint).toList();

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFirstRow(firstRowKeys),
            if (secondRowKeys.isNotEmpty) ...[
              const SizedBox(height: 2),
              _buildKeyRow(secondRowKeys),
            ],
          ],
        );
      },
    );
  }

  Widget _buildFirstRow(List<KeyboardKey> keys) {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          const SizedBox(width: 4),
          // Minimize keyboard button
          _buildControlButton(
            icon: Icons.keyboard_hide,
            onTap: widget.onToggleKeyboard,
            tooltip: 'Minimizar teclado',
          ),
          const SizedBox(width: 2),
          // Settings button
          _buildControlButton(
            icon: Icons.settings,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const KeyboardSettingsScreen()),
              );
            },
            tooltip: 'Configurar teclas',
          ),
          const SizedBox(width: 2),
          // Modifier indicator
          if (_ctrlPressed || _altPressed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF4EC9B0),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _ctrlPressed ? 'Ctrl' : 'Alt',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          // Keys
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 4, right: 8),
              itemCount: keys.length,
              itemBuilder: (context, index) => _buildKey(keys[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Material(
      color: const Color(0xFF3D3D3D),
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 32,
          height: 28,
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: Colors.grey.shade400),
        ),
      ),
    );
  }

  Widget _buildKeyRow(List<KeyboardKey> keys) {
    return SizedBox(
      height: 32,
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
      padding: const EdgeInsets.only(right: 2),
      child: Material(
        color: isActive
            ? const Color(0xFF4EC9B0)
            : key.isModifier
                ? const Color(0xFF3D5A5A)
                : const Color(0xFF3D3D3D),
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: () => _handleKeyPress(key),
          borderRadius: BorderRadius.circular(4),
          child: Container(
            constraints: const BoxConstraints(minWidth: 32),
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            child: icon != null
                ? Icon(
                    icon,
                    size: 14,
                    color: isActive ? Colors.black : Colors.white,
                  )
                : Text(
                    key.label,
                    style: TextStyle(
                      color: isActive ? Colors.black : Colors.white,
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
