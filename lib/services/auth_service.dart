import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_user.dart';
import '../models/permission.dart';
import 'device_service.dart';

const _kLastKioscoIdKey = 'last_kiosco_id';

/// Excepción de negocio para mostrar mensajes claros en la UI.
class AuthFlowException implements Exception {
  final String message;
  AuthFlowException(this.message);
  @override
  String toString() => message;
}

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentFirebaseUser => _auth.currentUser;

  /// Email sintético interno: Firebase Auth exige formato email,
  /// pero el kiosquero solo ve "usuario" + "kiosco".
  String _syntheticEmail(String usuario, String kioscoId) {
    final u = usuario.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_.]'), '');
    final k = kioscoId.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_.]'), '');
    return '$u@$k.kiosco.local';
  }

  /// Alta inicial: crea el kiosco (empresa) y su usuario admin.
  /// Se usa una sola vez por kiosco, desde la pantalla "Crear kiosco".
  Future<AppUser> registerKioscoAndAdmin({
    required String kioscoId,
    required String kioscoNombre,
    required String usuario,
    required String password,
  }) async {
    final kioscoRef = _db.collection('kioscos').doc(kioscoId.trim());

    // No podemos leer Firestore para chequear si el kiosco ya existe
    // ANTES de autenticar: las reglas de seguridad exigen una sesión
    // (request.auth != null), y todavía no la hay. Por eso primero
    // creamos el usuario de Auth, y recién con sesión activa chequeamos
    // y escribimos en Firestore. Si el kiosco ya existía, deshacemos
    // la cuenta de Auth para no dejar usuarios huérfanos.
    final email = _syntheticEmail(usuario, kioscoId);
    UserCredential cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthFlowException(_mapAuthError(e));
    }

    final deviceId = await DeviceService.getDeviceId();

    final appUser = AppUser(
      uid: cred.user!.uid,
      usuario: usuario.trim(),
      kioscoId: kioscoId.trim(),
      role: 'admin',
      deviceId: deviceId,
      deviceLinkedAt: DateTime.now(),
      displayName: usuario.trim(),
    );

    // Reclamo atómico del kioscoId: la transacción lee y escribe el mismo
    // doc en una sola operación indivisible, así que si dos registros con
    // el mismo kioscoId corren en simultáneo, Firestore garantiza que solo
    // uno de los dos ve el doc como "no existente" y logra crearlo — el
    // otro siempre va a leer el doc ya creado por el primero, sin importar
    // el entrelazado real de los hilos. Esto cierra la ventana de carrera
    // que existía antes entre el .get() y el .set() por separado.
    try {
      await _db.runTransaction((transaction) async {
        final snap = await transaction.get(kioscoRef);
        if (snap.exists) {
          throw AuthFlowException('Ya existe un kiosco con ese código. Elegí otro o iniciá sesión.');
        }
        transaction.set(kioscoRef, {
          'nombre': kioscoNombre.trim(),
          'createdAt': DateTime.now().toIso8601String(),
        });
        transaction.set(kioscoRef.collection('users').doc(cred.user!.uid), appUser.toJson());
      });
    } catch (e) {
      // El kiosco ya existía (o falló la transacción por otro motivo):
      // deshacemos la cuenta de Auth recién creada para no dejarla huérfana.
      await cred.user!.delete();
      if (e is AuthFlowException) rethrow;
      throw AuthFlowException('No se pudo crear el kiosco. Intentá nuevamente.');
    }

    await _rememberKioscoId(kioscoId.trim());
    return appUser;
  }

  /// El admin crea un usuario empleado para su kiosco. Todavía sin
  /// dispositivo vinculado: se vincula solo la primera vez que ese
  /// empleado inicia sesión desde un celular.
  Future<void> createEmployee({
    required String kioscoId,
    required String usuario,
    required String password,
    String? displayName,
  }) async {
    final email = _syntheticEmail(usuario, kioscoId);

    // Crear el usuario de Auth sin cerrar la sesión del admin actual
    // requiere una app secundaria; Firebase Auth en Flutter no lo
    // soporta directo, así que usamos un signUp temporal y luego
    // revalidamos sesión del admin en la UI si hiciera falta.
    UserCredential cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthFlowException(_mapAuthError(e));
    }

    final appUser = AppUser(
      uid: cred.user!.uid,
      usuario: usuario.trim(),
      kioscoId: kioscoId.trim(),
      role: 'empleado',
      displayName: displayName?.trim().isNotEmpty == true ? displayName!.trim() : usuario.trim(),
      permissions: Map.of(defaultEmployeePermissions),
    );

    await _db
        .collection('kioscos')
        .doc(kioscoId.trim())
        .collection('users')
        .doc(cred.user!.uid)
        .set(appUser.toJson());
  }

  /// Login normal: usuario + contraseña + código de kiosco.
  /// Si el usuario es 'empleado' y no tiene dispositivo vinculado,
  /// se vincula automáticamente al dispositivo actual. Si ya tiene
  /// uno vinculado y no coincide, se rechaza el login.
  Future<AppUser> login({
    required String kioscoId,
    required String usuario,
    required String password,
  }) async {
    final email = _syntheticEmail(usuario, kioscoId);

    UserCredential cred;
    try {
      cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthFlowException(_mapAuthError(e));
    }

    final userRef = _db
        .collection('kioscos')
        .doc(kioscoId.trim())
        .collection('users')
        .doc(cred.user!.uid);

    final snap = await userRef.get();
    if (!snap.exists) {
      await _auth.signOut();
      throw AuthFlowException('Este usuario no pertenece al kiosco "$kioscoId".');
    }

    var appUser = AppUser.fromJson(cred.user!.uid, snap.data()!);
    final currentDeviceId = await DeviceService.getDeviceId();

    if (!appUser.isAdmin) {
      if (!appUser.hasDeviceLinked) {
        // Primer login del empleado: vincula este celular.
        appUser = appUser.copyWith(deviceId: currentDeviceId, deviceLinkedAt: DateTime.now());
        await userRef.update({
          'deviceId': currentDeviceId,
          'deviceLinkedAt': DateTime.now().toIso8601String(),
        });
      } else if (appUser.deviceId != currentDeviceId) {
        await _auth.signOut();
        throw AuthFlowException(
          'Esta cuenta ya está vinculada a otro celular. Pedile al administrador que la desvincule si cambiaste de equipo.',
        );
      }
    }

    await _rememberKioscoId(kioscoId.trim());
    return appUser;
  }

  Future<void> _rememberKioscoId(String kioscoId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastKioscoIdKey, kioscoId);
  }

  /// Intenta restaurar la sesión si Firebase Auth ya tiene un usuario
  /// logueado de una sesión anterior (no requiere pedir credenciales).
  /// Devuelve null si no hay sesión previa válida.
  Future<AppUser?> tryRestoreSession() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;

    final prefs = await SharedPreferences.getInstance();
    final kioscoId = prefs.getString(_kLastKioscoIdKey);
    if (kioscoId == null) return null;

    final snap = await _db
        .collection('kioscos')
        .doc(kioscoId)
        .collection('users')
        .doc(firebaseUser.uid)
        .get();

    if (!snap.exists) return null;
    return AppUser.fromJson(firebaseUser.uid, snap.data()!);
  }

  /// El admin puede liberar el vínculo de un empleado para que pueda
  /// volver a iniciar sesión desde otro celular.
  Future<void> unlinkDevice({required String kioscoId, required String uid}) async {
    await _db
        .collection('kioscos')
        .doc(kioscoId.trim())
        .collection('users')
        .doc(uid)
        .update({'deviceId': null, 'deviceLinkedAt': null});
  }

  /// Borra el acceso de un empleado: borra su doc en Firestore y encola una
  /// solicitud de borrado en 'auth_deletion_requests/{uid}'. El cliente NO
  /// puede borrar la cuenta de Firebase Auth de otro usuario (el SDK solo
  /// permite borrar la cuenta logueada actualmente), así que esa cola la
  /// procesa la Cloud Function 'processAuthDeletions' (ver
  /// functions/index.js) que corre con Admin SDK y llama
  /// admin.auth().deleteUser(uid), dejando el borrado simétrico entre
  /// Firestore y Auth en vez de dejar la cuenta de Auth huérfana.
  Future<void> deleteEmployee({required String kioscoId, required String uid}) async {
    final userRef = _db.collection('kioscos').doc(kioscoId.trim()).collection('users').doc(uid);
    final snap = await userRef.get();
    final usuario = snap.data()?['usuario'] as String? ?? uid;

    await _db.collection('auth_deletion_requests').doc(uid).set({
      'uid': uid,
      'kioscoId': kioscoId.trim(),
      'usuario': usuario,
      'requestedAt': DateTime.now().toIso8601String(),
      'requestedBy': _auth.currentUser?.uid,
      'status': 'pending',
    });

    await userRef.delete();
  }

  Stream<List<AppUser>> watchEmployees(String kioscoId) {
    return _db
        .collection('kioscos')
        .doc(kioscoId.trim())
        .collection('users')
        .orderBy('createdAt')
        .snapshots()
        .map((s) => s.docs.map((d) => AppUser.fromJson(d.id, d.data())).toList());
  }

  Future<void> signOut() => _auth.signOut();

  // --- Superadmin global (Fernando) ---
  //
  // El superadmin no pertenece a ningún kiosco: ve y administra TODOS los
  // kioscos. En vez de hardcodear un email o uid en el cliente (lo que
  // cualquiera podría leer descompilando el APK e intentar suplantar), la
  // pertenencia se resuelve contra una colección de Firestore
  // ('superadmins/{uid}') que solo un superadmin ya autenticado puede
  // escribir (las reglas de seguridad del proyecto deben restringir
  // create/update/delete en esa colección — ver SECURITY_RULES.md). El
  // cliente solo puede *leer* su propio documento para autodeterminarse.

  /// true si el usuario de Firebase Auth actualmente logueado es superadmin
  /// global. No requiere haber pasado por el flujo normal de login con
  /// kioscoId: el superadmin inicia sesión con su email real (no el
  /// formato sintético usuario@kiosco.local).
  Future<bool> isSuperAdmin([String? uid]) async {
    final id = uid ?? _auth.currentUser?.uid;
    if (id == null) return false;
    try {
      final snap = await _db.collection('superadmins').doc(id).get();
      return snap.exists;
    } catch (_) {
      return false;
    }
  }

  /// Login del superadmin: usa su email real de Firebase Auth directamente
  /// (no hay kiosco ni usuario sintético). Solo tiene efecto si el uid
  /// resultante está presente en la colección 'superadmins'.
  Future<bool> loginSuperAdmin({required String email, required String password}) async {
    UserCredential cred;
    try {
      cred = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthFlowException(_mapAuthError(e));
    }
    final ok = await isSuperAdmin(cred.user!.uid);
    if (!ok) {
      await _auth.signOut();
      throw AuthFlowException('Esta cuenta no tiene permisos de super administrador.');
    }
    return true;
  }

  /// El superadmin precrea un kiosco nuevo y su usuario admin desde el
  /// panel global, sin que el dueño del kiosco tenga que autoregistrarse.
  /// Limitación real de Firebase Auth en cliente: crear un usuario nuevo
  /// cierra la sesión actual (la del superadmin). Por eso, después de
  /// crear el kiosco+admin, volvemos a loguear automáticamente al
  /// superadmin con las credenciales que recibimos por parámetro, así la
  /// UI nunca queda deslogueada ni tiene que pedirle la contraseña otra vez.
  Future<void> createKioscoAsSuperAdmin({
    required String kioscoId,
    required String kioscoNombre,
    required String usuario,
    required String password,
    required String superAdminEmail,
    required String superAdminPassword,
  }) async {
    await registerKioscoAndAdmin(
      kioscoId: kioscoId,
      kioscoNombre: kioscoNombre,
      usuario: usuario,
      password: password,
    );
    // registerKioscoAndAdmin deja logueado al admin nuevo; volvemos a
    // entrar como superadmin para que el panel no pierda la sesión.
    await loginSuperAdmin(email: superAdminEmail, password: superAdminPassword);
  }

  /// Lista en vivo de todos los kioscos registrados, para la vista global
  /// del superadmin. Cada documento tiene 'nombre' y 'createdAt'.
  Stream<List<Map<String, dynamic>>> watchAllKioscos() {
    return _db.collection('kioscos').snapshots().map(
          (s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
        );
  }

  /// Métricas de soporte de un kiosco puntual, para el panel del superadmin.
  /// Importante: el inventario y las ventas de cada kiosco viven en
  /// SharedPreferences LOCAL al dispositivo del kiosquero (ver
  /// StorageService) — no en Firestore. Por diseño, el superadmin nunca
  /// puede ver "cuántos productos tiene" o "cuánto vendió" un kiosco ajeno
  /// desde otro dispositivo; sí puede ver todo lo que vive en Firestore:
  /// el equipo de usuarios del kiosco y el estado de sus vínculos.
  Future<Map<String, dynamic>> getKioscoSupportInfo(String kioscoId) async {
    final usersSnap = await _db.collection('kioscos').doc(kioscoId.trim()).collection('users').get();
    final users = usersSnap.docs.map((d) => AppUser.fromJson(d.id, d.data())).toList();

    final adminMatches = users.where((u) => u.isAdmin).toList();
    final admin = adminMatches.isNotEmpty ? adminMatches.first : null;
    final employees = users.where((u) => !u.isAdmin).toList();
    final employeesWithoutDevice = employees.where((u) => !u.hasDeviceLinked).length;

    return {
      'totalUsers': users.length,
      'admin': admin,
      'employeeCount': employees.length,
      'employeesWithoutDevice': employeesWithoutDevice,
      'adminHasDeviceLinked': admin?.hasDeviceLinked ?? false,
    };
  }

  /// Acción de soporte del superadmin: libera el vínculo de dispositivo del
  /// ADMIN de un kiosco (no de un empleado — para eso ya existe
  /// unlinkDevice desde el propio panel del kiosco). Útil cuando el dueño
  /// del kiosco perdió o cambió de celular y no tiene a nadie más con
  /// acceso para desvincularlo él mismo.
  Future<void> unlinkKioscoAdminDevice(String kioscoId) async {
    final usersSnap = await _db.collection('kioscos').doc(kioscoId.trim()).collection('users').get();
    final adminDocs = usersSnap.docs.where((d) => d.data()['role'] == 'admin').toList();
    if (adminDocs.isEmpty) {
      throw AuthFlowException('Este kiosco no tiene un usuario admin.');
    }
    await adminDocs.first.reference.update({'deviceId': null, 'deviceLinkedAt': null});
  }

  /// El admin de un kiosco (o el superadmin) actualiza los permisos
  /// granulares de un empleado. No tiene efecto sobre cuentas admin: los
  /// admins siempre tienen todos los permisos implícitamente.
  Future<void> updateEmployeePermissions({
    required String kioscoId,
    required String uid,
    required Map<Permission, bool> permissions,
  }) async {
    await _db
        .collection('kioscos')
        .doc(kioscoId.trim())
        .collection('users')
        .doc(uid)
        .update({'permissions': permissions.map((k, v) => MapEntry(k.name, v))});
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Ese nombre de usuario ya está en uso en este kiosco.';
      case 'weak-password':
        return 'La contraseña es muy débil (mínimo 6 caracteres).';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Usuario, contraseña o kiosco incorrectos.';
      case 'invalid-email':
        return 'Nombre de usuario inválido.';
      default:
        return 'Error de autenticación: ${e.message ?? e.code}';
    }
  }
}
