import 'permission.dart';

class AppUser {
  final String uid;
  final String usuario;
  final String kioscoId;
  // 'admin' (dueño del kiosco) o 'empleado'. El superadmin global (Fernando)
  // NO se modela con un valor de role acá: se detecta por separado en
  // Firestore (colección 'superadmins') porque no pertenece a ningún
  // kiosco en particular, ve todos. Ver AuthService.isSuperAdmin().
  final String role;
  final String? deviceId;
  final DateTime? deviceLinkedAt;
  final String? displayName;
  final DateTime createdAt;
  // Permisos granulares, solo relevantes para 'empleado'. Si es null (datos
  // viejos, antes de esta feature, o un admin que no necesita esto), se
  // asume que el empleado tiene los permisos por defecto — así ningún
  // empleado existente queda repentinamente sin poder hacer nada tras
  // actualizar la app.
  final Map<Permission, bool>? permissions;

  AppUser({
    required this.uid,
    required this.usuario,
    required this.kioscoId,
    required this.role,
    this.deviceId,
    this.deviceLinkedAt,
    this.displayName,
    DateTime? createdAt,
    this.permissions,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isAdmin => role == 'admin';
  bool get hasDeviceLinked => deviceId != null && deviceId!.isNotEmpty;

  /// Los admins (y el superadmin) tienen todos los permisos implícitamente.
  /// Para un empleado, mira su mapa de permisos; si no tiene ese permiso
  /// explícito guardado, cae al default de esa feature.
  bool hasPermission(Permission permission) {
    if (isAdmin) return true;
    final stored = permissions?[permission];
    if (stored != null) return stored;
    return defaultEmployeePermissions[permission] ?? false;
  }

  Map<String, dynamic> toJson() => {
        'usuario': usuario,
        'kioscoId': kioscoId,
        'role': role,
        'deviceId': deviceId,
        'deviceLinkedAt': deviceLinkedAt?.toIso8601String(),
        'displayName': displayName,
        'createdAt': createdAt.toIso8601String(),
        'permissions': permissions?.map((k, v) => MapEntry(k.name, v)),
      };

  factory AppUser.fromJson(String uid, Map<String, dynamic> json) => AppUser(
        uid: uid,
        usuario: json['usuario'] ?? '',
        kioscoId: json['kioscoId'] ?? '',
        role: json['role'] ?? 'empleado',
        deviceId: json['deviceId'],
        deviceLinkedAt: json['deviceLinkedAt'] != null
            ? DateTime.tryParse(json['deviceLinkedAt'])
            : null,
        displayName: json['displayName'],
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
            : DateTime.now(),
        permissions: _parsePermissions(json['permissions']),
      );

  static Map<Permission, bool>? _parsePermissions(dynamic raw) {
    if (raw == null || raw is! Map) return null;
    final result = <Permission, bool>{};
    raw.forEach((key, value) {
      final perm = PermissionLabel.fromName(key as String);
      if (perm != null) result[perm] = value as bool;
    });
    return result;
  }

  AppUser copyWith({
    String? deviceId,
    DateTime? deviceLinkedAt,
    String? displayName,
    String? role,
    Map<Permission, bool>? permissions,
  }) {
    return AppUser(
      uid: uid,
      usuario: usuario,
      kioscoId: kioscoId,
      role: role ?? this.role,
      deviceId: deviceId ?? this.deviceId,
      deviceLinkedAt: deviceLinkedAt ?? this.deviceLinkedAt,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt,
      permissions: permissions ?? this.permissions,
    );
  }
}
