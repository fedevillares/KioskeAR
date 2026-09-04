import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import '../widgets/glass_container.dart';

/// Detalle de soporte de un kiosco puntual, visible solo para el
/// superadmin. Muestra lo que realmente vive en Firestore (equipo de
/// usuarios y estado de sus vínculos de dispositivo) — el inventario y las
/// ventas son locales al dispositivo del kiosquero y no son visibles desde
/// acá (ver nota en AuthService.getKioscoSupportInfo).
class KioscoSupportPage extends StatefulWidget {
  final String kioscoId;
  final String kioscoNombre;

  const KioscoSupportPage({Key? key, required this.kioscoId, required this.kioscoNombre}) : super(key: key);

  @override
  State<KioscoSupportPage> createState() => _KioscoSupportPageState();
}

class _KioscoSupportPageState extends State<KioscoSupportPage> {
  final _authService = AuthService();
  Map<String, dynamic>? _info;
  bool _isLoading = true;
  bool _unlinking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final info = await _authService.getKioscoSupportInfo(widget.kioscoId);
    if (mounted) {
      setState(() {
        _info = info;
        _isLoading = false;
      });
    }
  }

  Future<void> _unlinkAdminDevice() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Desvincular dispositivo del admin'),
        content: const Text(
          'El admin de este kiosco va a poder iniciar sesión desde un celular nuevo. '
          'Usá esto solo si perdió o cambió de equipo y no hay nadie más con acceso para desvincularlo.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppConstants.warningColor),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desvincular'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _unlinking = true);
    try {
      await _authService.unlinkKioscoAdminDevice(widget.kioscoId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dispositivo del admin desvinculado'), backgroundColor: AppConstants.successColor),
        );
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _unlinking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(widget.kioscoNombre),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GlassContainer(
                  borderRadius: BorderRadius.circular(18),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.groups, color: AppConstants.primaryColor),
                          SizedBox(width: 10),
                          Text('Equipo del kiosco', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _InfoRow('Usuarios totales', '${_info?['totalUsers'] ?? 0}'),
                      _InfoRow('Empleados', '${_info?['employeeCount'] ?? 0}'),
                      _InfoRow('Empleados sin dispositivo vinculado', '${_info?['employeesWithoutDevice'] ?? 0}'),
                      _InfoRow(
                        'Admin con dispositivo vinculado',
                        (_info?['adminHasDeviceLinked'] == true) ? 'Sí' : 'No',
                        valueColor: (_info?['adminHasDeviceLinked'] == true)
                            ? AppConstants.successColor
                            : AppConstants.warningColor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (_info?['admin'] != null) ...[
                  GlassContainer(
                    borderRadius: BorderRadius.circular(18),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.support_agent, color: AppConstants.warningColor),
                            SizedBox(width: 10),
                            Text('Acciones de soporte', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Admin: ${(_info?['admin'] as AppUser).displayName ?? (_info?['admin'] as AppUser).usuario}',
                          style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _unlinking ? null : _unlinkAdminDevice,
                            icon: _unlinking
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.phonelink_erase),
                            label: const Text('Desvincular dispositivo del admin'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppConstants.warningColor,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryColor.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 18, color: AppConstants.primaryColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'El inventario y las ventas de este kiosco se guardan localmente en el celular del kiosquero, '
                          'no en la nube — por diseño, no son visibles desde este panel.',
                          style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 13.5, color: context.colors.textSecondary))),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: valueColor)),
        ],
      ),
    );
  }
}
