import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class AuthService {
  final LocalAuthentication _localAuth;

  AuthService({LocalAuthentication? localAuth})
      : _localAuth = localAuth ?? LocalAuthentication();

  Future<bool> isBiometricAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics =
          await _localAuth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();
      return canAuthenticate;
    } on PlatformException {
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  Future<bool> authenticate({
    String localizedReason = 'Autentique-se para acessar o koder',
  }) async {
    try {
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
      return didAuthenticate;
    } on PlatformException {
      return false;
    }
  }

  Future<void> cancelAuthentication() async {
    await _localAuth.stopAuthentication();
  }
}
