import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _authService = AuthService();
  bool _isAuthenticating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    setState(() {
      _isAuthenticating = true;
      _error = null;
    });

    final isAvailable = await _authService.isBiometricAvailable();

    if (!isAvailable) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
      return;
    }

    final success = await _authService.authenticate(
      localizedReason: 'Autentique-se para acessar o c-term',
    );

    if (mounted) {
      setState(() {
        _isAuthenticating = false;
      });

      if (success) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        setState(() {
          _error = 'Falha na autenticação. Tente novamente.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.terminal,
              size: 80,
              color: Color(0xFF4EC9B0),
            ),
            const SizedBox(height: 24),
            const Text(
              'c-term',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Cliente SSH',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 48),
            if (_isAuthenticating)
              const Column(
                children: [
                  CircularProgressIndicator(
                    color: Color(0xFF4EC9B0),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Autenticando...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              )
            else if (_error != null)
              Column(
                children: [
                  Icon(
                    Icons.fingerprint,
                    size: 64,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: TextStyle(color: Colors.red.shade400),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _authenticate,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Tentar novamente'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4EC9B0),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  const Icon(
                    Icons.fingerprint,
                    size: 64,
                    color: Color(0xFF4EC9B0),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _authenticate,
                    icon: const Icon(Icons.lock_open),
                    label: const Text('Desbloquear'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4EC9B0),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
