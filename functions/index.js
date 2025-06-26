// index.js – wersja kompatybilna z firebase-functions v6.x+

// Import modułów Firebase Functions v2 i Admin SDK
const functions = require("firebase-functions");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

// Inicjalizacja Firebase Admin SDK
initializeApp();

// Logger z v6+ (functions.logger)
const logger = functions.logger;

// --- Konfiguracja ---
const REGION = "europe-west10"; // Zaktualizuj, jeśli Twój region jest inny
const MEMORY = "256MiB";
const TIMEOUT = 60; // sekundy

// --- Funkcje pomocnicze ---
async function getFilteredFcmTokens(targetRole, logContext) {
  logger.debug(`[${logContext}] Pobieranie tokenów dla roli: ${targetRole || "wszyscy"}`);
  const tokens = new Set();
  try {
    const usersRef = getFirestore().collection("users");
    const allUsersSnapshot = await usersRef.get();

    allUsersSnapshot.forEach((doc) => {
      const user = doc.data();
      // Dostosowanie do targetRole - jeśli targetRole jest zdefiniowany, sprawdzamy, czy pole 'roles' (string) użytkownika mu odpowiada.
      // Jeśli targetRole nie jest zdefiniowany (wysyłka do wszystkich), to dodajemy tokeny, jeśli użytkownik ma jakiekolwiek.
      // UWAGA: Poniższa logika zakłada, że jeśli `targetRole` jest podany w `getFilteredFcmTokens`,
      // to `user.roles` (które jest stringiem) powinno być równe `targetRole`.
      // Jeśli `targetRole` jest dla "wszystkich", to `user.roles` nie jest filtrowane.
      let roleMatch = !targetRole; // Jeśli nie ma targetRole, pasuje (wszyscy)
      if (targetRole && typeof user.roles === 'string' && user.roles === targetRole) {
        roleMatch = true;
      }

      if (
        user &&
        roleMatch && // Używamy roleMatch do filtrowania
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
          let errorCode = "UNKNOWN_CODE";
          let errorMessage = "Unknown error";

          if (resp.error && typeof resp.error === 'object') {
            errorCode = resp.error.code || errorCode;
            errorMessage = resp.error.message || errorMessage;
          }
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

// --- Funkcje główne ---

exports.sendNotificationOnCreate = onDocumentCreated(
  {
    region: REGION,
    document: "{collection}/{documentId}",
    memory: MEMORY,
    timeoutSeconds: TIMEOUT,
  },
  async (event) => {
    const collection = event.params.collection;
    const documentId = event.params.documentId;
    const logContext = `sendNotificationOnCreate/${collection}/${documentId}`;

    logger.info(`[${logContext}] Funkcja wywołana.`);

    try {
      const handledCollections = ['ogloszenia', 'aktualnosci', 'events'];
      if (!handledCollections.includes(collection)) {
        logger.debug(`[${logContext}] Pomijam kolekcję '${collection}' (nieobsługiwana).`);
        return;
      }

      const docData = event.data?.data();
      if (!docData) {
        logger.warn(`[${logContext}] Brak danych w dokumencie.`);
        return;
      }

      let title = docData.title || "Nowa informacja";
      let body = "Sprawdź szczegóły";
      // Dla sendNotificationOnCreate, rola docelowa jest określana przez `docData.rolaDocelowa`
      // lub jest wysyłana do wszystkich, jeśli `rolaDocelowa` nie jest zdefiniowana.
      // Funkcja getFilteredFcmTokens obsłuży to odpowiednio.
      let targetRole = docData.rolaDocelowa; // Może być stringiem lub undefined

      if (collection === 'ogloszenia') {
        title = docData.title || "Nowe ogłoszenie";
        body = docData.content || body;
        // targetRole już ustawione z docData.rolaDocelowa
      } else if (collection === 'aktualnosci') {
        title = docData.title || "Nowe aktualności";
        body = docData.content || body;
        targetRole = undefined; // Aktualności idą do wszystkich
      } else if (collection === 'events') {
        title = docData.title || "Nowe wydarzenie";
        body = docData.description || body;
        targetRole = undefined; // Wydarzenia idą do wszystkich
      }

      logger.info(`[${logContext}] Przygotowanie powiadomienia: Tytuł='${title}', Rola docelowa='${targetRole || 'wszyscy'}'`);

      const notificationPayload = { title, body };
      const dataPayload = { sourceCollection: collection, sourceDocId: documentId, click_action: "FLUTTER_NOTIFICATION_CLICK" };

      const tokens = await getFilteredFcmTokens(targetRole, logContext);

      if (tokens.length > 0) {
        await sendFcmNotifications(tokens, notificationPayload, dataPayload, logContext);
      } else {
        logger.info(`[${logContext}] Brak tokenów do wysyłki dla roli '${targetRole || 'wszyscy'}'`);
      }

      logger.info(`[${logContext}] Zakończono przetwarzanie.`);
    } catch (error) {
      logger.error(`[${logContext}] Nieobsłużony błąd w sendNotificationOnCreate: ${error.message}`, error);
    }
  }
);

exports.sendManualNotification = onCall(
  {
    region: REGION,
    memory: MEMORY,
    timeoutSeconds: TIMEOUT,
    // enforceAppCheck: true, // Rozważ włączenie Firebase App Check
  },
  async (request) => {
    const logContext = "sendManualNotification";
    logger.info(`[${logContext}] Otrzymano żądanie.`);

    // 1. Sprawdzenie autentykacji
    if (!request.auth) {
      logger.warn(`[${logContext}] Próba wywołania przez nieuwierzytelnionego użytkownika.`);
      throw new HttpsError(
        "unauthenticated",
        "Musisz być zalogowany, aby wysłać powiadomienie."
      );
    }

    const uid = request.auth.uid;
    logger.info(`[${logContext}] Żądanie od uwierzytelnionego użytkownika: ${uid}`);

    // 2. Sprawdzenie autoryzacji (czy użytkownik ma pole roles: "Admin" w Firestore)
    let isAdmin = false;
    logger.info(`[${logContext}] Sprawdzanie roli "Admin" w Firestore dla użytkownika ${uid}.`);
    try {
      const userDocRef = getFirestore().collection("users").doc(uid);
      const userDoc = await userDocRef.get();

      if (userDoc.exists) {
        const userData = userDoc.data();
        // Sprawdzamy, czy pole 'roles' istnieje, jest stringiem i jest równe "Admin"
        // Ważna jest wielkość liter "Admin" - jeśli w bazie jest inaczej, trzeba dostosować.
        if (userData.roles && typeof userData.roles === 'string' && userData.roles === 'Admin') {
          isAdmin = true;
          logger.info(`[${logContext}] Użytkownik ${uid} zidentyfikowany jako admin na podstawie pola roles: "${userData.roles}" w Firestore.`);
        } else {
          logger.warn(`[${logContext}] Użytkownik ${uid} nie jest administratorem. Wartość pola 'roles': "${userData.roles === undefined ? 'undefined' : userData.roles}".`);
        }
      } else {
        logger.warn(`[${logContext}] Nie znaleziono dokumentu użytkownika dla UID: ${uid} w Firestore w kolekcji 'users'.`);
      }
    } catch (error) {
      logger.error(`[${logContext}] Błąd podczas sprawdzania roli "Admin" w Firestore dla ${uid}: ${error.message}`, error);
      throw new HttpsError("internal", "Błąd serwera podczas weryfikacji uprawnień.");
    }

    if (!isAdmin) {
      logger.error(`[${logContext}] Użytkownik ${uid} nie jest administratorem (wymagane pole roles: "Admin" w Firestore). Odmowa dostępu.`);
      throw new HttpsError(
        "permission-denied",
        "Nie masz uprawnień do wykonania tej operacji. Wymagana rola: Admin."
      );
    }

    logger.info(`[${logContext}] Użytkownik ${uid} jest autoryzowany jako administrator.`);

    // Walidacja danych wejściowych
    const { title, body, targetRole } = request.data || {}; // targetRole to string roli, do której wysyłamy, lub undefined/null dla wszystkich

    if (!title || typeof title !== 'string' || title.trim() === '') {
      logger.error(`[${logContext}] Nieprawidłowy tytuł od admina ${uid}.`, { data: request.data });
      throw new HttpsError('invalid-argument', 'Pole "title" jest wymagane i musi być niepustym tekstem.');
    }

    if (!body || typeof body !== 'string' || body.trim() === '') {
      logger.error(`[${logContext}] Nieprawidłowa treść od admina ${uid}.`, { data: request.data });
      throw new HttpsError('invalid-argument', 'Pole "body" jest wymagane i musi być niepustym tekstem.');
    }

    logger.info(`[${logContext}] Administrator ${uid} wysyła manualne powiadomienie: Tytuł='${title}', Treść='${body}', Rola docelowa='${targetRole || 'wszyscy'}'`);

    try {
      const notificationPayload = { title: title.trim(), body: body.trim() };
      const dataPayload = { triggeredBy: 'manual_admin', adminUid: uid, click_action: "FLUTTER_NOTIFICATION_CLICK" };

      // targetRole przekazany z request.data jest używany do filtrowania tokenów
      const tokens = await getFilteredFcmTokens(targetRole, `${logContext} (admin: ${uid})`);

      let fcmResponse = { successCount: 0, failureCount: 0 };
      if (tokens.length > 0) {
        fcmResponse = await sendFcmNotifications(tokens, notificationPayload, dataPayload, `${logContext} (admin: ${uid})`);
      } else {
        logger.info(`[${logContext}] Brak tokenów dla wskazanej roli ('${targetRole || 'wszyscy'}') przez admina ${uid}.`);
      }

      return {
        success: true,
        message: `Powiadomienie zostało przetworzone. Sukcesy=${fcmResponse.successCount}, Błędy=${fcmResponse.failureCount}.`,
        details: {
          successCount: fcmResponse.successCount,
          failureCount: fcmResponse.failureCount,
          targetedTokensCount: tokens.length,
          requestedRole: targetRole || 'wszyscy',
        },
      };
    } catch (error) {
      logger.error(`[${logContext}] Błąd podczas wysyłki manualnego powiadomienia przez admina ${uid}: ${error.message || String(error)}`, error);
      if (error instanceof HttpsError) {
        throw error;
      }
      throw new HttpsError('internal', 'Wewnętrzny błąd serwera podczas wysyłania powiadomienia.');
    }
  }
);