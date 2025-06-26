// lib/screens/wsparcie_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Potrzebne do obsługi schowka (Clipboard)
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/glowing_card_wrapper.dart';
// Usunięto importy dla Awesome Snackbar
// import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
// import '../utils/snackbar_helper.dart';

// Zmieniamy na StatefulWidget
class WsparcieScreen extends StatefulWidget {
  const WsparcieScreen({super.key});

  @override
  State<WsparcieScreen> createState() => _WsparcieScreenState();
}

class _WsparcieScreenState extends State<WsparcieScreen> {
  // Zmienne stanu do przechowywania danych i statusu ładowania
  String? _recipientName;
  String? _accountNumber;
  String? _transferTitleSuggestion;
  // String? _bankName;
  bool _isLoading = true;
  String? _loadingError;

  @override
  void initState() {
    super.initState();
    _fetchDonationInfo(); // Pobierz dane przy inicjalizacji
  }

  // Funkcja do pobierania danych z Firestore
  Future<void> _fetchDonationInfo() async {
    setState(() {
      _isLoading = true;
      _loadingError = null;
    });
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('config')
          .doc('donationInfo')
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        if (mounted) {
           setState(() {
             _recipientName = data?['recipientName'] as String? ?? '';
             _accountNumber = data?['accountNumber'] as String? ?? '';
             _transferTitleSuggestion = data?['transferTitleSuggestion'] as String? ?? '';
             // _bankName = data?['bankName'] as String?;
           });
        }
      } else {
        if (mounted) {
           setState(() {
             _loadingError = 'Nie znaleziono konfiguracji danych do przelewu.';
           });
           // Używamy standardowego SnackBara dla błędu
           ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: const Text('Błąd konfiguracji: Nie znaleziono danych do przelewu.'),
                  backgroundColor: Theme.of(context).colorScheme.error),
           );
        }
        print("Błąd: Dokument config/donationInfo nie istnieje.");
      }
    } catch (e) {
      print("Błąd podczas pobierania danych do przelewu: $e");
      if (mounted) {
         setState(() {
           _loadingError = 'Błąd ładowania danych.';
         });
         // Używamy standardowego SnackBara dla błędu
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: const Text('Błąd: Nie udało się załadować danych do przelewu.'),
                backgroundColor: Theme.of(context).colorScheme.error),
         );
      }
    } finally {
      if (mounted) {
         setState(() {
           _isLoading = false;
         });
      }
    }
  }

  // Funkcja pomocnicza do otwierania URL (bez zmian)
  // ...

  @override
  Widget build(BuildContext context) {
    final String accountNumberForClipboard = _accountNumber?.replaceAll(' ', '') ?? '';
    final BorderRadius cardBorderRadius = BorderRadius.circular(12.0);
    // Definiujemy kolory gradientu (takie jak w HomeScreen)
    const List<Color> gradientColors = [
      Color.fromARGB(255, 109, 196, 223),
      Color.fromARGB(255, 133, 221, 235),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wsparcie'),
      ),
      body: SingleChildScrollView(
        // Przywracamy padding poziomy dla całej zawartości
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Główny nagłówek w gradientowym kontenerze opakowanym w GlowingCardWrapper
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: GlowingCardWrapper(
                borderRadius: cardBorderRadius,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: cardBorderRadius,
                  ),
                  child: Text(
                    'Wesprzyj naszą działalność',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),

            // Podtytuł sekcji danych do przelewu (bez zmian)
              Text(
                'Dane do przelewu tradycyjnego:',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            const SizedBox(height: 20),

            // Sekcja danych ładowana dynamicznie
             _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _loadingError != null
                    ? Center(
                        child: Text(
                          _loadingError!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : (_recipientName == null || _accountNumber == null || _transferTitleSuggestion == null)
                        ? const Center(child: Text('Brak danych do przelewu.'))
                        : GlowingCardWrapper(
                            borderRadius: cardBorderRadius,
                            child: Card(
                              margin: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(borderRadius: cardBorderRadius),
                              clipBehavior: Clip.antiAlias,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildInfoRow(context, Icons.person_outline, "Odbiorca:", _recipientName!),
                                    const Divider(height: 24),
                                    // Przekazujemy context do buildAccountNumberRow
                                    _buildAccountNumberRow(context, _accountNumber!, accountNumberForClipboard),
                                    const Divider(height: 24),
                                    _buildInfoRow(context, Icons.title, "Sugerowany tytuł:", _transferTitleSuggestion!),
                                  ],
                                ),
                              ),
                            ),
                          ),
            // Koniec sekcji dynamicznej

            const SizedBox(height: 30),

            // Podziękowanie na dole (bez zmian)
              Center(
                child: Text(
                  'Dziękujemy za Twoje wsparcie!',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[700]
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 16), // Dodatkowy odstęp na dole
          ],
        ),
      ),
    );
  }

  // Helper widget dla zwykłych wierszy informacyjnych (bez zmian)
  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
              const SizedBox(height: 2),
              SelectableText(value, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

    // Helper widget specjalnie dla numeru konta z przyciskiem kopiowania
    Widget _buildAccountNumberRow(BuildContext context, String accountNumberDisplay, String accountNumberClipboard) {
      return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.account_balance_wallet_outlined, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Numer konta (IBAN):", style: TextStyle(fontSize: 14, color: Colors.grey[700])),
              const SizedBox(height: 2),
              SelectableText(
                accountNumberDisplay,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy_all_outlined),
          iconSize: 22,
          tooltip: 'Skopiuj numer konta',
          color: Theme.of(context).colorScheme.primary,
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.only(left: 12.0),
          splashRadius: 24,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: accountNumberClipboard));
            // --- PRZYWRÓCONO STANDARDOWY SNACKBAR ---
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Numer konta skopiowany do schowka!'),
                duration: Duration(seconds: 2),
                // Możesz dodać backgroundColor, jeśli chcesz inny niż domyślny
                // backgroundColor: Colors.green,
              ),
            );
            // ---------------------------------------
          },
        ),
      ],
    );
    }
}
