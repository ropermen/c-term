import 'package:flutter/material.dart';
import '../services/api_service.dart';

class UserManagementDialog extends StatefulWidget {
  const UserManagementDialog({super.key});

  @override
  State<UserManagementDialog> createState() => _UserManagementDialogState();
}

class _UserManagementDialogState extends State<UserManagementDialog> {
  final _api = ApiService();
  List<ApiUser> _users = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() { _loading = true; _error = null; });
    try {
      _users = await _api.listUsers();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _showUserForm({ApiUser? user}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _UserFormDialog(user: user),
    );
    if (result == true) _loadUsers();
  }

  Future<void> _deleteUser(ApiUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        title: const Text('Excluir usuário', style: TextStyle(color: Colors.white)),
        content: Text('Excluir "${user.username}"?', style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _api.deleteUser(user.id);
        _loadUsers();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1C1C1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Gerenciar Usuários',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: Color(0xFF5B8DEF), size: 20),
                    tooltip: 'Novo usuário',
                    onPressed: () => _showUserForm(),
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
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: Color(0xFF5B8DEF)),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!, style: TextStyle(color: Colors.red.shade300)),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    final isSelf = user.id == _api.currentUser?.id;
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: user.isAdmin
                            ? const Color(0xFF5B8DEF).withOpacity(0.2)
                            : Colors.grey.withOpacity(0.2),
                        child: Icon(
                          user.isAdmin ? Icons.admin_panel_settings : Icons.person,
                          size: 16,
                          color: user.isAdmin ? const Color(0xFF5B8DEF) : Colors.grey,
                        ),
                      ),
                      title: Text(
                        user.username,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                      subtitle: Text(
                        '${user.displayName.isEmpty ? '-' : user.displayName} · ${user.role}',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 16, color: Colors.grey),
                            onPressed: () => _showUserForm(user: user),
                            tooltip: 'Editar',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          ),
                          if (!isSelf)
                            IconButton(
                              icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                              onPressed: () => _deleteUser(user),
                              tooltip: 'Excluir',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _UserFormDialog extends StatefulWidget {
  final ApiUser? user;
  const _UserFormDialog({this.user});

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _api = ApiService();
  String _role = 'user';
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.user != null;

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _usernameController.text = widget.user!.username;
      _displayNameController.text = widget.user!.displayName;
      _role = widget.user!.role;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });

    try {
      if (_isEditing) {
        await _api.updateUser(
          widget.user!.id,
          displayName: _displayNameController.text.trim(),
          role: _role,
          password: _passwordController.text.isNotEmpty ? _passwordController.text : null,
        );
      } else {
        await _api.createUser(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          displayName: _displayNameController.text.trim(),
          role: _role,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1C1C1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _isEditing ? 'Editar Usuário' : 'Novo Usuário',
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
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _field(
                        controller: _usernameController,
                        label: 'Usuário',
                        icon: Icons.person_outline,
                        enabled: !_isEditing,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Obrigatório' : null,
                      ),
                      const SizedBox(height: 8),
                      _field(
                        controller: _displayNameController,
                        label: 'Nome de exibição',
                        icon: Icons.badge_outlined,
                      ),
                      const SizedBox(height: 8),
                      _field(
                        controller: _passwordController,
                        label: _isEditing ? 'Nova senha (deixe vazio para manter)' : 'Senha',
                        icon: Icons.lock_outline,
                        obscure: true,
                        validator: _isEditing
                            ? null
                            : (v) => v == null || v.isEmpty ? 'Obrigatório' : null,
                      ),
                      const SizedBox(height: 8),
                      // Role selector
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2C2E),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.shield_outlined, size: 18, color: Colors.grey.shade400),
                            const SizedBox(width: 10),
                            Text('Perfil:', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('Usuário', style: TextStyle(fontSize: 12)),
                              selected: _role == 'user',
                              onSelected: (_) => setState(() => _role = 'user'),
                              selectedColor: const Color(0xFF5B8DEF).withOpacity(0.3),
                              backgroundColor: Colors.transparent,
                              side: BorderSide.none,
                              labelStyle: TextStyle(
                                color: _role == 'user' ? const Color(0xFF5B8DEF) : Colors.grey,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            ChoiceChip(
                              label: const Text('Admin', style: TextStyle(fontSize: 12)),
                              selected: _role == 'admin',
                              onSelected: (_) => setState(() => _role = 'admin'),
                              selectedColor: const Color(0xFF5B8DEF).withOpacity(0.3),
                              backgroundColor: Colors.transparent,
                              side: BorderSide.none,
                              labelStyle: TextStyle(
                                color: _role == 'admin' ? const Color(0xFF5B8DEF) : Colors.grey,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(_error!, style: TextStyle(color: Colors.red.shade300, fontSize: 12)),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 36,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5B8DEF),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: _saving
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : Text(_isEditing ? 'Salvar' : 'Criar', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      enabled: enabled,
      style: TextStyle(color: enabled ? Colors.white : Colors.grey, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 18),
        filled: true,
        fillColor: const Color(0xFF2C2C2E),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF5B8DEF), width: 2),
        ),
      ),
      validator: validator,
    );
  }
}
