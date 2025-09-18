// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

// Importy dla zmiennych środowiskowych i opcji Firebase
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';

// Importy ekranów
import 'login_screen.dart';
import 'home_screen.dart';
import 'admin_screen.dart';

// Funkcja do tworzenia/aktualizacji dokumentu użytkownika w Firestore
Future<void> _createOrUpdateUserDocument(User user) async {
  final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
  final timestamp = FieldValue.serverTimestamp(); // Czas serwera dla spójności

  try {
    final docSnapshot = await userDocRef.get();
    Map<String, dynamic> dataToSet = {
      'email': user.email ?? '',
      'displayName': user.displayName ?? '',
      'photoURL': user.photoURL ?? '', // <<< DODANA LINIA
      'lastLogin': timestamp, // Zaktualizuj czas ostatniego logowania
    };
    // Jeśli dokument nie istnieje, dodaj pola początkowe
    if (!docSnapshot.exists) {
      dataToSet['createdAt'] = timestamp; // Czas utworzenia konta
      dataToSet['roles'] = []; // Domyślnie pusta lista ról
      dataToSet['fcmTokens'] = []; // Domyślnie pusta lista tokenów FCM
    }
    // Użyj set z merge:true, aby zaktualizować istniejące pola lub dodać nowe
    await userDocRef.set(dataToSet, SetOptions(merge: true));
    print("Dokument użytkownika stworzony/zaktualizowany dla ${user.uid}");
  } catch (e) {
    print("Błąd podczas tworzenia/aktualizacji dokumentu użytkownika: $e");
  }
}

// Handler dla wiadomości FCM otrzymanych w tle
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ważne: Inicjalizuj Firebase w tle, jeśli jeszcze nie jest zainicjalizowany
  // Musimy tutaj również załadować .env i opcje, aby to działało niezawodnie
  await dotenv.load(fileName: ".env");
  await DefaultFirebaseOptions.initialize();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  print("Handling a background message: ${message.messageId}");
  print("Message data: ${message.data}");
  if (message.notification != null) {
    print(
        'Message also contained a notification: ${message.notification?.title} / ${message.notification?.body}');
  }
}

// Główna funkcja aplikacji
void main() async {
  // Upewnij się, że widgety Flutter są zainicjalizowane
  WidgetsFlutterBinding.ensureInitialized();

  // === POCZĄTEK POPRAWIONEJ SEKCJI INICJALIZACJI ===

  // 1. Załaduj zmienne środowiskowe z pliku .env
  await dotenv.load(fileName: ".env");

  // 2. Zainicjalizuj opcje Firebase, które odczytają załadowane zmienne
  await DefaultFirebaseOptions.initialize();

  // 3. Teraz zainicjalizuj Firebase używając opcji dla bieżącej platformy
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // === KONIEC POPRAWIONEJ SEKCJI INICJALIZACJI ===

  // Inicjalizacja Remote Config
  try {
    final remoteConfig = FirebaseRemoteConfig.instance;
    await remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(minutes: 1),
      minimumFetchInterval: const Duration(hours: 1),
    ));
    await remoteConfig.setDefaults(const {
      "google_books_api_key": "TWOJ_DOMYSLNY_KLUCZ_API_LUB_PUSTY_STRING",
    });
    await remoteConfig.fetchAndActivate();
    print('Remote Config fetched and activated.');
  } catch (e) {
    print('Nie udało się zainicjalizować Firebase Remote Config: $e');
  }

  // Zainicjalizuj formatowanie dat dla języka polskiego
  await initializeDateFormatting('pl_PL', null);

  // Ustaw handler dla wiadomości FCM w tle
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Uruchom główny widget aplikacji
  runApp(const MyApp());
}

