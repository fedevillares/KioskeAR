import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/session_provider.dart';
import '../utils/constants.dart';
import '../widgets/glass_container.dart';
import 'app_shell.dart';

/// Pantalla de configuración inicial: se usa UNA sola vez por kiosco,
/// para crear la empresa y su cuenta de administrador. No es un modo
/// del login normal — se llega acá solo desde un acceso discreto en
/// LoginPage, pensado para el dueño del kiosco, no para empleados.
class SetupKioscoPage extends StatefulWidget {
  const SetupKioscoPage({Key? key}) : super(key: key);

  @override
  State<SetupKioscoPage> createState() => _SetupKioscoPageState();
}

class _SetupKioscoPageState extends State<SetupKioscoPage> {
  final _formKey = GlobalKey<FormState>();
  final _kioscoController = TextEditingController();
  final _kioscoNombreController = TextEditingController();
  final _usuarioController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _kioscoController.dispose();
    _kioscoNombreController.dispose();
    _usuarioController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final session = Provider.of<SessionProvider>(context, listen: false);

    try {
      await session.registerKioscoAndAdmin(
        kioscoId: _kioscoController.text.trim(),
        kioscoNombre: _kioscoNombreController.text.trim(),
        usuario: _usuarioController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AppShell()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppConstants.primaryColor, AppConstants.secondaryColor],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: GlassContainer(
                        borderRadius: BorderRadius.circular(28),
                        blur: 26,
                        padding: const EdgeInsets.all(28),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppConstants.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.add_business,
                                  color: AppConstants.primaryColor,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Configurar tu kiosco',
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Esto se hace una sola vez. Vas a quedar como\nadministrador y desde ahí creás el resto de los usuarios.',
                                style: TextStyle(fontSize: 13.5, color: context.colors.textSecondary, height: 1.4),
                              ),
                              const SizedBox(height: 28),
                              TextFormField(
                                controller: _kioscoNombreController,
                                decoration: InputDecoration(
                                  labelText: 'Nombre del kiosco',
                                  hintText: 'ej: Kiosco Don José',
                                  prefixIcon: const Icon(Icons.storefront),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresá un nombre' : null,
                                textInputAction: TextInputAction.next,
                                textCapitalization: TextCapitalization.words,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _kioscoController,
                                decoration: InputDecoration(
                                  labelText: 'Código de kiosco',
                                  hintText: 'ej: don-jose',
                                  helperText: 'Este código lo van a usar tus empleados para entrar',
                                  prefixIcon: const Icon(Icons.tag),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty) ? 'Ingresá un código' : null,
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _usuarioController,
                                decoration: InputDecoration(
                                  labelText: 'Tu usuario (admin)',
                                  prefixIcon: const Icon(Icons.person),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty) ? 'Ingresá un usuario' : null,
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  labelText: 'Contraseña',
                                  prefixIcon: const Icon(Icons.lock),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                validator: (v) =>
                                    (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                                onFieldSubmitted: (_) => _submit(),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppConstants.errorColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline, color: AppConstants.errorColor, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(_error!, style: const TextStyle(color: AppConstants.errorColor)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 28),
                              FilledButton(
                                onPressed: _loading ? null : _submit,
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: AppConstants.primaryColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: _loading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Text('Crear kiosco'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
