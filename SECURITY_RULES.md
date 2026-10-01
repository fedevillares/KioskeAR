# Reglas de seguridad de Firestore — Kioske.AR

Este documento describe las reglas de seguridad que deben estar publicadas en
Firebase Console → Firestore Database → Reglas. El cliente Flutter **no**
puede aplicar estas restricciones por sí solo: si las reglas reales del
proyecto son más permisivas que esto, cualquiera con el APK descompilado
puede saltarse la lógica de la app y escribir directo contra Firestore.

## Estructura de datos relevante

```
kioscos/{kioscoId}
kioscos/{kioscoId}/users/{uid}
kioscos/{kioscoId}/audit_logs/{logId}
superadmins/{uid}
auth_deletion_requests/{uid}
```

## Principios generales

1. Nada se permite por defecto (`allow read, write: if false;` como base).
2. Un usuario autenticado solo puede leer/escribir dentro del subárbol de
   `kioscos/{kioscoId}` al que pertenece (su doc en `users/{uid}` debe
   existir con ese mismo `kioscoId`).
3. El rol (`admin`/`empleado`) y los permisos granulares (`permissions`)
   se leen del propio documento del usuario, nunca de un valor que el
   cliente mande suelto en la escritura.
4. `superadmins/{uid}` es de solo lectura para el propio uid; nadie puede
   crear, modificar ni borrar esa colección desde el cliente, ni siquiera
   el propio superadmin. Se gestiona manualmente desde Firebase Console o
   un script administrativo con credenciales de servicio.
5. `audit_logs` es de solo creación (append-only): nadie, ni el admin del
   kiosco, puede editar o borrar un log ya escrito. Esto es lo que le da
   valor como registro forense — si se pudiera editar, no serviría como
   evidencia de qué pasó.

## Reglas sugeridas (Firestore Rules, v2)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isSignedIn() {
      return request.auth != null;
    }

    function isSuperAdmin() {
      return isSignedIn() &&
        exists(/databases/$(database)/documents/superadmins/$(request.auth.uid));
    }

    function userDoc(kioscoId) {
      return get(/databases/$(database)/documents/kioscos/$(kioscoId)/users/$(request.auth.uid));
    }

    function belongsToKiosco(kioscoId) {
      return isSignedIn() &&
        exists(/databases/$(database)/documents/kioscos/$(kioscoId)/users/$(request.auth.uid));
    }

    function isAdminOfKiosco(kioscoId) {
      return belongsToKiosco(kioscoId) &&
        userDoc(kioscoId).data.role == 'admin';
    }

    // --- superadmins: solo lectura del propio doc, nunca escritura desde cliente ---
    match /superadmins/{uid} {
      allow read: if isSignedIn() && request.auth.uid == uid;
      allow write: if false; // gestionado fuera de la app (Console / Admin SDK)
    }

    // --- kioscos: metadata visible para quien pertenece a él o el superadmin ---
    match /kioscos/{kioscoId} {
      allow read: if belongsToKiosco(kioscoId) || isSuperAdmin();
      // La creación inicial ocurre durante el registro (registerKioscoAndAdmin):
      // en ese momento el usuario ya está autenticado pero todavía no tiene
      // doc en users/, así que esta regla permite create a cualquier
      // autenticado, y confía en que el código de la app valida unicidad de
      // kioscoId antes de escribir. El update queda limitado al admin.
      allow create: if isSignedIn();
      allow update: if isAdminOfKiosco(kioscoId) || isSuperAdmin();
      allow delete: if isSuperAdmin();

      // --- users: cada kiosco gestiona sus propios usuarios ---
      match /users/{uid} {
        allow read: if belongsToKiosco(kioscoId) || isSuperAdmin();

        // Alta de admin (registro) o de empleado (admin lo crea): el doc
        // se crea con el mismo uid que el usuario de Auth recién creado.
        allow create: if isSignedIn() && request.auth.uid == uid
                       || isAdminOfKiosco(kioscoId)
                       || isSuperAdmin();

        // Nadie puede auto-otorgarse permisos ni cambiar su propio rol:
        // solo el admin del kiosco (o el superadmin) puede modificar el
        // doc de un empleado. Un empleado no-admin no puede escribir su
        // propio doc en absoluto (ni para tocar 'permissions' ni 'role').
        allow update: if isAdminOfKiosco(kioscoId) || isSuperAdmin();

        allow delete: if isAdminOfKiosco(kioscoId) || isSuperAdmin();
      }

      // --- audit_logs: append-only, nadie edita ni borra ---
      match /audit_logs/{logId} {
        allow read: if isAdminOfKiosco(kioscoId) || isSuperAdmin();
        allow create: if belongsToKiosco(kioscoId);
        allow update, delete: if false;
      }
    }

    // --- auth_deletion_requests: cola para que la Cloud Function
    // processAuthDeletion borre la cuenta de Firebase Auth de un empleado
    // eliminado. Solo se permite crear (encolar); el campo 'status' y el
    // borrado real de la cuenta los gestiona exclusivamente el Admin SDK
    // desde la función (que no pasa por estas reglas). Nadie desde el
    // cliente puede leer, modificar ni borrar una solicitud ya creada,
    // para que no se pueda falsear el estado ni espiar qué cuentas se
    // están borrando.
    match /auth_deletion_requests/{uid} {
      allow create: if isSignedIn();
      allow read, update, delete: if false;
    }
  }
}
```

## Pendientes operativos (no se resuelven con reglas)

- **Crear el documento `superadmins/{uid}` de Fernando.** No se puede hacer
  desde la app (las reglas de arriba lo prohíben a propósito). Pasos:
  1. Crear/usar una cuenta de Firebase Auth con el email real de Fernando
     (no el formato sintético `usuario@kiosco.local`).
  2. Desde Firebase Console → Firestore → crear manualmente el documento
     `superadmins/{uid}`, donde `{uid}` es el uid de esa cuenta de Auth
     (se ve en Authentication → Users). El contenido del documento puede
     ser `{ "createdAt": <timestamp> }` o similar; lo único que importa
     para las reglas es que el documento *exista*.
- **Borrado de cuentas de Auth — resuelto vía Cloud Function.**
  `deleteEmployee()` en el cliente borra el documento de Firestore y además
  encola una solicitud en `auth_deletion_requests/{uid}`. La función
  `processAuthDeletion` (en `functions/index.js`) escucha esa colección y
  llama a `admin.auth().deleteUser(uid)` con el Admin SDK, dejando el
  borrado simétrico entre Firestore y Auth. **Falta desplegar la función**
  para que esto tenga efecto real:
  1. Requiere que el proyecto esté en el plan Blaze (pago por uso) — los
     triggers de Firestore no corren en el plan gratuito Spark.
  2. Desde la raíz del proyecto: `cd functions && npm install`.
  3. Luego: `firebase deploy --only functions` (requiere Firebase CLI
     logueada con una cuenta que tenga permisos en el proyecto
     `mi-kiosco-f5f9b`).
  4. Hasta que se despliegue, las solicitudes quedan acumuladas en
     `auth_deletion_requests` con `status: "pending"` sin causar error —
     simplemente no se procesan todavía, así que las cuentas de Auth de
     empleados borrados quedan huérfanas hasta el primer deploy.
- **Rotación de la clave AES** usada para cifrar datos sensibles locales:
  ya no está hardcodeada en el código (resuelto en la Fase 1 de seguridad),
  pero sigue siendo responsabilidad operativa rotarla si se sospecha
  compromiso.
