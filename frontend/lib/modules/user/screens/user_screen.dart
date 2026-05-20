import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_drawer.dart';
import '../services/user_service.dart';

/// Phase 11 — Company User Management screen.
/// Visible to MANAGER and SUPER_ADMIN only (drawer already gates this).
class UserScreen extends StatefulWidget {
  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  final _service = UserService();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => setState(() => _future = _service.getUsers());

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Color _roleColor(String? role) {
    switch (role) {
      case 'SUPER_ADMIN': return const Color(0xFF7C3AED);
      case 'MANAGER':     return AppColors.primary;
      case 'SUPERVISOR':  return AppColors.accent;
      case 'DRIVER':      return AppColors.success;
      default:            return Colors.grey;
    }
  }

  IconData _roleIcon(String? role) {
    switch (role) {
      case 'SUPER_ADMIN': return Icons.admin_panel_settings_rounded;
      case 'MANAGER':     return Icons.manage_accounts_rounded;
      case 'SUPERVISOR':  return Icons.supervisor_account_rounded;
      case 'DRIVER':      return Icons.local_shipping_rounded;
      default:            return Icons.person_rounded;
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  // ─── Actions ──────────────────────────────────────────────────────────────

  Future<void> _showAddDialog() async {
    final nameCtrl     = TextEditingController();
    final emailCtrl    = TextEditingController();
    final passwordCtrl = TextEditingController();
    String selectedRole = 'SUPERVISOR';
    bool obscure = true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          title: const Row(children: [
            Icon(Icons.person_add_rounded, size: 20),
            SizedBox(width: 8),
            Text('Add User'),
          ]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email *',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordCtrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'Password *',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () =>
                        setDlgState(() => obscure = !obscure),
                  ),
                  helperText: 'Min 8 characters',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                items: ['MANAGER', 'SUPERVISOR', 'DRIVER']
                    .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(r),
                        ))
                    .toList(),
                onChanged: (v) =>
                    setDlgState(() => selectedRole = v ?? selectedRole),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add User'),
              onPressed: () async {
                if (nameCtrl.text.isEmpty ||
                    emailCtrl.text.isEmpty ||
                    passwordCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text('Please fill all required fields')),
                  );
                  return;
                }
                if (passwordCtrl.text.length < 8) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Password must be at least 8 characters')),
                  );
                  return;
                }
                try {
                  await _service.createUser({
                    'full_name': nameCtrl.text.trim(),
                    'email':     emailCtrl.text.trim().toLowerCase(),
                    'password':  passwordCtrl.text,
                    'role_name': selectedRole,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            '${nameCtrl.text.trim()} added successfully'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    String msg = 'Failed to add user';
                    try {
                      final detail =
                          (e as dynamic).response?.data?['detail'];
                      if (detail is String) msg = detail;
                    } catch (_) {}
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                          content: Text(msg),
                          backgroundColor: AppColors.error),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditDialog(Map<String, dynamic> user) async {
    final nameCtrl  = TextEditingController(text: user['full_name'] as String? ?? '');
    String selectedRole = user['role_name'] as String? ?? 'SUPERVISOR';
    bool isActive   = user['is_active'] as bool? ?? true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          title: const Row(children: [
            Icon(Icons.edit_rounded, size: 20),
            SizedBox(width: 8),
            Text('Edit User'),
          ]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              // Role dropdown — disable for SUPER_ADMIN
              if (selectedRole != 'SUPER_ADMIN')
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  items: ['MANAGER', 'SUPERVISOR', 'DRIVER']
                      .map((r) => DropdownMenuItem(
                            value: r,
                            child: Text(r),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setDlgState(() => selectedRole = v ?? selectedRole),
                ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: isActive,
                onChanged: (v) => setDlgState(() => isActive = v),
                title: const Text('Active'),
                subtitle: Text(isActive ? 'User can log in' : 'Access disabled'),
                contentPadding: EdgeInsets.zero,
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.save_rounded, size: 16),
              label: const Text('Save'),
              onPressed: () async {
                try {
                  final payload = <String, dynamic>{
                    'full_name': nameCtrl.text.trim(),
                    'is_active': isActive,
                  };
                  if (selectedRole != 'SUPER_ADMIN') {
                    payload['role_name'] = selectedRole;
                  }
                  await _service.updateUser(
                      user['id'] as int, payload);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('User updated successfully'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    String msg = 'Failed to update user';
                    try {
                      final detail =
                          (e as dynamic).response?.data?['detail'];
                      if (detail is String) msg = detail;
                    } catch (_) {}
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                          content: Text(msg),
                          backgroundColor: AppColors.error),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeactivate(Map<String, dynamic> user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(children: [
          Icon(Icons.person_off_rounded, color: Colors.red, size: 20),
          SizedBox(width: 8),
          Text('Deactivate User'),
        ]),
        content: Text(
          'Deactivate "${user['full_name']}"?\nThey will no longer be able to log in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await _service.deactivateUser(user['id'] as int);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user['full_name']} deactivated'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Failed to deactivate user';
        try {
          final detail = (e as dynamic).response?.data?['detail'];
          if (detail is String) msg = detail;
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.error),
        );
      }
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Users'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            onPressed: _showAddDialog,
            tooltip: 'Add User',
          ),
        ],
      ),
      drawer: const AppDrawer(activeRoute: 'users'),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text('Failed to load: ${snap.error}'),
                const SizedBox(height: 12),
                ElevatedButton(
                    onPressed: _load, child: const Text('Retry')),
              ]),
            );
          }

          final users = snap.data ?? [];
          final activeCount =
              users.where((u) => u['is_active'] == true).length;

          if (users.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.group_outlined,
                    size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('No users yet',
                    style: TextStyle(
                        color: Colors.grey[600], fontSize: 16)),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _showAddDialog,
                  icon: const Icon(Icons.person_add_rounded),
                  label: const Text('Add User'),
                ),
              ]),
            );
          }

          return Column(
            children: [
              // Summary bar
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                color: AppColors.primary.withValues(alpha: 0.05),
                child: Row(children: [
                  Icon(Icons.group_rounded,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    '$activeCount active  •  ${users.length} total',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ]),
              ),

              // User list
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => _load(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: users.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final user = users[i];
                      final role = user['role_name'] as String?;
                      final isActive = user['is_active'] as bool? ?? true;
                      final name =
                          user['full_name'] as String? ?? 'Unknown';

                      return Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: isActive
                              ? BorderSide.none
                              : BorderSide(
                                  color: Colors.grey[300]!),
                        ),
                        child: Opacity(
                          opacity: isActive ? 1.0 : 0.5,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(children: [
                              // Avatar
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: _roleColor(role)
                                      .withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    _initials(name),
                                    style: TextStyle(
                                      color: _roleColor(role),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                      if (!isActive) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'INACTIVE',
                                            style: TextStyle(
                                                fontSize: 9,
                                                color: Colors.grey,
                                                fontWeight:
                                                    FontWeight.w700),
                                          ),
                                        ),
                                      ],
                                    ]),
                                    const SizedBox(height: 3),
                                    Text(
                                      user['email'] as String? ?? '',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(children: [
                                      Icon(
                                        _roleIcon(role),
                                        size: 13,
                                        color: _roleColor(role),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        role ?? 'No role',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _roleColor(role),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ]),
                                  ],
                                ),
                              ),

                              // Actions
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert,
                                    color: Colors.grey),
                                onSelected: (action) {
                                  if (action == 'edit') {
                                    _showEditDialog(user);
                                  } else if (action == 'deactivate') {
                                    _confirmDeactivate(user);
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(children: [
                                      Icon(Icons.edit_rounded,
                                          size: 16),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ]),
                                  ),
                                  if (isActive)
                                    PopupMenuItem(
                                      value: 'deactivate',
                                      child: Row(children: [
                                        Icon(Icons.person_off_rounded,
                                            size: 16,
                                            color: AppColors.error),
                                        const SizedBox(width: 8),
                                        Text('Deactivate',
                                            style: TextStyle(
                                                color: AppColors.error)),
                                      ]),
                                    ),
                                ],
                              ),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