// Główny widget aplikacji
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Kolor bazowy nadal może być używany do generowania reszty schematu
    const Color seedColor = Color.fromARGB(255, 133, 221, 235);
    // Definiujemy DOKŁADNY kolor, którego chcemy użyć dla podświetlonych ikon
    const Color selectedIconColor = Color.fromARGB(255, 30, 197, 222);

    return MaterialApp(
      title: 'Jafa App',
      theme: ThemeData(
        // Użyj Material 3
        useMaterial3: true,
        // Schemat kolorów generowany z koloru bazowego
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor, // Nadal używamy seedColor do generowania reszty
        ),
        // Ustawienia globalne dla tła, AppBar, Drawer, BottomNav, Card
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1.0,
          surfaceTintColor: Colors.white,
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: Colors.white,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: selectedIconColor,
          unselectedItemColor: Colors.grey[600],
          elevation: 1.0,
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 3.0,
          margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12.0)),
          ),
          clipBehavior: Clip.antiAlias,
        ),
        // Ustawienie domyślnej czcionki dla całej aplikacji
        textTheme: GoogleFonts.senTextTheme(
            ThemeData(brightness: Brightness.light).textTheme),
      ),
      // Widget startowy, który obsługuje logikę uwierzytelniania
      home: const AuthWrapper(),
      // Ukryj baner "Debug" w prawym górnym rogu
      debugShowCheckedModeBanner: false,
    );
  }
}

// Widget obsługujący przełączanie między ekranem logowania a głównym ekranem aplikacji
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  // Funkcja pomocnicza do pobierania ról użytkownika z Firestore
  Future<List<String>> _getUserRoles(String userId) async {
    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        // Bezpieczne rzutowanie listy ról
        final roles = data?['roles'] as List<dynamic>?;
        return roles?.map((role) => role.toString()).toList() ?? [];
      } else {
        print("Dokument użytkownika $userId nie istnieje.");
        return []; // Zwróć pustą listę, jeśli dokument nie istnieje
      }
    } catch (e) {
      print('Błąd pobierania ról dla $userId: $e');
      return []; // Zwróć pustą listę w przypadku błędu
    }
  }

  @override
  Widget build(BuildContext context) {
    // Nasłuchuj na zmiany stanu uwierzytelnienia użytkownika
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Pokaż wskaźnik ładowania podczas oczekiwania na stan
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        // Pokaż błąd, jeśli wystąpił problem z odczytem stanu
        if (snapshot.hasError) {
          return const Scaffold(
              body: Center(
                  child: Text('Wystąpił błąd podczas sprawdzania logowania.')));
        }

        // Jeśli użytkownik jest zalogowany (snapshot.hasData)
        if (snapshot.hasData) {
          final user = snapshot.data!;
          // Wywołaj funkcję aktualizującą dane użytkownika w tle
          _createOrUpdateUserDocument(user);

          // Pobierz role użytkownika asynchronicznie
          return FutureBuilder<List<String>>(
            future: _getUserRoles(user.uid),
            builder: (context, rolesSnapshot) {
              // Pokaż wskaźnik ładowania podczas pobierania ról
              if (rolesSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                    body: Center(child: CircularProgressIndicator()));
              }
              // Jeśli wystąpił błąd pobierania ról, zaloguj go i pokaż HomeScreen
              if (rolesSnapshot.hasError) {
                print(
                    'Błąd pobierania ról w FutureBuilder: ${rolesSnapshot.error}');
                return const HomeScreen(); // Przejdź do HomeScreen jako fallback
              }

              // Pobierz listę ról (lub pustą listę, jeśli brak)
              final userRoles = rolesSnapshot.data ?? [];

              // Sprawdź, czy użytkownik ma rolę 'Admin'
              if (userRoles.contains('Admin')) {
                // Pokaż ekran administratora
                return const AdminScreen();
              } else {
                // Pokaż standardowy ekran główny
                return const HomeScreen();
              }
            },
          );
        }
        // Jeśli użytkownik nie jest zalogowany
        else {
          // Pokaż ekran logowania
          return const LoginScreen();
        }
      },
    );
  }
}