import 'package:flutter/material.dart';

class TerminalKeyboard extends StatefulWidget {
  final void Function(String) onKeyPressed;
  final VoidCallback? onToggle;

  const TerminalKeyboard({
    super.key,
    required this.onKeyPressed,
    this.onToggle,
  });

  @override
  State<TerminalKeyboard> createState() => _TerminalKeyboardState();
}

class _TerminalKeyboardState extends State<TerminalKeyboard> {
  bool _ctrlPressed = false;
  bool _altPressed = false;
  bool _showExtended = false;

  void _sendKey(String key) {
    String output = key;

    if (_ctrlPressed) {
      // Ctrl + key combinations
      final ctrlMap = {
        'c': '\x03', // SIGINT
        'd': '\x04', // EOF
        'z': '\x1A', // SIGTSTP
        'l': '\x0C', // Clear screen
        'a': '\x01', // Beginning of line
        'e': '\x05', // End of line
        'u': '\x15', // Kill line
        'k': '\x0B', // Kill to end of line
        'w': '\x17', // Delete word
        'r': '\x12', // Reverse search
        'p': '\x10', // Previous command
        'n': '\x0E', // Next command
      };
      output = ctrlMap[key.toLowerCase()] ?? key;
      setState(() => _ctrlPressed = false);
    } else if (_altPressed) {
      // Alt + key (send escape sequence)
      output = '\x1B$key';
      setState(() => _altPressed = false);
    }

    widget.onKeyPressed(output);
  }

  void _sendSpecialKey(String sequence) {
    widget.onKeyPressed(sequence);
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
            // Toggle and modifier row
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  _ModifierKey(
                    label: 'Ctrl',
                    isPressed: _ctrlPressed,
                    onTap: () => setState(() {
                      _ctrlPressed = !_ctrlPressed;
                      if (_ctrlPressed) _altPressed = false;
                    }),
                  ),
                  const SizedBox(width: 4),
                  _ModifierKey(
                    label: 'Alt',
                    isPressed: _altPressed,
                    onTap: () => setState(() {
                      _altPressed = !_altPressed;
                      if (_altPressed) _ctrlPressed = false;
                    }),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => setState(() => _showExtended = !_showExtended),
                    icon: Icon(
                      _showExtended ? Icons.keyboard_hide : Icons.keyboard,
                      size: 18,
                      color: Colors.grey.shade400,
                    ),
                    label: Text(
                      _showExtended ? 'Menos' : 'Mais',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF3D3D3D)),
            // Main keys row
            _buildMainRow(),
            if (_showExtended) ...[
              const SizedBox(height: 4),
              _buildExtendedRow1(),
              const SizedBox(height: 4),
              _buildExtendedRow2(),
              const SizedBox(height: 4),
              _buildExtendedRow3(),
            ],
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildMainRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          _KeyButton(label: 'Tab', onTap: () => _sendSpecialKey('\t')),
          _KeyButton(label: 'Esc', onTap: () => _sendSpecialKey('\x1B')),
          _KeyButton(
            label: 'Ctrl+C',
            color: Colors.red.shade900,
            onTap: () => _sendSpecialKey('\x03'),
          ),
          _KeyButton(
            label: 'Ctrl+D',
            color: Colors.orange.shade900,
            onTap: () => _sendSpecialKey('\x04'),
          ),
          _KeyButton(
            label: 'Ctrl+Z',
            color: Colors.blue.shade900,
            onTap: () => _sendSpecialKey('\x1A'),
          ),
          _KeyButton(label: 'Up', icon: Icons.arrow_upward, onTap: () => _sendSpecialKey('\x1B[A')),
          _KeyButton(label: 'Down', icon: Icons.arrow_downward, onTap: () => _sendSpecialKey('\x1B[B')),
          _KeyButton(label: 'Left', icon: Icons.arrow_back, onTap: () => _sendSpecialKey('\x1B[D')),
          _KeyButton(label: 'Right', icon: Icons.arrow_forward, onTap: () => _sendSpecialKey('\x1B[C')),
        ],
      ),
    );
  }

  Widget _buildExtendedRow1() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          _KeyButton(label: '|', onTap: () => _sendKey('|')),
          _KeyButton(label: '&', onTap: () => _sendKey('&')),
          _KeyButton(label: ';', onTap: () => _sendKey(';')),
          _KeyButton(label: '>', onTap: () => _sendKey('>')),
          _KeyButton(label: '<', onTap: () => _sendKey('<')),
          _KeyButton(label: '>>', onTap: () => _sendKey('>>')),
          _KeyButton(label: '2>', onTap: () => _sendKey('2>')),
          _KeyButton(label: '&>', onTap: () => _sendKey('&>')),
          _KeyButton(label: '||', onTap: () => _sendKey('||')),
          _KeyButton(label: '&&', onTap: () => _sendKey('&&')),
        ],
      ),
    );
  }

  Widget _buildExtendedRow2() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          _KeyButton(label: '~', onTap: () => _sendKey('~')),
          _KeyButton(label: '/', onTap: () => _sendKey('/')),
          _KeyButton(label: '\\', onTap: () => _sendKey('\\')),
          _KeyButton(label: '-', onTap: () => _sendKey('-')),
          _KeyButton(label: '_', onTap: () => _sendKey('_')),
          _KeyButton(label: '.', onTap: () => _sendKey('.')),
          _KeyButton(label: '*', onTap: () => _sendKey('*')),
          _KeyButton(label: '?', onTap: () => _sendKey('?')),
          _KeyButton(label: '!', onTap: () => _sendKey('!')),
          _KeyButton(label: '@', onTap: () => _sendKey('@')),
        ],
      ),
    );
  }

  Widget _buildExtendedRow3() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          _KeyButton(label: '\$', onTap: () => _sendKey('\$')),
          _KeyButton(label: '#', onTap: () => _sendKey('#')),
          _KeyButton(label: '%', onTap: () => _sendKey('%')),
          _KeyButton(label: '^', onTap: () => _sendKey('^')),
          _KeyButton(label: '(', onTap: () => _sendKey('(')),
          _KeyButton(label: ')', onTap: () => _sendKey(')')),
          _KeyButton(label: '[', onTap: () => _sendKey('[')),
          _KeyButton(label: ']', onTap: () => _sendKey(']')),
          _KeyButton(label: '{', onTap: () => _sendKey('{')),
          _KeyButton(label: '}', onTap: () => _sendKey('}')),
          _KeyButton(label: '"', onTap: () => _sendKey('"')),
          _KeyButton(label: "'", onTap: () => _sendKey("'")),
          _KeyButton(label: '`', onTap: () => _sendKey('`')),
          _KeyButton(label: '=', onTap: () => _sendKey('=')),
          _KeyButton(label: '+', onTap: () => _sendKey('+')),
        ],
      ),
    );
  }
}

class _ModifierKey extends StatelessWidget {
  final String label;
  final bool isPressed;
  final VoidCallback onTap;

  const _ModifierKey({
    required this.label,
    required this.isPressed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isPressed ? const Color(0xFF4EC9B0) : const Color(0xFF3D3D3D),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isPressed ? const Color(0xFF4EC9B0) : const Color(0xFF4D4D4D),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isPressed ? Colors.black : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final Color? color;

  const _KeyButton({
    required this.label,
    this.icon,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Material(
        color: color ?? const Color(0xFF3D3D3D),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            constraints: const BoxConstraints(minWidth: 44),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Center(
              child: icon != null
                  ? Icon(icon, size: 16, color: Colors.white)
                  : Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
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
