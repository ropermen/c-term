# koder

Cliente SSH para Flutter com autenticacao biometrica e suporte a multiplas conexoes simultaneas.

## Funcionalidades

- **Autenticacao Biometrica**: Protecao do aplicativo com impressao digital ou Face ID
- **Gerenciamento de Conexoes**: Cadastro, edicao e exclusao de conexoes SSH
- **Terminal Integrado**: Terminal completo com suporte a cores ANSI
- **Multiplas Sessoes**: Abra varias conexoes simultaneamente em tabs
- **Armazenamento Seguro**: Credenciais armazenadas de forma criptografada

## Capturas de Tela

*Em breve*

## Instalacao

### Pre-requisitos

- Flutter SDK 3.6+
- Android SDK / Xcode (para iOS)

### Executar em modo de desenvolvimento

```bash
flutter pub get
flutter run
```

### Build para producao

```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release
```

## Arquitetura

```
lib/
├── main.dart              # Ponto de entrada
├── app.dart               # Configuracao do MaterialApp
├── models/
│   └── ssh_connection.dart    # Modelo de conexao SSH
├── providers/
│   ├── connections_provider.dart  # Estado das conexoes
│   └── terminal_provider.dart     # Estado dos terminais
├── screens/
│   ├── auth_screen.dart           # Tela de autenticacao
│   ├── home_screen.dart           # Lista de conexoes
│   ├── connection_form_screen.dart # Formulario de conexao
│   └── terminal_screen.dart       # Terminal SSH
└── services/
    ├── auth_service.dart      # Servico de biometria
    ├── ssh_service.dart       # Servico SSH
    └── storage_service.dart   # Armazenamento seguro
```

## Dependencias Principais

- `dartssh2`: Cliente SSH para Dart
- `xterm`: Widget de terminal
- `local_auth`: Autenticacao biometrica
- `flutter_secure_storage`: Armazenamento seguro
- `provider`: Gerenciamento de estado

## Licenca

MIT
