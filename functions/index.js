/**
 * Cloud Functions de Kioske.AR.
 *
 * Estas funciones existen porque el cliente Flutter, autenticado con el SDK
 * normal de Firebase Auth, solo puede borrar la cuenta de Auth que está
 * actualmente logueada — nunca la de otro usuario. Para que borrar un
 * empleado sea simétrico (Firestore + Auth, no solo Firestore dejando una
 * cuenta huérfana), hace falta el Admin SDK, que solo corre en un entorno
 * de confianza como este.
 *
 * Despliegue (desde la carpeta del proyecto, con Firebase CLI instalado):
 *   firebase deploy --only functions
 *
 * Requiere que el proyecto esté en el plan Blaze (pago por uso) — los
 * triggers de Firestore no están disponibles en el plan gratuito Spark.
 */

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

/**
 * Se dispara cuando AuthService.deleteEmployee() (en el cliente Flutter)
 * crea un documento en 'auth_deletion_requests/{uid}'. Borra la cuenta de
 * Firebase Auth correspondiente y marca la solicitud como procesada.
 *
 * Idempotente: si el usuario de Auth ya no existe (por ejemplo porque la
 * función ya corrió antes para ese uid), lo trata como éxito en vez de
 * fallar, para que reintentos automáticos de Cloud Functions no queden
 * en loop de error.
 */
exports.processAuthDeletion = onDocumentCreated(
  "auth_deletion_requests/{uid}",
  async (event) => {
    const uid = event.params.uid;
    const ref = event.data.ref;

    try {
      await admin.auth().deleteUser(uid);
      logger.info(`Cuenta de Auth borrada: ${uid}`);
    } catch (err) {
      if (err.code === "auth/user-not-found") {
        logger.info(`Cuenta de Auth ${uid} ya no existía, se ignora.`);
      } else {
        logger.error(`Error borrando cuenta de Auth ${uid}:`, err);
        await ref.update({
          status: "error",
          error: err.message || String(err),
          processedAt: new Date().toISOString(),
        });
        return;
      }
    }

    await ref.update({
      status: "completed",
      processedAt: new Date().toISOString(),
    });
  }
);

/**
 * Limpieza periódica (diaria) de solicitudes ya completadas hace más de
 * 30 días, para que la colección 'auth_deletion_requests' no crezca sin
 * límite. Es solo housekeeping, no afecta la lógica de borrado.
 */
exports.cleanOldDeletionRequests = onSchedule("every 24 hours", async () => {
  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - 30);

  const snap = await db
    .collection("auth_deletion_requests")
    .where("status", "==", "completed")
    .where("processedAt", "<", cutoff.toISOString())
    .get();

  if (snap.empty) {
    logger.info("Sin solicitudes antiguas para limpiar.");
    return;
  }

  const batch = db.batch();
  snap.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();
  logger.info(`Limpiadas ${snap.size} solicitudes de borrado antiguas.`);
});
