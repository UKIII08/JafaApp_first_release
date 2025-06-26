// lib/screens/informacje_screen.dart
import 'package:flutter/material.dart';
// Usunięto import '../widgets/glowing_card_wrapper.dart';
// import 'package:flutter_markdown/flutter_markdown.dart';

class InformacjeScreen extends StatelessWidget {
  const InformacjeScreen({super.key});

  // --- Teksty (bez zmian) ---
  final String oJafieText =
      "Jafa Warszawa to katolicka wspólnota wielopokoleniowa, której misją jest służba dzieciom i młodzieży.";

  final String rodoText =
      "**Informacja RODO**\n\n"
      "Administratorem Twoich danych osobowych jest **Fundacja Jafa Warszawa**. Twoje dane są przetwarzane w celu umożliwienia logowania i korzystania z aplikacji „JafaApp”, zgodnie z art. 6 ust. 1 lit. a i f RODO.\n\n"
      "Masz prawo dostępu do swoich danych, ich poprawienia, usunięcia, ograniczenia przetwarzania, sprzeciwu wobec przetwarzania oraz prawo do wniesienia skargi do Prezesa Urzędu Ochrony Danych Osobowych.\n\n"
      "Kontakt: **jafawarszawa@gmail.com**";

  final String politykaPrywatnosciText =
      "## Polityka prywatności aplikacji „JafaApp”\n\n"
      "Niniejsza Polityka prywatności opisuje zasady przetwarzania danych osobowych w aplikacji mobilnej „JafaApp”.\n\n"
      "### 1. Administrator danych\n\n"
      "Administratorem danych osobowych jest: \n"
      "Fundacja Jafa Warszawa\n\n"
      "### 2. Jakie dane przetwarzamy?\n\n"
      "Aplikacja korzysta z Firebase Authentication firmy Google, co oznacza, że przy logowaniu możemy przetwarzać następujące dane:\n"
      "- Imię i nazwisko (jeśli dostępne w koncie Google),\n"
      "- Adres e-mail,\n"
      "- Zdjęcie profilowe (jeśli dostępne),\n"
      "- Identyfikator użytkownika.\n\n"
      "Dane są wykorzystywane wyłącznie w celu umożliwienia logowania oraz identyfikacji użytkowników w ramach funkcjonalności aplikacji.\n\n"
      "### 3. Cel i podstawa prawna przetwarzania\n\n"
      "Dane są przetwarzane w celu:\n"
      "- umożliwienia korzystania z aplikacji,\n"
      "- zapewnienia bezpieczeństwa i dostępu do funkcji społecznościowych.\n\n"
      "Podstawą prawną przetwarzania danych jest zgoda użytkownika (art. 6 ust. 1 lit. a RODO) oraz prawnie uzasadniony interes administratora (art. 6 ust. 1 lit. f RODO) – tj. zapewnienie funkcjonalności aplikacji.\n\n"
      "### 4. Odbiorcy danych\n\n"
      "Dane mogą być przekazywane firmie Google LLC w związku z korzystaniem z Firebase Authentication. Google działa jako podmiot przetwarzający dane na podstawie zawartych umów powierzenia przetwarzania danych.\n\n"
      "### 5. Czas przechowywania danych\n\n"
      "Dane są przechowywane przez czas korzystania z aplikacji. Użytkownik może w każdej chwili usunąć swoje konto oraz dane, kontaktując się z administratorem.\n\n"
      "### 6. Prawa użytkownika\n\n"
      "Użytkownik ma prawo do:\n"
      "- dostępu do swoich danych,\n"
      "- ich sprostowania, usunięcia lub ograniczenia przetwarzania,\n"
      "- wniesienia sprzeciwu wobec przetwarzania,\n"
      "- przenoszenia danych,\n"
      "- wniesienia skargi do Prezesa UODO.\n\n"
      "### 7. Dobrowolność podania danych\n\n"
      "Korzystanie z aplikacji wymaga logowania za pomocą konta Google. Podanie danych jest dobrowolne, ale niezbędne do korzystania z aplikacji.\n\n"
      "### 8. Zmiany polityki prywatności\n\n"
      "Polityka może być aktualizowana – nowa wersja będzie dostępna w aplikacji.\n\n"
      "---\n\n"
      "Jeśli masz pytania dotyczące ochrony danych osobowych, skontaktuj się z nami: \n"
      "jafawarszawa@gmail.com\n\n";

