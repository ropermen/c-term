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
  bool _shiftPressed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KeyboardProvider>().loadKeys();
    });
  }

  void _handleKeyPress(KeyboardKey key) {
    if (key.isModifier) {
      setState(() {
        if (key.id == 'ctrl') {
          _ctrlPressed = !_ctrlPressed;
        } else if (key.id == 'alt') {
          _altPressed = !_altPressed;
        } else if (key.id == 'shift') {
          _shiftPressed = !_shiftPressed;
        }
      });
      return;
    }

    String output = key.value;

    // Apply Shift modifier (uppercase for letters)
    if (_shiftPressed && key.value.length == 1) {
      output = key.value.toUpperCase();
    }

    // Apply Ctrl modifier
    if (_ctrlPressed) {
      if (output.length == 1) {
        final char = output.toLowerCase();
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
        output = ctrlMap[char] ?? output;
      }
    }

    // Apply Alt modifier (ESC prefix)
    if (_altPressed) {
      output = '\x1B$output';
    }

    // Reset modifiers after key press
    setState(() {
      _ctrlPressed = false;
      _altPressed = false;
      _shiftPressed = false;
    });

    widget.onKeyPressed(output);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF252528),
      child: SafeArea(
        top: false,
        child: _buildKeyboard(),
      ),
    );
  }

  Widget _buildKeyboard() {
    return Consumer<KeyboardProvider>(
      builder: (context, provider, _) {
        final firstRowKeys = provider.enabledKeysRow1;
        final secondRowKeys = provider.enabledKeysRow2;

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

  void _showTextInputDialog() {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        title: const Text(
          'Enviar texto',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: 'Digite o comando...',
            hintStyle: TextStyle(color: Colors.grey.shade500),
            filled: true,
            fillColor: const Color(0xFF1C1C1E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              widget.onKeyPressed(value);
            }
            Navigator.of(ctx).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final text = textController.text;
              if (text.isNotEmpty) {
                widget.onKeyPressed(text);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  Widget _buildFirstRow(List<KeyboardKey> keys) {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          const SizedBox(width: 4),
          // Keyboard settings button
          Material(
            color: const Color(0xFF3C3C3E),
            borderRadius: BorderRadius.circular(4),
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const KeyboardSettingsScreen()),
                );
              },
              borderRadius: BorderRadius.circular(4),
              child: Container(
                width: 32,
                height: 28,
                alignment: Alignment.center,
                child: Icon(Icons.settings, size: 16, color: Colors.grey.shade400),
              ),
            ),
          ),
          const SizedBox(width: 2),
          // Text input button
          Material(
            color: const Color(0xFF3C3C3E),
            borderRadius: BorderRadius.circular(4),
            child: InkWell(
              onTap: _showTextInputDialog,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                width: 32,
                height: 28,
                alignment: Alignment.center,
                child: Icon(Icons.keyboard, size: 16, color: Colors.grey.shade400),
              ),
            ),
          ),
          const SizedBox(width: 2),
          // Modifier indicators
          if (_ctrlPressed || _altPressed || _shiftPressed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF5B8DEF),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                [
                  if (_ctrlPressed) 'Ctrl',
                  if (_altPressed) 'Alt',
                  if (_shiftPressed) 'Shift',
                ].join('+'),
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
        (key.id == 'alt' && _altPressed) ||
        (key.id == 'shift' && _shiftPressed);

    IconData? icon;
    if (key.id == 'up') icon = Icons.arrow_upward;
    if (key.id == 'down') icon = Icons.arrow_downward;
    if (key.id == 'left') icon = Icons.arrow_back;
    if (key.id == 'right') icon = Icons.arrow_forward;

    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: Material(
        color: isActive
            ? const Color(0xFF5B8DEF)
            : key.isModifier
                ? const Color(0xFF3A4A6A)
                : const Color(0xFF3C3C3E),
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
