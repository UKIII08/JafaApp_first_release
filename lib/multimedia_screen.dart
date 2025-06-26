// lib/screens/multimedia_screen.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // Potrzebny do otwierania linków
import 'package:cloud_firestore/cloud_firestore.dart'; // <<< DODANO IMPORT FIRESTORE
import '../widgets/glowing_card_wrapper.dart';

// Zmieniamy na StatefulWidget, aby pobrać dane asynchronicznie
class MultimediaScreen extends StatefulWidget {
  const MultimediaScreen({super.key});

  @override
  State<MultimediaScreen> createState() => _MultimediaScreenState();
}

class _MultimediaScreenState extends State<MultimediaScreen> {
  // Zmienne stanu do przechowywania linku i statusu ładowania
  String? _dynamicDriveUrl;
  bool _isLoading = true;
  String? _loadingError; // Do przechowywania ewentualnego błędu

  @override
  void initState() {
    super.initState();
    _fetchDriveLink(); // Rozpocznij pobieranie linku przy inicjalizacji
  }

  // Funkcja do pobierania linku z Firestore
  Future<void> _fetchDriveLink() async {
    setState(() {
      _isLoading = true; // Rozpocznij ładowanie
      _loadingError = null; // Zresetuj błąd
    });
    try {
      // Odwołanie do dokumentu w Firestore
      final docSnapshot = await FirebaseFirestore.instance
          .collection('config') // Nazwa kolekcji
          .doc('photoDysk')     // Nazwa dokumentu
          .get();

      if (docSnapshot.exists) {
        // Pobierz dane dokumentu
        final data = docSnapshot.data();
        // Wyciągnij link z pola 'photoLink'
        final link = data?['photoLink'] as String?;

        if (link != null && link.isNotEmpty) {
          // Jeśli link istnieje i nie jest pusty, zapisz go w stanie
          if (mounted) { // Sprawdź, czy widget jest nadal zamontowany
             setState(() {
               _dynamicDriveUrl = link;
             });
          }
        } else {
          // Jeśli pole 'photoLink' jest puste lub go nie ma
           if (mounted) {
              setState(() {
                 _loadingError = 'Nie znaleziono linku w konfiguracji.';
              });
           }
          print("Błąd: Pole 'photoLink' jest puste lub nie istnieje w dokumencie config/photoDysk.");
        }
      } else {
        // Jeśli dokument 'photoDysk' nie istnieje
         if (mounted) {
            setState(() {
               _loadingError = 'Nie znaleziono konfiguracji folderu zdjęć.';
            });
         }
        print("Błąd: Dokument config/photoDysk nie istnieje w Firestore.");
      }
    } catch (e) {
      // Ogólny błąd podczas pobierania danych
      print("Błąd podczas pobierania linku z Firestore: $e");
       if (mounted) {
          setState(() {
             _loadingError = 'Błąd podczas ładowania konfiguracji.';
          });
       }
    } finally {
      // Zakończ ładowanie, niezależnie od wyniku
       if (mounted) {
          setState(() {
             _isLoading = false;
          });
       }
    }
  }


  // Funkcja pomocnicza do otwierania URL (bez zmian)
  Future<void> _launchURL(String urlString, BuildContext context) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch $url';
      }
    } catch (e) {
      print('Błąd otwierania URL: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nie można otworzyć linku: $urlString')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Definiujemy pożądany kolor ikony folderu i poświaty
    const Color primaryActionColor = Color.fromARGB(255, 133, 221, 235);
    // Definiujemy promień zaokrąglenia dla spójności
    final BorderRadius buttonBorderRadius = BorderRadius.circular(30.0); // Mocno zaokrąglony

    return Scaffold(
      appBar: AppBar(
        title: const Text("Multimedia"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.folder_shared_outlined,
                size: 80,
                color: primaryActionColor,
              ),
              const SizedBox(height: 24),
              const Text(
                "Wspólny Folder Zdjęć",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                "Kliknij przycisk poniżej, aby otworzyć folder na Dysku Google. Możesz tam przeglądać zdjęcia z wydarzeń oraz dodawać własne.",
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // Ostrzeżenie o bezpieczeństwie (bez zmian)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  "Pamiętaj: bądź odpowiedzialny za treści, które dodajesz.",
                  style: TextStyle(fontSize: 13, color: Colors.orange[800], fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 30),

              // --- Przycisk z logiką ładowania ---
              _isLoading
                  ? const CircularProgressIndicator() // Pokaż wskaźnik ładowania
                  : _loadingError != null
                      ? Text( // Pokaż błąd, jeśli wystąpił
                          _loadingError!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                          textAlign: TextAlign.center,
                        )
                      : GlowingCardWrapper( // Pokaż przycisk, jeśli załadowano bez błędu
                          borderRadius: buttonBorderRadius,
                          baseColor: primaryActionColor.withOpacity(0.8),
                          glowColor: primaryActionColor.withOpacity(1.0),
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.folder_open_outlined),
                            label: const Text("Otwórz folder ze zdjęciami"),
                            onPressed: () {
                              // Sprawdź, czy link został poprawnie załadowany
                              if (_dynamicDriveUrl != null && _dynamicDriveUrl!.isNotEmpty) {
                                _launchURL(_dynamicDriveUrl!, context);
                              } else {
                                // Ten komunikat nie powinien się pojawić, jeśli _loadingError jest null,
                                // ale zostawiamy jako zabezpieczenie.
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Nie udało się załadować linku do folderu.')),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              shape: RoundedRectangleBorder(
                                borderRadius: buttonBorderRadius,
                              ),
                            ),
                          ),
                        ),
              // --- Koniec przycisku ---
            ],
          ),
        ),
      ),
    );
  }
}