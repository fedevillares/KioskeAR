import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_logger.dart';

/// Modelo de entrada de auditoría
class AuditLogEntry {
  final String id; // UUID
  final String action; // STOCK_CHANGE, SALE, DELETE_PRODUCT, etc.
  final String userId; // uid del usuario (o DNI si se usa para AFIP)
  final String entityId; // ID del producto/venta/cliente
  final Map<String, dynamic> oldValues; // Snapshot anterior
  final Map<String, dynamic> newValues; // Snapshot nuevo
  final DateTime timestamp;
  final String? ipAddress;
  final String? reason; // Por qué se hizo el cambio
  final String? notes;
  final String hash; // SHA-256 del contenido para detectar tampering

  AuditLogEntry({
    String? id,
    required this.action,
    required this.userId,
    required this.entityId,
    required this.oldValues,
    required this.newValues,
    DateTime? timestamp,
    this.ipAddress,
    this.reason,
    this.notes,
    String? hash,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now(),
        hash = hash ?? '';

  /// Calcular hash del contenido (para detectar tampering)
  String calculateHash() {
    final content = '$action|$userId|$entityId|${timestamp.toIso8601String()}|${jsonEncode(oldValues)}|${jsonEncode(newValues)}';
    return sha256.convert(utf8.encode(content)).toString();
  }

  /// Verificar integridad del registro
  bool verifyIntegrity() {
    return calculateHash() == hash;
  }

  /// Serializar a JSON
  Map<String, dynamic> toJson() => {
        'id': id,
        'action': action,
        'userId': userId,
        'entityId': entityId,
        'oldValues': oldValues,
        'newValues': newValues,
        'timestamp': timestamp.toIso8601String(),
        'ipAddress': ipAddress,
        'reason': reason,
        'notes': notes,
        'hash': hash,
      };

  /// Deserializar desde JSON
  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    final entry = AuditLogEntry(
      id: json['id'] ?? const Uuid().v4(),
      action: json['action'] ?? 'UNKNOWN',
      userId: json['userId'] ?? 'unknown',
      entityId: json['entityId'] ?? 'unknown',
      oldValues: json['oldValues'] ?? {},
      newValues: json['newValues'] ?? {},
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      ipAddress: json['ipAddress'],
      reason: json['reason'],
      notes: json['notes'],
      hash: json['hash'] ?? '',
    );
    return entry;
  }

  @override
  String toString() {
    return '''
AuditLogEntry(
  id: $id,
  action: $action,
  userId: $userId,
  entityId: $entityId,
  timestamp: $timestamp,
  hash: $hash
)''';
  }
}

/// Servicio de auditoría - Sistema append-only inmutable
/// Diseñado para cumplir con:
/// - AFIP (trazabilidad de operaciones)
/// - Ley 25.326 (Protección de Datos Personales)
/// - Auditorías forenses
///
/// SEGURIDAD / INTEGRIDAD FORENSE: antes esto guardaba los logs solo en
/// SharedPreferences del propio dispositivo, y el hash de integridad se
/// calculaba con un algoritmo que también vive en el mismo código fuente
/// que un atacante puede leer/modificar. Eso significa que alguien con
/// acceso al dispositivo (root, debugging, o simplemente editando la app)
/// puede borrar o reescribir tanto los logs como el hash que los "protege"
/// — la detección de tampering era cosmética, no una garantía real.
///
/// Ahora cada entrada se replica además a Cloud Firestore, en una
/// colección de solo-append (`kioscos/{kioscoId}/audit_logs`) a la que el
/// cliente no tiene permiso de editar ni borrar documentos existentes
/// (reglas de seguridad de Firestore — ver SECURITY_RULES.md). Esa copia
/// vive fuera del dispositivo del empleado, así que un atacante local ya
/// no puede hacer que su propio rastro desaparezca: puede manipular su
/// copia local, pero no la que ya viajó a la nube. `detectTampering` ahora
/// compara la copia local contra la remota además de verificar el hash.
class AuditService {
  static const String _auditLogsKey = 'audit_logs';
  static const int _maxLogs = 50000; // Retención máxima
  static const int _cleanupThreshold = 45000; // Limpiar cuando excede

