import 'package:flutter/material.dart';
import '../providers/terminal_provider.dart';

class RdpViewPanel extends StatelessWidget {
  final TerminalSession session;

  const RdpViewPanel({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.desktop_windows, size: 48, color: Colors.grey.shade700),
          const SizedBox(height: 16),
          Text(
            'RDP nao disponivel nesta plataforma',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Use a versao web do koder para conexoes RDP.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
