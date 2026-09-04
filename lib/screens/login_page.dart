import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/session_provider.dart';
import '../utils/constants.dart';
import '../widgets/glass_container.dart';
import 'app_shell.dart';
import 'superadmin_page.dart';

/// Pantalla de inicio de sesión. Hay exactamente dos formas de entrar, y
/// ambas están identificadas con texto (no íconos sueltos): "Kiosco" para
/// admins/empleados que ya fueron creados por el super admin, y "Super
/// admin" para Fernando. No existe ningún flujo de autoregistro público:
/// los kioscos y sus admins los precrea el super admin desde su panel
/// (ver SuperAdminPage), nunca el usuario final desde acá.
class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

enum _LoginMode { kiosco, superAdmin }

class _LoginPageState extends State<LoginPage> {
  _LoginMode _mode = _LoginMode.kiosco;

  final _formKey = GlobalKey<FormState>();
  final _kioscoController = TextEditingController();
  final _usuarioController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _kioscoController.dispose();
    _usuarioController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _switchMode(_LoginMode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _error = null;
      _kioscoController.clear();
      _usuarioController.clear();
      _passwordController.clear();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final session = Provider.of<SessionProvider>(context, listen: false);

    try {
      if (_mode == _LoginMode.superAdmin) {
        await session.loginSuperAdmin(
          email: _usuarioController.text.trim(),
          password: _passwordController.text,
        );
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const SuperAdminPage()),
            (route) => false,
          );
        }
      } else {
        await session.login(
          kioscoId: _kioscoController.text.trim(),
          usuario: _usuarioController.text.trim(),
          password: _passwordController.text,
        );
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AppShell()),
            (route) => false,
          );
        }
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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Branding arriba de la tarjeta, fuera del glass,
                    // para separar identidad de marca del formulario.
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
                      ),
                      child: const Icon(Icons.store, color: Colors.white, size: 38),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Kioske.AR',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Iniciá sesión para continuar',
                      style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.85)),
                    ),
                    const SizedBox(height: 24),

                    // Selector de tipo de cuenta: dos opciones con texto
                    // explícito, no íconos sueltos. Resuelve la confusión
                    // de "no sé cuál es cuál" que había con los accesos
                    // discretos anteriores.
                    GlassContainer(
                      borderRadius: BorderRadius.circular(16),
                      blur: 20,
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Expanded(
                            child: _ModeButton(
                              label: 'Kiosco',
                              icon: Icons.storefront,
                              selected: _mode == _LoginMode.kiosco,
                              onTap: () => _switchMode(_LoginMode.kiosco),
                            ),
                          ),
                          Expanded(
                            child: _ModeButton(
                              label: 'Super admin',
                              icon: Icons.admin_panel_settings,
                              selected: _mode == _LoginMode.superAdmin,
                              onTap: () => _switchMode(_LoginMode.superAdmin),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    GlassContainer(
                      borderRadius: BorderRadius.circular(28),
                      blur: 26,
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _mode == _LoginMode.superAdmin
                                  ? 'Acceso exclusivo de Fernando como super administrador de la plataforma.'
                                  : 'Para empleados y administradores de un kiosco ya creado. Si todavía no tenés cuenta, pedile al super admin que te la cree.',
                              style: TextStyle(fontSize: 12.5, color: context.colors.textSecondary, height: 1.4),
                            ),
                            const SizedBox(height: 18),
                            if (_mode == _LoginMode.kiosco) ...[
                              TextFormField(
                                controller: _kioscoController,
                                decoration: InputDecoration(
                                  labelText: 'Kiosco',
                                  hintText: 'Código de tu kiosco',
                                  prefixIcon: const Icon(Icons.storefront),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty) ? 'Ingresá el código de kiosco' : null,
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _usuarioController,
                                decoration: InputDecoration(
                                  labelText: 'Usuario',
                                  prefixIcon: const Icon(Icons.person),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty) ? 'Ingresá tu usuario' : null,
                                textInputAction: TextInputAction.next,
                              ),
                            ] else
                              TextFormField(
                                controller: _usuarioController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  hintText: 'tu email de super admin',
                                  prefixIcon: const Icon(Icons.email_outlined),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty) ? 'Ingresá tu email' : null,
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
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: _loading ? null : _submit,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: _mode == _LoginMode.superAdmin
                                    ? AppConstants.secondaryColor
                                    : AppConstants.primaryColor,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Ingresar', style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: AppConstants.fastAnimation,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withOpacity(0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