  static CollectionReference<Map<String, dynamic>> _remoteLogsRef(String kioscoId) =>
      FirebaseFirestore.instance.collection('kioscos').doc(kioscoId).collection('audit_logs');

  /// Registrar una acción en la auditoría. Si se provee kioscoId, además
  /// de guardar localmente intenta replicar a Firestore (best-effort: si
  /// no hay conexión, la app sigue funcionando y la réplica remota queda
  /// pendiente — Firestore reintenta el envío offline automáticamente).
  static Future<void> logAction({
    required String action,
    required String userId,
    required String entityId,
    required Map<String, dynamic> oldValues,
    required Map<String, dynamic> newValues,
    String? kioscoId,
    String? ipAddress,
    String? reason,
    String? notes,
  }) async {
    try {
      var entry = AuditLogEntry(
        action: action,
        userId: userId,
        entityId: entityId,
        oldValues: oldValues,
        newValues: newValues,
        ipAddress: ipAddress,
        reason: reason,
        notes: notes,
      );

      entry = AuditLogEntry(
        id: entry.id,
        action: entry.action,
        userId: entry.userId,
        entityId: entry.entityId,
        oldValues: entry.oldValues,
        newValues: entry.newValues,
        timestamp: entry.timestamp,
        ipAddress: entry.ipAddress,
        reason: entry.reason,
        notes: entry.notes,
        hash: entry.calculateHash(),
      );

      final prefs = await SharedPreferences.getInstance();
      final logsJson = prefs.getString(_auditLogsKey) ?? '[]';
      final List<dynamic> logs = json.decode(logsJson);

      logs.add(entry.toJson());

      if (logs.length > _cleanupThreshold) {
        logs.removeRange(0, logs.length - _maxLogs);
      }

      await prefs.setString(_auditLogsKey, json.encode(logs));

      if (kioscoId != null) {
        // No esperamos (no usamos await bloqueante) para no trabar la UI
        // si la red está lenta; Firestore maneja la cola offline solo.
        _remoteLogsRef(kioscoId).doc(entry.id).set(entry.toJson()).catchError((e) {
          debugLog('⚠️ No se pudo replicar auditoría a Firestore (quedará en cola offline): $e');
        });
      }

      debugLog('✓ Acción auditada: $action → $entityId');
    } catch (e) {
      debugLog('❌ Error registrando acción en auditoría: $e');
      rethrow;
    }
  }

  /// Registrar un error (para diagnosticar problemas)
  static Future<void> logError(String errorAction, String errorMessage, {String? kioscoId}) async {
    await logAction(
      action: 'ERROR',
      userId: 'SYSTEM',
      entityId: 'ERROR_LOG',
      oldValues: {'action': errorAction},
      newValues: {'error': errorMessage, 'timestamp': DateTime.now().toIso8601String()},
      reason: 'Error del sistema',
      kioscoId: kioscoId,
    );
  }

  /// Obtener historial completo (requiere ser admin)
  static Future<List<AuditLogEntry>> getFullAuditTrail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logsJson = prefs.getString(_auditLogsKey) ?? '[]';
      final List<dynamic> decoded = json.decode(logsJson);

      return decoded
          .map((l) => AuditLogEntry.fromJson(l as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugLog('Error retrieving audit trail: $e');
      return [];
    }
  }

  /// Obtener acciones de un usuario específico
  static Future<List<AuditLogEntry>> getUserActions(
    String userId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final logs = await getFullAuditTrail();

    return logs.where((log) {
      bool matchesUser = log.userId == userId;
      bool matchesDateFrom = from == null || log.timestamp.isAfter(from);
      bool matchesDateTo = to == null || log.timestamp.isBefore(to);

      return matchesUser && matchesDateFrom && matchesDateTo;
    }).toList();
  }

  /// Obtener historial de cambios de una entidad (producto, venta, etc.)
  static Future<List<AuditLogEntry>> getEntityHistory(String entityId) async {
    final logs = await getFullAuditTrail();
    return logs.where((log) => log.entityId == entityId).toList();
  }

