import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/session_provider.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/glass_container.dart';
import 'kiosco_support_page.dart';
import 'login_page.dart';

/// Vista global exclusiva del superadmin (Fernando): lista todos los
/// kioscos que existen en la plataforma, sin necesidad de pertenecer a
/// ninguno. Pensada como punto de partida para soporte y control general
/// (cuántos kioscos hay, cuándo se crearon), no para operar el día a día
/// de cada uno — eso sigue siendo responsabilidad del admin de cada kiosco.
class SuperAdminPage extends StatefulWidget {
  const SuperAdminPage({Key? key}) : super(key: key);

  @override
  State<SuperAdminPage> createState() => _SuperAdminPageState();
}

class _SuperAdminPageState extends State<SuperAdminPage> {
  void _showCreateKioscoDialog() {
    final formKey = GlobalKey<FormState>();
    final nombreController = TextEditingController();
    final kioscoIdController = TextEditingController();
    final usuarioController = TextEditingController();
    final passwordController = TextEditingController();
    bool obscure = true;
    bool loading = false;
    String? error;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setStateDialog) {
            Future<void> submit() async {
              if (!formKey.currentState!.validate()) return;
              setStateDialog(() {
                loading = true;
                error = null;
              });
              try {
                final session = Provider.of<SessionProvider>(context, listen: false);
                await session.createKioscoAsSuperAdmin(
                  kioscoId: kioscoIdController.text.trim(),
                  kioscoNombre: nombreController.text.trim(),
                  usuario: usuarioController.text.trim(),
                  password: passwordController.text,
                );
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Kiosco "${nombreController.text.trim()}" creado correctamente')),
                  );
                }
              } catch (e) {
                setStateDialog(() {
                  loading = false;
                  error = e.toString().replaceFirst('Exception: ', '');
                });
              }
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: GlassContainer(
                  borderRadius: BorderRadius.circular(24),
                  blur: 26,
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.add_business, color: AppConstants.primaryColor),
                              SizedBox(width: 10),
                              Text('Crear nuevo kiosco', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Como super admin, precreás el kiosco y su usuario administrador. Después le pasás esas credenciales al dueño del kiosco.',
                            style: TextStyle(fontSize: 12.5, color: Colors.black54, height: 1.4),
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            controller: nombreController,
                            decoration: InputDecoration(
                              labelText: 'Nombre del kiosco',
                              prefixIcon: const Icon(Icons.storefront),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresá un nombre' : null,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: kioscoIdController,
                            decoration: InputDecoration(
                              labelText: 'Código de kiosco',
                              hintText: 'identificador único, ej: kiosco-juan',
                              prefixIcon: const Icon(Icons.tag),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresá un código' : null,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: usuarioController,
                            decoration: InputDecoration(
                              labelText: 'Usuario admin',
                              prefixIcon: const Icon(Icons.person),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresá un usuario' : null,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: passwordController,
                            obscureText: obscure,
                            decoration: InputDecoration(
                              labelText: 'Contraseña admin',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                                onPressed: () => setStateDialog(() => obscure = !obscure),
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                            onFieldSubmitted: (_) => submit(),
                          ),
                          if (error != null) ...[
                            const SizedBox(height: 14),
                            Text(error!, style: const TextStyle(color: AppConstants.errorColor, fontSize: 13)),
                          ],
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: loading ? null : () => Navigator.pop(dialogContext),
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
                                  onPressed: loading ? null : submit,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppConstants.primaryColor,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
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
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Panel Super Admin'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              final session = context.read<SessionProvider>();
              await session.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateKioscoDialog,
        icon: const Icon(Icons.add_business),
        label: const Text('Crear kiosco'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: authService.watchAllKioscos(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final kioscos = snapshot.data!;
          if (kioscos.isEmpty) {
            return const Center(child: Text('Todavía no hay kioscos registrados'));
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: GlassContainer(
                  borderRadius: BorderRadius.circular(16),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.store, color: AppConstants.primaryColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${kioscos.length} ${kioscos.length == 1 ? 'kiosco registrado' : 'kioscos registrados'} en la plataforma',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  itemCount: kioscos.length,
                  itemBuilder: (context, index) {
                    final k = kioscos[index];
                    DateTime? createdAt;
                    final rawDate = k['createdAt'];
                    if (rawDate is String) createdAt = DateTime.tryParse(rawDate);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassContainer(
                        borderRadius: BorderRadius.circular(16),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppConstants.secondaryColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.storefront, color: AppConstants.secondaryColor),
                          ),
                          title: Text(
                            k['nombre'] ?? k['id'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Código: ${k['id']}'
                            '${createdAt != null ? ' · creado ${Helpers.formatDate(createdAt)}' : ''}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => KioscoSupportPage(
                                kioscoId: k['id'],
                                kioscoNombre: k['nombre'] ?? k['id'],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
