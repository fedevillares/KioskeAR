import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

/// Obtiene un identificador estable del dispositivo físico para
/// vincular cuentas de empleados a un único celular.
class DeviceService {
  static Future<String> getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        return info.id.isNotEmpty ? info.id : info.fingerprint;
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        return info.identifierForVendor ?? 'ios-unknown';
      }
    } catch (_) {
      // fallback abajo
    }
    return 'device-unknown';
  }
}