  /// Obtener acciones de un tipo específico
  static Future<List<AuditLogEntry>> getActionsByType(String action) async {
    final logs = await getFullAuditTrail();
    return logs.where((log) => log.action == action).toList();
  }

  /// Detectar posible tampering en los logs locales (verificación de hash
  /// individual, funciona siempre, online u offline).
  static Future<List<String>> detectTampering() async {
    final logs = await getFullAuditTrail();
    final tamperedIds = <String>[];

    for (var log in logs) {
      if (!log.verifyIntegrity()) {
        tamperedIds.add(log.id);
      }
    }

    if (tamperedIds.isNotEmpty) {
      debugLog('⚠️ ALERTA: Se detectó tampering en ${tamperedIds.length} registros de auditoría');

      await logAction(
        action: 'TAMPERING_DETECTED',
        userId: 'SYSTEM',
        entityId: 'AUDIT_LOG',
        oldValues: {},
        newValues: {'tampered_count': tamperedIds.length, 'tampered_ids': tamperedIds},
        reason: '⚠️ Intento de alteración de logs de auditoría detectado',
      );
    }

    return tamperedIds;
  }

  /// Verificación más fuerte: compara la copia local contra la copia
  /// remota en Firestore (que el cliente no puede editar). Si un log
  /// existe localmente con un hash distinto al que quedó registrado en la
  /// nube en su momento, o si un log local desapareció de la nube, hay
  /// evidencia de manipulación local. Requiere conexión a internet.
  static Future<Map<String, dynamic>> detectTamperingAgainstRemote(String kioscoId) async {
    try {
      final localLogs = await getFullAuditTrail();
      final remoteSnap = await _remoteLogsRef(kioscoId).get();
      final remoteById = {
        for (final doc in remoteSnap.docs) doc.id: AuditLogEntry.fromJson(doc.data())
      };

      final mismatched = <String>[];
      final missingRemotely = <String>[];

      for (final local in localLogs) {
        final remote = remoteById[local.id];
        if (remote == null) {
          // Puede ser legítimo si se generó offline y todavía no sincronizó;
          // se reporta como advertencia, no como tampering confirmado.
          missingRemotely.add(local.id);
        } else if (remote.hash != local.hash) {
          mismatched.add(local.id);
        }
      }

      return {
        'checked_at': DateTime.now().toIso8601String(),
        'local_count': localLogs.length,
        'remote_count': remoteSnap.docs.length,
        'hash_mismatch_ids': mismatched,
        'missing_remotely_ids': missingRemotely,
        'integrity_ok': mismatched.isEmpty,
      };
    } catch (e) {
      return {'error': e.toString(), 'integrity_ok': false};
    }
  }

  /// Generar reporte de auditoría para AFIP
  static Future<String> generateAFIPReport({
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final logs = await getFullAuditTrail();

      final filtered = logs.where((log) {
        bool matchesFrom = from == null || log.timestamp.isAfter(from);
        bool matchesTo = to == null || log.timestamp.isBefore(to);
        return matchesFrom && matchesTo;
      }).toList();

      final csv = StringBuffer();
      csv.writeln('ID,FECHA,HORA,ACCION,USUARIO,ENTIDAD,MOTIVO,VALORES_ANTERIORES,VALORES_NUEVOS,HASH_INTEGRIDAD');

      for (var log in filtered) {
        final date = log.timestamp.toLocal().toIso8601String().split('T').first;
        final time = log.timestamp.toLocal().toIso8601String().split('T').last;

        csv.writeln(
          '"${log.id}",'
          '"$date",'
          '"$time",'
          '"${log.action}",'
          '"${log.userId}",'
          '"${log.entityId}",'
          '"${log.reason ?? ''}",'
          '"${json.encode(log.oldValues)}",'
          '"${json.encode(log.newValues)}",'
          '"${log.hash}"'
        );
      }

      return csv.toString();
    } catch (e) {
      debugLog('Error generating AFIP report: $e');
      return '';
    }
  }

