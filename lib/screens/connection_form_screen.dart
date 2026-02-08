import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ssh_connection.dart';
import '../providers/connections_provider.dart';

class ConnectionFormScreen extends StatefulWidget {
  final Connection? connection;
  final ConnectionType connectionType;
  final bool asDialog;

  const ConnectionFormScreen({
    super.key,
    this.connection,
    this.connectionType = ConnectionType.ssh,
    this.asDialog = false,
  });

  @override
  State<ConnectionFormScreen> createState() => _ConnectionFormScreenState();
}

class _ConnectionFormScreenState extends State<ConnectionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _privateKeyController = TextEditingController();
  final _domainController = TextEditingController();

  bool _usePrivateKey = false;
  bool _obscurePassword = true;
  bool _isSaving = false;
  RdpScaleMode _rdpScaleMode = RdpScaleMode.clientResolution;

  bool get _isEditing => widget.connection != null;
  ConnectionType get _type => widget.connection?.type ?? widget.connectionType;

  @override
  void initState() {
    super.initState();
    if (widget.connection != null) {
      _nameController.text = widget.connection!.name;
      _hostController.text = widget.connection!.host;
      _portController.text = widget.connection!.port.toString();
      _usernameController.text = widget.connection!.username;
      _passwordController.text = widget.connection!.password ?? '';
      _privateKeyController.text = widget.connection!.privateKey ?? '';
      _domainController.text = widget.connection!.domain ?? '';
      _rdpScaleMode = widget.connection!.rdpScaleMode;
      _usePrivateKey = widget.connection!.privateKey?.isNotEmpty ?? false;
    } else {
      _portController.text = _type.defaultPort.toString();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _privateKeyController.dispose();
    _domainController.dispose();
    super.dispose();
  }

  Future<void> _saveConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final provider = context.read<ConnectionsProvider>();

      if (_isEditing) {
        final updated = widget.connection!.copyWith(
          name: _nameController.text.trim(),
          host: _hostController.text.trim(),
          port: int.parse(_portController.text.trim()),
          username: _usernameController.text.trim(),
          password: _usePrivateKey ? null : _passwordController.text,
          privateKey: _usePrivateKey ? _privateKeyController.text : null,
          domain: _type == ConnectionType.rdp ? _domainController.text.trim() : null,
          rdpScaleMode: _type == ConnectionType.rdp ? _rdpScaleMode : RdpScaleMode.fit,
        );
        await provider.updateConnection(updated);
      } else {
        await provider.addConnection(
          name: _nameController.text.trim(),
          host: _hostController.text.trim(),
          port: int.parse(_portController.text.trim()),
          username: _usernameController.text.trim(),
          password: _usePrivateKey ? null : _passwordController.text,
          privateKey: _usePrivateKey ? _privateKeyController.text : null,
          type: _type,
          domain: _type == ConnectionType.rdp ? _domainController.text.trim() : null,
          rdpScaleMode: _type == ConnectionType.rdp ? _rdpScaleMode : RdpScaleMode.fit,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.asDialog) {
      return _buildDialog(context);
    }
    return _buildFullPage(context);
  }

  Widget _buildDialog(BuildContext context) {
    final title = _isEditing
        ? 'Editar ${_type.label}'
        : 'Nova Conexão ${_type.label}';

    return Dialog(
      backgroundColor: const Color(0xFF1C1C1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFF3A3A3C), height: 1),
                // Form body
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _buildFormFields(compact: true),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullPage(BuildContext context) {
    final title = _isEditing
        ? 'Editar Conexão ${_type.label}'
        : 'Nova Conexão ${_type.label}';

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C2C2E),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: _buildFormFields(compact: false),
        ),
      ),
    );
  }

  List<Widget> _buildFormFields({required bool compact}) {
    final spacing = compact ? 8.0 : 16.0;

    return [
      _buildTextField(
        controller: _nameController,
        label: 'Nome da conexão',
        hint: 'Ex: Servidor de produção',
        icon: Icons.label_outline,
        compact: compact,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Informe um nome para a conexão';
          }
          return null;
        },
      ),
      SizedBox(height: spacing),
      Row(
        children: [
          Expanded(
            flex: 3,
            child: _buildTextField(
              controller: _hostController,
              label: 'Host',
              hint: 'Ex: 192.168.1.100',
              icon: Icons.dns_outlined,
              keyboardType: TextInputType.url,
              compact: compact,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Informe o host';
                }
                return null;
              },
            ),
          ),
          SizedBox(width: spacing),
          Expanded(
            flex: 1,
            child: _buildTextField(
              controller: _portController,
              label: 'Porta',
              hint: _type.defaultPort.toString(),
              icon: Icons.numbers,
              keyboardType: TextInputType.number,
              compact: compact,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Informe a porta';
                }
                final port = int.tryParse(value.trim());
                if (port == null || port < 1 || port > 65535) {
                  return 'Porta inválida';
                }
                return null;
              },
            ),
          ),
        ],
      ),
      SizedBox(height: spacing),

      // Username: SSH and RDP require it, VNC does not
      if (_type != ConnectionType.vnc)
        _buildTextField(
          controller: _usernameController,
          label: 'Usuário',
          hint: 'Ex: root',
          icon: Icons.person_outline,
          compact: compact,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Informe o usuário';
            }
            return null;
          },
        ),
      if (_type != ConnectionType.vnc) SizedBox(height: spacing),

      // Domain: RDP only
      if (_type == ConnectionType.rdp) ...[
        _buildTextField(
          controller: _domainController,
          label: 'Domínio (opcional)',
          hint: 'Ex: CORP',
          icon: Icons.domain,
          compact: compact,
        ),
        SizedBox(height: spacing),
        // Scale mode selector
        Container(
          padding: EdgeInsets.all(compact ? 10 : 16),
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2E),
            borderRadius: BorderRadius.circular(compact ? 8 : 12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Modo de exibição',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 13 : 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: compact ? 8 : 12),
              ...RdpScaleMode.values.map((mode) => _ScaleModeOption(
                mode: mode,
                isSelected: _rdpScaleMode == mode,
                onTap: () => setState(() => _rdpScaleMode = mode),
                compact: compact,
              )),
            ],
          ),
        ),
        SizedBox(height: spacing),
      ],

      // Auth method: SSH has password/key toggle, RDP and VNC have password only
      if (_type == ConnectionType.ssh) ...[
        SizedBox(height: compact ? 4 : 8),
        Container(
          padding: EdgeInsets.all(compact ? 10 : 16),
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2E),
            borderRadius: BorderRadius.circular(compact ? 8 : 12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Método de autenticação',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 13 : 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: compact ? 8 : 12),
              Row(
                children: [
                  Expanded(
                    child: _AuthMethodButton(
                      label: 'Senha',
                      icon: Icons.password,
                      isSelected: !_usePrivateKey,
                      onTap: () => setState(() => _usePrivateKey = false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AuthMethodButton(
                      label: 'Chave SSH',
                      icon: Icons.key,
                      isSelected: _usePrivateKey,
                      onTap: () => setState(() => _usePrivateKey = true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: spacing),
        if (_usePrivateKey)
          _buildTextField(
            controller: _privateKeyController,
            label: 'Chave privada (PEM)',
            hint: '-----BEGIN OPENSSH PRIVATE KEY-----\n...',
            icon: Icons.key,
            maxLines: compact ? 4 : 8,
            compact: compact,
            validator: (value) {
              if (_usePrivateKey &&
                  (value == null || value.trim().isEmpty)) {
                return 'Informe a chave privada';
              }
              return null;
            },
          )
        else
          _buildPasswordField(compact: compact),
      ] else ...[
        // RDP and VNC: password only
        _buildPasswordField(compact: compact),
      ],

      SizedBox(height: compact ? 12 : 32),
      SizedBox(
        height: compact ? 36 : 50,
        child: ElevatedButton(
          onPressed: _isSaving ? null : _saveConnection,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5B8DEF),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(compact ? 8 : 12),
            ),
          ),
          child: _isSaving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
              : Text(
                  _isEditing ? 'Salvar alterações' : 'Criar conexão',
                  style: TextStyle(
                    fontSize: compact ? 14 : 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    ];
  }

  Widget _buildPasswordField({bool compact = false}) {
    return _buildTextField(
      controller: _passwordController,
      label: 'Senha',
      hint: 'Digite a senha',
      icon: Icons.lock_outline,
      obscureText: _obscurePassword,
      compact: compact,
      suffixIcon: IconButton(
        icon: Icon(
          _obscurePassword
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          color: Colors.grey,
          size: compact ? 18 : 24,
        ),
        onPressed: () =>
            setState(() => _obscurePassword = !_obscurePassword),
      ),
      validator: (value) {
        if (_type == ConnectionType.ssh && !_usePrivateKey &&
            (value == null || value.isEmpty)) {
          return 'Informe a senha';
        }
        return null;
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    bool compact = false,
    Widget? suffixIcon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    final radius = compact ? 8.0 : 12.0;
    final fontSize = compact ? 13.0 : 14.0;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: maxLines,
      style: TextStyle(color: Colors.white, fontSize: fontSize),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: Colors.grey.shade400, fontSize: fontSize),
        hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: fontSize),
        prefixIcon: Icon(icon, color: Colors.grey.shade400, size: compact ? 18 : 24),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFF2C2C2E),
        isDense: compact,
        contentPadding: compact
            ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: Color(0xFF5B8DEF), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
      validator: validator,
    );
  }
}

class _ScaleModeOption extends StatelessWidget {
  final RdpScaleMode mode;
  final bool isSelected;
  final VoidCallback onTap;
  final bool compact;

  const _ScaleModeOption({
    required this.mode,
    required this.isSelected,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 4 : 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(compact ? 6 : 8),
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: compact ? 6 : 10,
            horizontal: compact ? 8 : 12,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF5B8DEF).withOpacity(0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(compact ? 6 : 8),
            border: Border.all(
              color: isSelected ? const Color(0xFF5B8DEF) : Colors.grey.shade700,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: isSelected ? const Color(0xFF5B8DEF) : Colors.grey,
                size: compact ? 16 : 20,
              ),
              SizedBox(width: compact ? 8 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.label,
                      style: TextStyle(
                        color: isSelected ? const Color(0xFF5B8DEF) : Colors.white,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        fontSize: compact ? 12 : 14,
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 2),
                      Text(
                        mode.description,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthMethodButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _AuthMethodButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF5B8DEF).withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF5B8DEF) : Colors.grey.shade600,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF5B8DEF) : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF5B8DEF) : Colors.grey,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
