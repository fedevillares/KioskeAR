import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cart_item.dart';
import '../utils/security_helper.dart';

class MercadoPagoService {
  static const String _baseUrl = 'https://api.mercadopago.com';
  static const int _timeoutSeconds = 15;
  
  static Future<bool> isEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('mp_enabled') ?? false;
    } catch (e) {
      print('Error verificando enabled: $e');
      return false;
    }
  }

  static Future<String?> getAccessToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final enabled = prefs.getBool('mp_enabled') ?? false;
      if (!enabled) {
        print('MercadoPago deshabilitado');
        return null;
      }
      
      final token = prefs.getString('mp_token');
      if (token == null || token.isEmpty) {
        print('No hay token guardado');
        return null;
      }
      
      // Intentar desencriptar
      final decrypted = await SecurityHelper.decrypt(token);
      print('✓ Token cargado: ${decrypted.substring(0, 15)}...');
      return decrypted;
    } catch (e) {
      print('Error obteniendo token: $e');
      return null;
    }
  }

  static Future<bool> saveConfiguration({
    required bool enabled,
    String? accessToken,
  }) async {
    try {
      print('═══════════════════════════════════════');
      print('GUARDANDO CONFIGURACIÓN MERCADO PAGO');
      print('Enabled: $enabled');
      print('Token: ${accessToken != null ? "SÍ (${accessToken.length} chars)" : "NO"}');
      
      final prefs = await SharedPreferences.getInstance();
      
      // Guardar enabled
      await prefs.setBool('mp_enabled', enabled);
      print('✓ Enabled guardado');
      
      // Guardar token si existe
      if (accessToken != null && accessToken.trim().isNotEmpty) {
        final cleanToken = accessToken.trim();
        
        // Validar
        if (!cleanToken.startsWith('APP_USR') && !cleanToken.startsWith('TEST')) {
          print('❌ Token inválido (debe empezar con APP_USR o TEST)');
          return false;
        }
        
        // Encriptar y guardar
        final encrypted = await SecurityHelper.encrypt(cleanToken);
        await prefs.setString('mp_token', encrypted);
        print('✓ Token guardado (encriptado: ${encrypted.length} chars)');

        // Verificar
        final verify = prefs.getString('mp_token');
        if (verify == null || verify.isEmpty) {
          print('❌ Error: Token no se guardó');
          return false;
        }

        // Verificar que se puede desencriptar
        final testDecrypt = await SecurityHelper.decrypt(verify);
        if (testDecrypt != cleanToken) {
          print('⚠️ Advertencia: Token desencriptado no coincide exactamente');
        } else {
          print('✓ Verificación OK: Token se puede leer correctamente');
        }
      }
      
      // Commit
      await prefs.commit();
      print('✓ Commit ejecutado');
      
      // Verificación final
      await prefs.reload();
      final finalEnabled = prefs.getBool('mp_enabled');
      final finalToken = prefs.getString('mp_token');
      
      print('VERIFICACIÓN FINAL:');
      print('  Enabled: $finalEnabled');
      print('  Token guardado: ${finalToken != null && finalToken.isNotEmpty}');
      
      if (finalEnabled != enabled) {
        print('❌ Error: Enabled no coincide');
        return false;
      }
      
      if (accessToken != null && accessToken.isNotEmpty) {
        if (finalToken == null || finalToken.isEmpty) {
          print('❌ Error: Token no persiste');
          return false;
        }
      }
      
      print('✅ CONFIGURACIÓN GUARDADA EXITOSAMENTE');
      print('═══════════════════════════════════════');
      return true;
    } catch (e, stack) {
      print('❌ ERROR GUARDANDO:');
      print('Error: $e');
      print('Stack: $stack');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> createPaymentQR({
    required List<CartItem> items,
    required double total,
    String? externalReference,
  }) async {
    try {
      if (items.isEmpty || total <= 0) {
        print('Carrito vacío');
        return null;
      }

      print('Creando QR de pago...');
      final accessToken = await getAccessToken();
      
      // Modo prueba
      if (accessToken == null || accessToken.isEmpty) {
        print('⚠️ Modo prueba');
        final testId = 'test_${DateTime.now().millisecondsSinceEpoch}';
        return {
          'qr_data': 'https://www.mercadopago.com.ar/checkout/test/$testId',
          'preference_id': testId,
          'sandbox_init_point': 'https://www.mercadopago.com.ar/checkout/test/$testId',
        };
      }

      final itemsList = items.map((item) => {
        'title': SecurityHelper.sanitizeInput(item.productName),
        'quantity': item.quantity,
        'unit_price': item.price,
        'currency_id': 'ARS',
      }).toList();

      final body = {
        'items': itemsList,
        'external_reference': externalReference ?? 'order_${DateTime.now().millisecondsSinceEpoch}',
        'back_urls': {
          'success': 'https://kiosco.app/success',
          'failure': 'https://kiosco.app/failure',
          'pending': 'https://kiosco.app/pending',
        },
        'auto_return': 'approved',
      };

      print('Enviando a Mercado Pago...');
      final response = await http.post(
        Uri.parse('$_baseUrl/checkout/preferences'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      ).timeout(Duration(seconds: _timeoutSeconds));

      print('Respuesta: ${response.statusCode}');

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        print('✓ QR generado');
        return {
          'qr_data': data['init_point'] ?? '',
          'preference_id': data['id'] ?? '',
          'sandbox_init_point': data['sandbox_init_point'] ?? '',
        };
      } else {
        print('Error ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error creando QR: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> getDebugInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      
      final enabled = prefs.getBool('mp_enabled') ?? false;
      final token = prefs.getString('mp_token') ?? '';
      
      String tokenInfo = 'No hay token';
      if (token.isNotEmpty) {
        try {
          final decrypted = await SecurityHelper.decrypt(token);
          tokenInfo = 'Token: ${decrypted.substring(0, 20)}... (${decrypted.length} chars)';
        } catch (e) {
          tokenInfo = 'Error: $e';
        }
      }
      
      return {
        'enabled': enabled,
        'token_status': tokenInfo,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Future<void> debugPrintConfig() async {
    final info = await getDebugInfo();
    print('═══════════════════════════════════════');
    print('DEBUG - Mercado Pago');
    info.forEach((key, value) => print('$key: $value'));
    print('═══════════════════════════════════════');
  }
}