  /// Generar reporte de auditoría por usuario
  static Future<String> generateUserReport(String userId) async {
    try {
      final logs = await getUserActions(userId);

      final report = StringBuffer();
      report.writeln('╔════════════════════════════════════════════════════════════════╗');
      report.writeln('║              REPORTE DE AUDITORÍA POR USUARIO                  ║');
      report.writeln('╚════════════════════════════════════════════════════════════════╝\n');
      report.writeln('Usuario: $userId');
      report.writeln('Acciones registradas: ${logs.length}');
      report.writeln('Rango: ${logs.isNotEmpty ? logs.first.timestamp : 'N/A'} - ${logs.isNotEmpty ? logs.last.timestamp : 'N/A'}');
      report.writeln('\n────────────────────────────────────────────────────────────────\n');

      for (var log in logs) {
        report.writeln('Timestamp: ${log.timestamp}');
        report.writeln('Acción: ${log.action}');
        report.writeln('Entidad: ${log.entityId}');
        if (log.reason != null) report.writeln('Motivo: ${log.reason}');
        report.writeln('Valores Anteriores: ${json.encode(log.oldValues)}');
        report.writeln('Valores Nuevos: ${json.encode(log.newValues)}');
        report.writeln('Hash: ${log.hash}');
        report.writeln('');
      }

      return report.toString();
    } catch (e) {
      return 'Error generando reporte: $e';
    }
  }

  /// Verificar integridad completa del sistema de auditoría
  static Future<Map<String, dynamic>> verifyAuditIntegrity({String? kioscoId}) async {
    try {
      final logs = await getFullAuditTrail();
      final tampered = await detectTampering();

      final result = {
        'total_logs': logs.length,
        'tampered_logs': tampered.length,
        'integrity_ok': tampered.isEmpty,
        'timestamp': DateTime.now().toIso8601String(),
        'tampered_ids': tampered,
      };

      if (kioscoId != null) {
        result['remote_check'] = await detectTamperingAgainstRemote(kioscoId);
      }

      return result;
    } catch (e) {
      return {
        'error': e.toString(),
        'integrity_ok': false,
      };
    }
  }

  /// Estadísticas de auditoría
  static Future<Map<String, dynamic>> getStatistics() async {
    try {
      final logs = await getFullAuditTrail();

      final actionCounts = <String, int>{};
      final userCounts = <String, int>{};

      for (var log in logs) {
        actionCounts[log.action] = (actionCounts[log.action] ?? 0) + 1;
        userCounts[log.userId] = (userCounts[log.userId] ?? 0) + 1;
      }

      return {
        'total_entries': logs.length,
        'actions_by_type': actionCounts,
        'actions_by_user': userCounts,
        'date_range': {
          'from': logs.isNotEmpty ? logs.first.timestamp.toIso8601String() : null,
          'to': logs.isNotEmpty ? logs.last.timestamp.toIso8601String() : null,
        },
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Exportar logs de auditoría
  static Future<String> exportAuditLogs() async {
    try {
      final logs = await getFullAuditTrail();
      return json.encode({
        'version': '1.0.0',
        'exported_at': DateTime.now().toIso8601String(),
        'total_entries': logs.length,
        'logs': logs.map((l) => l.toJson()).toList(),
      });
    } catch (e) {
      debugLog('Error exporting audit logs: $e');
      return '{}';
    }
  }

  /// Limpiar logs antiguos del dispositivo (> 90 días). La copia remota en
  /// Firestore NO se borra acá — es la que cumple el rol de archivo
  /// histórico permanente para auditorías forenses/AFIP.
  static Future<void> cleanupOldLogs({int daysToKeep = 90}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
      final logs = await getFullAuditTrail();

      final filtered = logs.where((log) => log.timestamp.isAfter(cutoffDate)).toList();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_auditLogsKey, json.encode(filtered.map((l) => l.toJson()).toList()));

      debugLog('✓ Limpieza de logs completada. Registros eliminados: ${logs.length - filtered.length}');
    } catch (e) {
      debugLog('Error cleaning up logs: $e');
    }
  }
}
