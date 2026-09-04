import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_user.dart';
import '../models/permission.dart';
import '../providers/session_provider.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import '../widgets/glass_container.dart';

/// Panel exclusivo del admin: crea y gestiona los usuarios (empleados)
/// vinculados al kiosco actual, y permite desvincular un dispositivo.
class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({Key? key}) : super(key: key);

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  final _authService = AuthService();

  void _showCreateEmployeeDialog() {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final kioscoId = session.kioscoId!;
    final usuarioController = TextEditingController();
    final nombreController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool loading = false;
    String? error;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: GlassContainer(
                  borderRadius: BorderRadius.circular(24),
                  blur: 26,
                  padding: EdgeInsets.zero,
                  child: Material(
                    type: MaterialType.transparency,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Nuevo empleado',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: nombreController,
                              decoration: InputDecoration(
                                labelText: 'Nombre (opcional)',
                                prefixIcon: const Icon(Icons.badge),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: usuarioController,
                              decoration: InputDecoration(
                                labelText: 'Usuario',
                                prefixIcon: const Icon(Icons.person),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty) ? 'Ingresá un usuario' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: passwordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: 'Contraseña',
                                prefixIcon: const Icon(Icons.lock),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                            ),
                            if (error != null) ...[
                              const SizedBox(height: 12),
                              Text(error!, style: const TextStyle(color: AppConstants.errorColor)),
                            ],
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: loading ? null : () => Navigator.pop(context),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text('Cancelar'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: loading
                                        ? null
                                        : () async {
                                            if (!formKey.currentState!.validate()) return;
                                            setStateDialog(() {
                                              loading = true;
                                              error = null;
                                            });
                                            try {
                                              await _authService.createEmployee(
                                                kioscoId: kioscoId,
                                                usuario: usuarioController.text.trim(),
                                                password: passwordController.text,
                                                displayName: nombreController.text,
                                              );
                                              if (context.mounted) Navigator.pop(context);
                                            } catch (e) {
                                              setStateDialog(() {
                                                loading = false;
                                                error = e.toString().replaceFirst('Exception: ', '');
                                              });
                                            }
                                          },
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      backgroundColor: AppConstants.primaryColor,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: loading
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Text('Crear'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _unlinkDevice(AppUser user) async {
    final session = Provider.of<SessionProvider>(context, listen: false);
    await _authService.unlinkDevice(kioscoId: session.kioscoId!, uid: user.uid);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dispositivo de ${user.displayName ?? user.usuario} desvinculado')),
      );
    }
  }

  Future<void> _editPermissions(AppUser user) async {
    final session = Provider.of<SessionProvider>(context, listen: false);
    final kioscoId = session.kioscoId!;

    final current = <Permission, bool>{
      for (final p in Permission.values) p: user.hasPermission(p),
    };

    final updated = await showDialog<Map<Permission, bool>>(
      context: context,
      builder: (context) {
        final working = Map<Permission, bool>.of(current);
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
                child: GlassContainer(
                  borderRadius: BorderRadius.circular(24),
                  blur: 26,
                  padding: EdgeInsets.zero,
                  child: Material(
                    type: MaterialType.transparency,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                          child: Row(
                            children: [
                              const Icon(Icons.tune, color: AppConstants.primaryColor),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Permisos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    Text(
                                      user.displayName ?? user.usuario,
                                      style: TextStyle(fontSize: 12.5, color: context.colors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            children: Permission.values.map((p) {
                              return CheckboxListTile(
                                value: working[p] ?? false,
                                onChanged: (v) => setStateDialog(() => working[p] = v ?? false),
                                title: Text(p.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                subtitle: Text(p.description, style: const TextStyle(fontSize: 12)),
                                controlAffinity: ListTileControlAffinity.leading,
                                activeColor: AppConstants.primaryColor,
                              );
                            }).toList(),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text('Cancelar'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () => Navigator.pop(context, working),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppConstants.primaryColor,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text('Guardar'),
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
          },
        );
      },
    );

    if (updated == null) return;
    await _authService.updateEmployeePermissions(kioscoId: kioscoId, uid: user.uid, permissions: updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Permisos de ${user.displayName ?? user.usuario} actualizados'),
          backgroundColor: AppConstants.successColor,
        ),
      );
    }
  }

  Future<void> _deleteEmployee(AppUser user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar empleado'),
        content: Text('¿Eliminar el acceso de ${user.displayName ?? user.usuario}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppConstants.errorColor),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final session = Provider.of<SessionProvider>(context, listen: false);
      await _authService.deleteEmployee(kioscoId: session.kioscoId!, uid: user.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = Provider.of<SessionProvider>(context);
    final kioscoId = session.kioscoId!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de administración'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: session.hasPermission(Permission.gestionarEmpleados)
          ? FloatingActionButton(
              onPressed: _showCreateEmployeeDialog,
              backgroundColor: AppConstants.primaryColor,
              child: const Icon(Icons.person_add),
            )
          : null,
      body: StreamBuilder<List<AppUser>>(
        stream: _authService.watchEmployees(kioscoId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final users = snapshot.data!;
          if (users.isEmpty) {
            return const Center(child: Text('No hay usuarios todavía'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassContainer(
                  borderRadius: BorderRadius.circular(16),
                  blur: 12,
                  enableBlur: false,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppConstants.primaryColor.withOpacity(0.15),
                        child: Icon(
                          user.isAdmin ? Icons.admin_panel_settings : Icons.person,
                          color: AppConstants.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName ?? user.usuario,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            Text(
                              user.isAdmin ? 'Administrador' : 'Empleado',
                              style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
                            ),
                            Text(
                              user.hasDeviceLinked
                                  ? 'Dispositivo vinculado'
                                  : 'Sin dispositivo vinculado',
                              style: TextStyle(
                                color: user.hasDeviceLinked ? AppConstants.successColor : AppConstants.warningColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!user.isAdmin && session.hasPermission(Permission.gestionarEmpleados))
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'permissions') _editPermissions(user);
                            if (value == 'unlink') _unlinkDevice(user);
                            if (value == 'delete') _deleteEmployee(user);
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'permissions', child: Text('Editar permisos')),
                            if (user.hasDeviceLinked)
                              const PopupMenuItem(value: 'unlink', child: Text('Desvincular dispositivo')),
                            const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
