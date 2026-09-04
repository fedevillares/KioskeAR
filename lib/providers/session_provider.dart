import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/permission.dart';
import '../services/auth_service.dart';

/// Mantiene el usuario logueado (admin o empleado) disponible en toda
/// la app, y expone helpers de rol y kiosco actual.
class SessionProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;

  bool _restoring = true;
  bool get isRestoring => _restoring;

  // El superadmin (Fernando) no tiene un AppUser de ningún kiosco: se
  // detecta aparte contra Firestore. Cuando es true, currentUser puede ser
  // null (no hace falta pertenecer a ningún kiosco para usar la vista
  // global de superadmin).
  bool _isSuperAdmin = false;
  bool get isSuperAdmin => _isSuperAdmin;

  // Credenciales del superadmin retenidas SOLO en memoria (nunca en disco)
  // mientras dura la sesión. Hacen falta para el re-login automático que
  // exige createKioscoAsSuperAdmin (crear un usuario nuevo en Firebase
  // Auth cierra la sesión actual). Se pierden al cerrar la app o la sesión.
  String? _superAdminEmail;
  String? _superAdminPassword;

  bool get isLoggedIn => _currentUser != null || _isSuperAdmin;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  String? get kioscoId => _currentUser?.kioscoId;

  bool hasPermission(Permission permission) {
    if (_isSuperAdmin) return true;
    return _currentUser?.hasPermission(permission) ?? false;
  }

  /// Se llama una vez al arrancar la app, antes de mostrar el splash.
  /// Si Firebase ya tenía una sesión activa, la recupera sin pedir
  /// usuario/contraseña de nuevo.
  Future<void> restoreSession() async {
    try {
      _isSuperAdmin = await _authService.isSuperAdmin();
      if (!_isSuperAdmin) {
        _currentUser = await _authService.tryRestoreSession();
      }
    } catch (_) {
      _currentUser = null;
      _isSuperAdmin = false;
    } finally {
      _restoring = false;
      notifyListeners();
    }
  }

  Future<void> login({
    required String kioscoId,
    required String usuario,
    required String password,
  }) async {
    final user = await _authService.login(
      kioscoId: kioscoId,
      usuario: usuario,
      password: password,
    );
    _currentUser = user;
    _isSuperAdmin = false;
    notifyListeners();
  }

  /// Login exclusivo del superadmin global: usa email real, sin kiosco.
  Future<void> loginSuperAdmin({required String email, required String password}) async {
    await _authService.loginSuperAdmin(email: email, password: password);
    _currentUser = null;
    _isSuperAdmin = true;
    _superAdminEmail = email;
    _superAdminPassword = password;
    notifyListeners();
  }

  Future<void> registerKioscoAndAdmin({
    required String kioscoId,
    required String kioscoNombre,
    required String usuario,
    required String password,
  }) async {
    final user = await _authService.registerKioscoAndAdmin(
      kioscoId: kioscoId,
      kioscoNombre: kioscoNombre,
      usuario: usuario,
      password: password,
    );
    _currentUser = user;
    _isSuperAdmin = false;
    notifyListeners();
  }

  /// El superadmin (logueado con su email real) precrea un kiosco nuevo y
  /// su admin. Internamente esto desloguea y vuelve a loguear como
  /// superadmin usando las credenciales retenidas en memoria desde
  /// loginSuperAdmin — Fernando no tiene que volver a tipearlas.
  Future<void> createKioscoAsSuperAdmin({
    required String kioscoId,
    required String kioscoNombre,
    required String usuario,
    required String password,
  }) async {
    final email = _superAdminEmail;
    final superPassword = _superAdminPassword;
    if (email == null || superPassword == null) {
      throw Exception('Sesión de super admin expirada. Volvé a iniciar sesión.');
    }
    await _authService.createKioscoAsSuperAdmin(
      kioscoId: kioscoId,
      kioscoNombre: kioscoNombre,
      usuario: usuario,
      password: password,
      superAdminEmail: email,
      superAdminPassword: superPassword,
    );
    _currentUser = null;
    _isSuperAdmin = true;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _currentUser = null;
    _isSuperAdmin = false;
    _superAdminEmail = null;
    _superAdminPassword = null;
    notifyListeners();
  }
}
