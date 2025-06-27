// index.js – wersja kompatybilna z firebase-functions v2.x+

const functions = require("firebase-functions");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

const logger = functions.logger;
const db = getFirestore();

// --- Konfiguracja ---
const REGION = "europe-west3";
const MEMORY = "256MiB";
const TIMEOUT = 60;

// --- Funkcje pomocnicze (istniejące) ---
async function getFilteredFcmTokens(targetRole, logContext) {
  logger.debug(`[${logContext}] Pobieranie tokenów dla roli: ${targetRole || "wszyscy"}`);
  const tokens = new Set();
  try {
    const usersRef = db.collection("users");
    const allUsersSnapshot = await usersRef.get();

    allUsersSnapshot.forEach((doc) => {
      const user = doc.data();
      const roles = user.roles;
      const roleMatch = !targetRole || (Array.isArray(roles) && roles.includes(targetRole));

      if (
        user &&
        roleMatch &&
        Array.isArray(user.fcmTokens) &&
        user.fcmTokens.length > 0
      ) {
        user.fcmTokens.forEach((token) => {
          if (typeof token === "string" && token.length > 0) {
            tokens.add(token);
          }
        });
      }
    });
    logger.info(`[${logContext}] Znaleziono ${tokens.size} unikalnych tokenów dla roli "${targetRole || 'wszyscy'}".`);
  } catch (error) {
    logger.error(`[${logContext}] Błąd podczas pobierania tokenów użytkowników: ${error.message}`, error);
    throw error;
  }
  return Array.from(tokens);
}

async function sendFcmNotifications(tokens, notification, data = {}, logContext) {
    if (!Array.isArray(tokens) || tokens.length === 0) {
      logger.info(`[${logContext}] Brak tokenów do wysłania.`);
      return { successCount: 0, failureCount: 0, responses: [] };
    }
  
    logger.info(`[${logContext}] Wysyłanie do ${tokens.length} tokenów.`);
  
    const messagePayload = {
      tokens: tokens,
      notification: notification,
      data: data,
    };
  
    try {
      const response = await getMessaging().sendEachForMulticast(messagePayload);
      logger.info(`[${logContext}] FCM: Sukcesy=${response.successCount}, Błędy=${response.failureCount}`);
  
      if (response.failureCount > 0 && Array.isArray(response.responses)) {
        response.responses.forEach((resp, idx) => {
          if (resp && resp.success === false) {
            const failedToken = tokens[idx] || `unknown_token_${idx}`;
            const errorCode = resp.error?.code || "UNKNOWN_CODE";
            const errorMessage = resp.error?.message || "Unknown error";
            logger.warn(`[${logContext}] Błąd tokenu ${failedToken}: [${errorCode}] ${errorMessage}`);
          }
        });
      }
      return response;
    } catch (error) {
      logger.error(`[${logContext}] Błąd krytyczny przy FCM: ${error.message}`, error);
      throw error;
    }
}


// --- Funkcje główne (istniejące) ---

exports.sendNotificationOnCreate = onDocumentCreated(
  { region: REGION, document: "{collection}/{documentId}", memory: MEMORY, timeoutSeconds: TIMEOUT },
  async (event) => {
    const collection = event.params.collection;
    const documentId = event.params.documentId;
    const logContext = `sendNotificationOnCreate/${collection}/${documentId}`;
    logger.info(`[${logContext}] Funkcja wywołana.`);

    try {
      const handledCollections = ['ogloszenia', 'aktualnosci', 'events'];
      if (!handledCollections.includes(collection)) {
        return;
      }
      const docData = event.data?.data();
      if (!docData) {
        return;
      }
      let title = docData.title || "Nowa informacja";
      let body = "Sprawdź szczegóły";
      let targetRole = docData.rolaDocelowa;
      if (collection !== 'ogloszenia') {
        targetRole = undefined;
      }
      const notificationPayload = { title, body };
      const dataPayload = { sourceCollection: collection, sourceDocId: documentId, click_action: "FLUTTER_NOTIFICATION_CLICK" };
      const tokens = await getFilteredFcmTokens(targetRole, logContext);
      if (tokens.length > 0) {
        await sendFcmNotifications(tokens, notificationPayload, dataPayload, logContext);
      }
    } catch (error) {
      logger.error(`[${logContext}] Nieobsłużony błąd:`, error);
    }
  }
);

exports.sendManualNotification = onCall(
  { region: REGION, memory: MEMORY, timeoutSeconds: TIMEOUT },
  async (request) => {
    const logContext = "sendManualNotification";
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Musisz być zalogowany.");
    }
    const uid = request.auth.uid;
    const userDoc = await db.collection("users").doc(uid).get();
    const roles = userDoc.data()?.roles;
    if (!Array.isArray(roles) || !roles.includes("Admin")) {
      throw new HttpsError("permission-denied", "Brak uprawnień administratora.");
    }
    const { title, body, targetRole } = request.data || {};
    if (!title || typeof title !== 'string' || title.trim() === '') {
      throw new HttpsError('invalid-argument', 'Pole "title" jest wymagane.');
    }
    if (!body || typeof body !== 'string' || body.trim() === '') {
      throw new HttpsError('invalid-argument', 'Pole "body" jest wymagane.');
    }
    try {
      const notificationPayload = { title: title.trim(), body: body.trim() };
      const dataPayload = { triggeredBy: 'manual_admin', adminUid: uid, click_action: "FLUTTER_NOTIFICATION_CLICK" };
      const tokens = await getFilteredFcmTokens(targetRole, logContext);
      const fcmResponse = tokens.length > 0 ? await sendFcmNotifications(tokens, notificationPayload, dataPayload, logContext) : { successCount: 0, failureCount: 0 };
      return {
        success: true,
        message: `Powiadomienie przetworzone. Sukcesy=${fcmResponse.successCount}, Błędy=${fcmResponse.failureCount}.`,
      };
    } catch (error) {
      logger.error(`[${logContext}] Błąd wysyłki admina ${uid}:`, error);
      throw new HttpsError('internal', 'Wewnętrzny błąd serwera.');
    }
  }
);

