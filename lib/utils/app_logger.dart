import 'package:flutter/foundation.dart';

/// Logging de diagnóstico que solo se emite en builds de debug.
///
/// SEGURIDAD: `print()` normal no se elimina en builds de release de
/// Flutter (solo se ofuscan nombres de símbolos con --obfuscate), así que
/// cualquier dato impreso con `print()` queda accesible en logcat/consola
/// en producción para quien tenga acceso al dispositivo (adb, SDKs de
/// terceros que leen logs, etc). `debugLog` reemplaza esos usos: el mensaje
/// nunca se construye ni se emite fuera de `kDebugMode`.
void debugLog(Object? message) {
  if (kDebugMode) {
    // ignore: avoid_print
    print(message);
  }
}
