import '../utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';
import '../providers/session_provider.dart';
import '../services/mercadopago_service.dart';
import '../services/backup_service.dart';
import '../utils/constants.dart';
import '../utils/security_helper.dart';
import '../widgets/glass_container.dart';
import 'dart:io';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _mpTokenController = TextEditingController();
  bool _mpEnabled = false;
  bool _isLoading = true;
  bool _autoBackupEnabled = false;
  bool _stockAlertsEnabled = true;
  bool _priceHistoryEnabled = true;
  int _lowStockThreshold = 5;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _mpTokenController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      setState(() => _isLoading = true);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      
      // Mercado Pago
      final mpEnabled = prefs.getBool('mp_enabled') ?? false;
      final mpToken = prefs.getString('mp_token') ?? '';
      
      // Otras configuraciones
      final autoBackup = prefs.getBool('auto_backup_enabled') ?? false;
      final stockAlerts = prefs.getBool('stock_alerts_enabled') ?? true;
      final priceHistory = prefs.getBool('price_history_enabled') ?? true;
      final threshold = prefs.getInt('low_stock_threshold') ?? 5;
      
      debugLog('📥 Cargando configuración...');

      String decryptedToken = '';
      if (mpToken.isNotEmpty) {
        try {
          decryptedToken = await SecurityHelper.decrypt(mpToken);
        } catch (e) {
          debugLog('Error desencriptando token: $e');
          decryptedToken = '';
        }
      }

      setState(() {
        _mpEnabled = mpEnabled;
        _mpTokenController.text = decryptedToken;
        _autoBackupEnabled = autoBackup;
        _stockAlertsEnabled = stockAlerts;
        _priceHistoryEnabled = priceHistory;
        _lowStockThreshold = threshold;
        _isLoading = false;
      });
      
      await MercadoPagoService.debugPrintConfig();
    } catch (e) {
      debugLog('❌ Error cargando configuración: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveMercadoPagoSettings() async {
    try {
      final token = _mpTokenController.text.trim();
      
      debugLog('\n🔄 Guardando configuración...');
      debugLog('Token ingresado: ${token.isNotEmpty ? "${token.length} chars" : "VACÍO"}');
      
      if (token.isNotEmpty && !token.startsWith('APP_USR') && !token.startsWith('TEST')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ El token debe empezar con APP_USR o TEST'),
              backgroundColor: AppConstants.errorColor,
            ),
          );
        }
        return;
      }
      
      // Mostrar loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Guardando...'),
            ],
          ),
        ),
      );
      
      // Guardar
      final success = await MercadoPagoService.saveConfiguration(
        enabled: _mpEnabled,
        accessToken: token.isNotEmpty ? token : null,
      );
      
      // Cerrar loading
      if (mounted) Navigator.pop(context);
      
      // Mostrar resultado
      if (mounted) {
        if (success) {
          await MercadoPagoService.debugPrintConfig();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Configuración guardada exitosamente'),
              backgroundColor: AppConstants.successColor,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Error al guardar. Revisa la consola.'),
              backgroundColor: AppConstants.errorColor,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      debugLog('❌ Excepción: $e');
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _saveGeneralSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auto_backup_enabled', _autoBackupEnabled);
      await prefs.setBool('stock_alerts_enabled', _stockAlertsEnabled);
      await prefs.setBool('price_history_enabled', _priceHistoryEnabled);
      await prefs.setInt('low_stock_threshold', _lowStockThreshold);
      await prefs.commit();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Configuración guardada'),
            backgroundColor: AppConstants.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugLog('Error guardando configuración general: $e');
    }
  }

  Future<void> _enableTestMode() async {
    try {
      setState(() => _mpEnabled = true);
      
      final success = await MercadoPagoService.saveConfiguration(enabled: true);
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Modo prueba activado'),
              backgroundColor: AppConstants.successColor,
            ),
          );
          await MercadoPagoService.debugPrintConfig();
        }
      }
    } catch (e) {
      debugLog('Error: $e');
    }
  }

  Future<void> _createBackup() async {
    try {
      // Mostrar opciones
      final option = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Tipo de Backup'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.code, color: AppConstants.primaryColor),
                title: const Text('JSON'),
                subtitle: const Text('Backup completo (para restaurar)'),
                onTap: () => Navigator.pop(context, 'json'),
              ),
              ListTile(
                leading: const Icon(Icons.table_chart, color: AppConstants.successColor),
                title: const Text('Excel (CSV)'),
                subtitle: const Text('Para abrir en Excel'),
                onTap: () => Navigator.pop(context, 'csv'),
              ),
            ],
          ),
        ),
      );

      if (option == null) return;

      if (!mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      
      final kioscoId = context.read<SessionProvider>().kioscoId;
      if (kioscoId == null) return;

      File? result;
      if (option == 'json') {
        result = await BackupService.createBackup(kioscoId);
      } else {
        result = await BackupService.createExcelBackup(kioscoId);
      }
      
      if (mounted) Navigator.pop(context);
      
      if (result != null && mounted) {
        final fileName = result.path.split('/').last;
        final filePath = result.path; // Guardar en variable local
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Backup creado: $fileName'),
            backgroundColor: AppConstants.successColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Compartir',
              textColor: Colors.white,
              onPressed: () => BackupService.shareBackup(filePath),
            ),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Error al crear backup'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    } catch (e) {
      debugLog('Error en backup: $e');
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    }
  }

  void _showMercadoPagoHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: AppConstants.primaryColor),
            SizedBox(width: 12),
            Expanded(child: Text('Cómo obtener tu Access Token')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Sigue estos pasos:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildHelpStep('1', 'Ingresa a tu cuenta de Mercado Pago'),
              _buildHelpStep('2', 'Ve a "Tu negocio" → "Configuración"'),
              _buildHelpStep('3', 'Selecciona "Gestión y Administración"'),
              _buildHelpStep('4', 'Haz clic en "Credenciales"'),
              _buildHelpStep('5', 'Copia tu "Access Token de producción"'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppConstants.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '🔒 Tu token se guarda encriptado de forma segura',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: AppConstants.primaryColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(number, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (_isLoading) {
      return GlassBackground(
        child: const Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return GlassBackground(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Configuración', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 10),

          // Apariencia
          _SectionHeader('Apariencia', Icons.palette),
          GlassContainer(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            borderRadius: BorderRadius.circular(18),
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Modo Oscuro'),
                  subtitle: Text(themeProvider.isDarkMode ? 'Activado' : 'Desactivado'),
                  secondary: Icon(themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode, color: AppConstants.primaryColor),
                  value: themeProvider.isDarkMode,
                  onChanged: (value) => themeProvider.toggleTheme(),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.format_size, color: AppConstants.primaryColor),
                  title: const Text('Tamaño de Fuente'),
                  subtitle: Text(_getFontSizeLabel(themeProvider.fontSize)),
                  trailing: SizedBox(
                    width: 150,
                    child: Slider(
                      value: themeProvider.fontSize,
                      min: 0.8,
                      max: 1.4,
                      divisions: 6,
                      label: _getFontSizeLabel(themeProvider.fontSize),
                      onChanged: (value) => themeProvider.setFontSize(value),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Inventario
          _SectionHeader('Inventario', Icons.inventory_2),
          GlassContainer(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            borderRadius: BorderRadius.circular(18),
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Alertas de Stock'),
                  subtitle: const Text('Notificaciones cuando el stock es bajo'),
                  secondary: const Icon(Icons.notifications, color: AppConstants.warningColor),
                  value: _stockAlertsEnabled,
                  onChanged: (value) {
                    setState(() => _stockAlertsEnabled = value);
                    _saveGeneralSettings();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.warning_amber, color: AppConstants.warningColor),
                  title: const Text('Umbral de Stock Bajo'),
                  subtitle: Text('Alertar cuando queden $_lowStockThreshold unidades'),
                  trailing: SizedBox(
                    width: 150,
                    child: Slider(
                      value: _lowStockThreshold.toDouble(),
                      min: 1,
                      max: 20,
                      divisions: 19,
                      label: _lowStockThreshold.toString(),
                      onChanged: (value) {
                        setState(() => _lowStockThreshold = value.toInt());
                        _saveGeneralSettings();
                      },
                    ),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Historial de Precios'),
                  subtitle: const Text('Guardar cambios de precio'),
                  secondary: const Icon(Icons.history, color: AppConstants.primaryColor),
                  value: _priceHistoryEnabled,
                  onChanged: (value) {
                    setState(() => _priceHistoryEnabled = value);
                    _saveGeneralSettings();
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Backup
          _SectionHeader('Respaldo de Datos', Icons.backup),
          GlassContainer(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            borderRadius: BorderRadius.circular(18),
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Backup Automático'),
                  subtitle: const Text('Respaldar datos diariamente'),
                  secondary: const Icon(Icons.backup, color: AppConstants.successColor),
                  value: _autoBackupEnabled,
                  onChanged: (value) {
                    setState(() => _autoBackupEnabled = value);
                    _saveGeneralSettings();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.download, color: AppConstants.primaryColor),
                  title: const Text('Crear Backup Ahora'),
                  subtitle: const Text('Exportar datos a JSON o CSV'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _createBackup,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Mercado Pago
          _SectionHeader('Mercado Pago', Icons.payment),
          GlassContainer(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            borderRadius: BorderRadius.circular(18),
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Habilitar Mercado Pago'),
                  subtitle: Text(_mpEnabled ? 'Pagos con QR habilitados' : 'Deshabilitado'),
                  secondary: const Icon(Icons.qr_code_2, color: Color(0xFF009EE3)),
                  value: _mpEnabled,
                  onChanged: (value) async {
                    setState(() => _mpEnabled = value);
                    await _saveMercadoPagoSettings();
                  },
                ),
                if (!_mpEnabled) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _enableTestMode,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF009EE3),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.science),
                        label: const Text('Activar Modo Prueba'),
                      ),
                    ),
                  ),
                ],
                if (_mpEnabled) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Access Token (Opcional)',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _showMercadoPagoHelp,
                              icon: const Icon(Icons.help_outline, size: 18),
                              label: const Text('Ayuda', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _mpTokenController,
                          decoration: InputDecoration(
                            hintText: 'APP_USR-XXXXXXXXXXXXXXXXXX',
                            helperText: 'Se guarda encriptado 🔒',
                            helperStyle: const TextStyle(fontSize: 11, color: AppConstants.successColor),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.key),
                            suffixIcon: _mpTokenController.text.isNotEmpty
                                ? const Icon(Icons.check_circle, color: AppConstants.successColor)
                                : null,
                          ),
                          obscureText: true,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _mpTokenController.text.isNotEmpty ? _saveMercadoPagoSettings : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF009EE3),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.save),
                            label: const Text('Guardar Token'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Debug
          if (_mpEnabled) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                onPressed: () async {
                  await MercadoPagoService.debugPrintConfig();
                  final info = await MercadoPagoService.getDebugInfo();
                  if (mounted) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('🔍 Debug Info'),
                        content: SingleChildScrollView(
                          child: Text(
                            info.entries.map((e) => '${e.key}: ${e.value}').join('\n\n'),
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cerrar'),
                          ),
                        ],
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.bug_report),
                label: const Text('Ver Debug Info'),
              ),
            ),
          ],
          
          const SizedBox(height: 20),
          
          // Acerca de
          _SectionHeader('Acerca de', Icons.info_outline),
          GlassContainer(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            borderRadius: BorderRadius.circular(18),
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.store, color: AppConstants.primaryColor),
                  ),
                  title: const Text('Kioske.AR'),
                  subtitle: const Text('Versión 1.0.0'),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.person, color: AppConstants.primaryColor),
                  title: Text('Desarrollado por'),
                  subtitle: Text('Federico Villares'),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.code, color: AppConstants.primaryColor),
                  title: Text('Tecnología'),
                  subtitle: Text('Flutter 3.16+ • AES-256'),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.security, color: AppConstants.successColor),
                  title: Text('Seguridad'),
                  subtitle: Text('Datos encriptados localmente'),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
        ],
      ),
      ),
    );
  }

  String _getFontSizeLabel(double size) {
    if (size <= 0.8) return 'Muy pequeño';
    if (size <= 0.9) return 'Pequeño';
    if (size <= 1.0) return 'Normal';
    if (size <= 1.1) return 'Mediano';
    if (size <= 1.2) return 'Grande';
    return 'Muy grande';
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader(this.title, this.icon);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppConstants.primaryColor),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppConstants.primaryColor)),
        ],
      ),
    );
  }
}