exports.sendBirthdayNotifications = onSchedule(
  { schedule: "every day 09:00", timeZone: "Europe/Warsaw", region: REGION },
  async (event) => {
    const today = new Date();
    const day = today.getDate();
    const month = today.getMonth() + 1;
    const logContext = `sendBirthdayNotifications`;
    logger.info(`[${logContext}] Sprawdzanie urodzin dla: ${day}/${month}`);
    const usersRef = db.collection("users");
    const birthdayUsersSnap = await usersRef.where("birthMonth", "==", month).where("birthDay", "==", day).get();
    if (birthdayUsersSnap.empty) {
      return null;
    }
    const allUsersSnap = await usersRef.get();
    const allTokens = new Set();
    allUsersSnap.forEach(doc => {
      const user = doc.data();
      if (user.fcmTokens && Array.isArray(user.fcmTokens)) {
        user.fcmTokens.forEach(token => allTokens.add(token));
      }
    });
    const tokensToSend = Array.from(allTokens);
    if (tokensToSend.length === 0) {
      return null;
    }
    for (const userDoc of birthdayUsersSnap.docs) {
      const birthdayUser = userDoc.data();
      const userName = birthdayUser.displayName || 'Ktoś z naszej wspólnoty';
      const notificationPayload = { title: '🎉 Wszystkiego najlepszego! 🎉', body: `Dziś urodziny świętuje ${userName}! Złóż życzenia!` };
      const dataPayload = { type: 'BIRTHDAY', userId: userDoc.id, click_action: "FLUTTER_NOTIFICATION_CLICK" };
      await sendFcmNotifications(tokensToSend, notificationPayload, dataPayload, logContext);
    }
    return null;
  }
);


// <<< NOWA FUNKCJA DO AKTUALIZACJI ZNACZNIKA CZASU >>>
exports.updateBirthdayWallTimestamp = onDocumentCreated(
  {
    region: REGION,
    document: "birthdayWishes/{userId}/wishes/{wishId}",
  },
  async (event) => {
    const userId = event.params.userId;
    const logContext = `updateBirthdayWallTimestamp/${userId}`;
    logger.info(`[${logContext}] Nowe życzenie dodane. Aktualizowanie znacznika czasu.`);

    const wallRef = db.collection("birthdayWishes").doc(userId);
    try {
      await wallRef.set({
        lastUpdated: FieldValue.serverTimestamp(),
      }, { merge: true });
      logger.info(`[${logContext}] Znacznik czasu zaktualizowany pomyślnie.`);
    } catch (error) {
      logger.error(`[${logContext}] Błąd podczas aktualizacji znacznika czasu:`, error);
    }
  }
);

// <<< NOWA FUNKCJA DO AUTOMATYCZNEGO CZYSZCZENIA >>>
exports.cleanupOldWishes = onSchedule(
  {
    schedule: "every day 03:00",
    timeZone: "Europe/Warsaw",
    region: REGION,
  },
  async (event) => {
    const logContext = "cleanupOldWishes";
    logger.info(`[${logContext}] Rozpoczynanie czyszczenia starych tablic życzeń.`);

    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
    
    const oldWallsQuery = db.collection("birthdayWishes").where("lastUpdated", "<=", sevenDaysAgo);
    
    try {
      const snapshot = await oldWallsQuery.get();
      if (snapshot.empty) {
        logger.info(`[${logContext}] Nie znaleziono starych tablic do usunięcia.`);
        return null;
      }

      logger.info(`[${logContext}] Znaleziono ${snapshot.size} starych tablic do usunięcia.`);
      
      const promises = [];
      snapshot.forEach(doc => {
        promises.push(deleteCollection(db, `birthdayWishes/${doc.id}/wishes`, 100).then(() => {
          logger.info(`[${logContext}] Usunięto subkolekcję życzeń dla ${doc.id}.`);
          return doc.ref.delete();
        }));
      });

      await Promise.all(promises);
      logger.info(`[${logContext}] Zakończono czyszczenie pomyślnie.`);

    } catch (error) {
      logger.error(`[${logContext}] Wystąpił błąd podczas czyszczenia:`, error);
    }
    return null;
  }
);

// Funkcja pomocnicza do usuwania całej kolekcji (niezbędna)
async function deleteCollection(db, collectionPath, batchSize) {
  const collectionRef = db.collection(collectionPath);
  const query = collectionRef.orderBy('__name__').limit(batchSize);

  return new Promise((resolve, reject) => {
    deleteQueryBatch(db, query, resolve).catch(reject);
  });
}

async function deleteQueryBatch(db, query, resolve) {
  const snapshot = await query.get();

  if (snapshot.size === 0) {
    return resolve();
  }

  const batch = db.batch();
  snapshot.docs.forEach((doc) => {
    batch.delete(doc.ref);
  });

  await batch.commit();

  process.nextTick(() => {
    deleteQueryBatch(db, query, resolve);
  });
}