  final String umowaUzytkowaniaText =
      "# Umowa licencyjna użytkownika końcowego (EULA)\n\n"
      "Niniejsza umowa reguluje zasady korzystania z aplikacji mobilnej „JafaApp”, udostępnionej przez Fundację Jafa Warszawa.\n\n"
      "## 1. Definicje\n\n"
      "- „Aplikacja” – aplikacja mobilna „JafaApp”.\n"
      "- „Użytkownik” – osoba korzystająca z aplikacji.\n"
      "- „Fundacja” – Fundacja Jafa Warszawa, administrator aplikacji.\n\n"
      "## 2. Licencja\n\n"
      "Fundacja udziela Użytkownikowi niewyłącznej, odwołalnej, niezbywalnej i nieprzenoszalnej licencji na korzystanie z aplikacji wyłącznie w celach zgodnych z jej przeznaczeniem.\n\n"
      "## 3. Własność intelektualna\n\n"
      "Wszelkie treści i elementy aplikacji, takie jak grafiki, logo, kod źródłowy oraz inne materiały, stanowią własność Fundacji lub jej partnerów i są chronione prawem autorskim.\n\n"
      "Użytkownik nie może:\n"
      "- kopiować, modyfikować, dekompilować ani podejmować prób odtworzenia kodu źródłowego,\n"
      "- wykorzystywać aplikacji w sposób naruszający prawo, dobre obyczaje lub postanowienia niniejszej umowy.\n\n"
      "## 4. Dobrowolne płatności\n\n"
      "Korzystanie z aplikacji jest bezpłatne.\n\n"
      "Aplikacja może jednak udostępniać funkcjonalność umożliwiającą Użytkownikowi dokonywanie **dobrowolnych płatności (darowizn)** na rzecz Fundacji, np. w celu wspierania jej działalności.\n\n"
      "Wszelkie zasady dotyczące takich płatności (np. sposób realizacji, operator płatności, zasady zwrotów) będą opisane osobno – np. w polityce płatności dostępnej w aplikacji lub na stronie internetowej Fundacji.\n\n"
      "## 5. Odpowiedzialność\n\n"
      "Aplikacja jest udostępniana „tak jak jest” (as-is). Fundacja dokłada starań, aby działała poprawnie, ale:\n\n"
      "- nie gwarantuje jej nieprzerwanego, bezbłędnego działania,\n"
      "- nie ponosi odpowiedzialności za szkody wynikłe z jej użycia lub niemożności korzystania, z wyjątkiem sytuacji, w których szkoda została wyrządzona umyślnie.\n\n"
      "## 6. Zmiany umowy\n\n"
      "Fundacja może zaktualizować postanowienia niniejszej umowy. Nowa wersja będzie dostępna w aplikacji. Dalsze korzystanie z aplikacji oznacza akceptację zmian.\n\n"
      "## 7. Postanowienia końcowe\n\n"
      "- Prawem właściwym dla niniejszej umowy jest prawo polskie.\n"
      "- Spory wynikłe z korzystania z aplikacji będą rozstrzygane przez sąd właściwy dla siedziby Fundacji.\n\n"
      "Kontakt: **jafawarszawa@gmail.com**\n\n"
      "---\n\n"
      "Dziękujemy za korzystanie z JafaApp!";

  // --- KONIEC TEKSTÓW ---

  // Funkcja pomocnicza do budowania logo (bez zmian)
  Widget buildLogo(double height) {
    return Image.asset(
      'assets/logo.png', // Upewnij się, że ścieżka jest poprawna
      height: height,
      errorBuilder: (context, error, stackTrace) {
        print("Błąd ładowania logo w InformacjeScreen: $error");
        return SizedBox(
          height: height,
          child: const Center(
            child: Icon(Icons.image_not_supported, color: Colors.grey),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Pobierz motyw dla stylów
    // Definiujemy promień zaokrąglenia dla spójności
    final BorderRadius cardBorderRadius = BorderRadius.circular(12.0);
    // Definiujemy kolory gradientu (takie jak w HomeScreen)
    const List<Color> gradientColors = [
      Color.fromARGB(255, 109, 196, 223),
      Color.fromARGB(255, 133, 221, 235),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Informacje')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- ZMIANA: Sekcja "O Jafie" z gradientem ---
            Container(
              margin: const EdgeInsets.only(bottom: 24.0), // Odstęp
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  // Używamy gradientu
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: cardBorderRadius, // Zaokrąglenie
                boxShadow: [
                  // Subtelny cień
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    // Nagłówek
                    'O wspólnocie Jafa',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white, // Biały tekst na gradiencie
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    // Treść
                    oJafieText,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      height: 1.5,
                      color: Colors.white.withOpacity(
                        0.95,
                      ), // Lekko przezroczysty biały
                    ),
                  ),
                ],
              ),
            ),
            // --- KONIEC ZMIANY ---

            // Sekcja RODO (bez zmian w strukturze, tylko styl tytułu)
            ExpansionTile(
              title: Text(
                'Informacja RODO',
                style: theme.textTheme.titleMedium, // Użyto titleMedium
              ),
              leading: Icon(
                Icons.security_outlined,
                color: theme.colorScheme.secondary,
              ),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ).copyWith(top: 0, bottom: 16.0),
                  child: SelectableText(
                    rodoText,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                ),
              ],
            ),
            const Divider(height: 1),

            // Sekcja Polityka Prywatności (bez zmian w strukturze, tylko styl tytułu)
            ExpansionTile(
              title: Text(
                'Polityka Prywatności',
                style: theme.textTheme.titleMedium, // Użyto titleMedium
              ),
              leading: Icon(
                Icons.privacy_tip_outlined,
                color: theme.colorScheme.secondary,
              ),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ).copyWith(top: 0, bottom: 16.0),
                  child: SelectableText(
                    politykaPrywatnosciText,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                ),
              ],
            ),
            const Divider(height: 1),

            // Sekcja Regulamin Aplikacji (bez zmian w strukturze, tylko styl tytułu)
            ExpansionTile(
              title: Text(
                'Regulamin Aplikacji',
                style: theme.textTheme.titleMedium, // Użyto titleMedium
              ),
              leading: Icon(
                Icons.gavel_outlined,
                color: theme.colorScheme.secondary,
              ),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ).copyWith(top: 0, bottom: 16.0),
                  child: SelectableText(
                    umowaUzytkowaniaText,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                ),
              ],
            ),
            const Divider(height: 1),

            // Logo na dole (bez zmian)
            Padding(
              padding: const EdgeInsets.only(top: 32.0, bottom: 16.0),
              child: Center(child: buildLogo(60)),
            ),
          ],
        ),
      ),
    );
  }
}
