import 'dart:convert';
import 'dart:math';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Maneja cifrado simétrico (AES-256) y validaciones de entrada.
///
/// SEGURIDAD: la clave NUNCA está escrita en el código fuente. Antes había
/// una clave fija de 32 bytes hardcodeada acá mismo — cualquiera que
/// descompilara el APK (proceso de minutos con herramientas gratuitas como
/// jadx) la obtenía íntegra, lo que invalida cualquier garantía de
/// confidencialidad o de integridad forense de los datos cifrados con ella.
///
/// Ahora la clave se genera una sola vez por instalación con un generador
/// criptográficamente seguro (Random.secure) y se guarda en el almacenamiento
/// seguro nativo del sistema operativo:
/// - Android: Keystore (respaldado por hardware en la mayoría de equipos).
/// - iOS: Keychain.
///
/// Ese almacenamiento no es legible por otras apps ni accesible extrayendo
/// el APK/IPA; solo se puede leer en tiempo de ejecución desde la propia app
/// y, en Android, autenticado contra el Keystore del dispositivo. Esto eleva
/// el cifrado de "ofuscación cosmética" a una protección real contra acceso
/// no autorizado a los datos en reposo.
class SecurityHelper {
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _keyStorageKey = 'kioskear_aes_key_v1';
  static const _ivStorageKey = 'kioskear_aes_iv_v1';

  static Encrypter? _encrypterCache;
  static IV? _ivCache;

  /// Genera bytes aleatorios criptográficamente seguros en base64.
  static String _generateRandomBase64(int byteLength) {
    final random = Random.secure();
    final bytes = List<int>.generate(byteLength, (_) => random.nextInt(256));
    return base64.encode(bytes);
  }

  /// Obtiene (o crea, si es la primera vez) la clave AES-256 y el IV de
  /// esta instalación, y prepara el Encrypter. Se cachea en memoria para
  /// no golpear el almacenamiento seguro en cada operación.
  static Future<Encrypter> _getEncrypter() async {
    if (_encrypterCache != null) return _encrypterCache!;

    var keyB64 = await _secureStorage.read(key: _keyStorageKey);
    var ivB64 = await _secureStorage.read(key: _ivStorageKey);

    if (keyB64 == null || ivB64 == null) {
      // Primera vez que se usa el cifrado en este dispositivo: generamos
      // una clave e IV nuevos, únicos para esta instalación.
      keyB64 = _generateRandomBase64(32); // AES-256 = 32 bytes de clave
      ivB64 = _generateRandomBase64(16); // bloque AES = 16 bytes de IV
      await _secureStorage.write(key: _keyStorageKey, value: keyB64);
      await _secureStorage.write(key: _ivStorageKey, value: ivB64);
    }

    final key = Key(base64.decode(keyB64));
    _ivCache = IV(base64.decode(ivB64));
    _encrypterCache = Encrypter(AES(key, mode: AESMode.cbc));
    return _encrypterCache!;
  }

  static Future<String> encrypt(String plainText) async {
    if (plainText.isEmpty) return '';
    try {
      final encrypter = await _getEncrypter();
      final encrypted = encrypter.encrypt(plainText, iv: _ivCache!);
      return encrypted.base64;
    } catch (e) {
      // No hacemos fallback silencioso a texto plano: si el cifrado falla,
      // quien llama necesita saberlo explícitamente para no guardar datos
      // sensibles sin proteger por error.
      throw SecurityException('No se pudo cifrar el contenido: $e');
    }
  }

  static Future<String> decrypt(String encryptedText) async {
    if (encryptedText.isEmpty) return '';
    try {
      final encrypter = await _getEncrypter();
      final encrypted = Encrypted.fromBase64(encryptedText);
      return encrypter.decrypt(encrypted, iv: _ivCache!);
    } catch (e) {
      throw SecurityException('No se pudo descifrar el contenido: $e');
    }
  }

  /// Borra la clave de cifrado del dispositivo (p. ej. al cerrar sesión
  /// definitivamente o desinstalar datos). Los datos cifrados con la clave
  /// anterior quedan irrecuperables a propósito.
  static Future<void> wipeEncryptionKey() async {
    await _secureStorage.delete(key: _keyStorageKey);
    await _secureStorage.delete(key: _ivStorageKey);
    _encrypterCache = null;
    _ivCache = null;
  }

  static String? validateInput(String? value, {int minLength = 1, int maxLength = 100}) {
    if (value == null || value.trim().isEmpty) {
      return 'Este campo es requerido';
    }
    if (value.trim().length < minLength) {
      return 'Mínimo $minLength caracteres';
    }
    if (value.trim().length > maxLength) {
      return 'Máximo $maxLength caracteres';
    }
    return null;
  }

  static String sanitizeInput(String input) {
    return input
        .trim()
        .replaceAll(RegExp(r'[<>"`]'), '')
        .replaceAll(RegExp(r"[']"), '')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static String? validateNumber(String? value, {double? min, double? max}) {
    if (value == null || value.trim().isEmpty) {
      return 'Este campo es requerido';
    }
    final number = double.tryParse(value);
    if (number == null) {
      return 'Ingrese un número válido';
    }
    if (min != null && number < min) {
      return 'Mínimo: $min';
    }
    if (max != null && number > max) {
      return 'Máximo: $max';
    }
    return null;
  }

  static String? validatePrice(String? value) {
    return validateNumber(value, min: 0, max: 999999);
  }

  static String? validateStock(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El stock es requerido';
    }
    final stock = int.tryParse(value);
    if (stock == null || stock < 0) {
      return 'Ingrese un stock válido';
    }
    return null;
  }

  static String? validateProductName(String? value) {
    return validateInput(value, minLength: 2, maxLength: 50);
  }

  static bool validateMercadoPagoToken(String token) {
    final trimmed = token.trim();
    return trimmed.startsWith('APP_USR') || trimmed.startsWith('TEST');
  }
}

class SecurityException implements Exception {
  final String message;
  SecurityException(this.message);
  @override
  String toString() => message;
}
