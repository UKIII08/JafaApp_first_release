// lib/screens/sluzba_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
// Potrzebne dla RotationTransition

// <<< Jeśli będziesz implementować Shimmer, dodaj import >>>
// import 'package:shimmer/shimmer.dart';

// --- KROK 1: Definicja niestandardowego widgetu ---
class CustomGradientExpansionTile extends StatefulWidget {
  final String title;
  final List<Widget> children;
  final List<Color> gradientColors;
  final EdgeInsets childrenPadding;
  final CrossAxisAlignment expandedCrossAxisAlignment;
  final Duration animationDuration;
  final Key? expansionKey; // Dodajemy klucz

  const CustomGradientExpansionTile({
    required this.title,
    required this.children,
    required this.gradientColors,
    this.childrenPadding = const EdgeInsets.all(16.0),
    this.expandedCrossAxisAlignment = CrossAxisAlignment.center,
    this.animationDuration = const Duration(milliseconds: 200),
    this.expansionKey, // Przypisujemy klucz
    super.key,
  });

  @override
  State<CustomGradientExpansionTile> createState() => _CustomGradientExpansionTileState();
}

class _CustomGradientExpansionTileState extends State<CustomGradientExpansionTile> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _iconTurns;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.animationDuration, vsync: this);
    _iconTurns = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
     // Sprawdzenie stanu początkowego na podstawie klucza PageStorage
     if (widget.expansionKey != null) {
       _isExpanded = PageStorage.of(context).readState(context, identifier: widget.expansionKey) as bool? ?? false;
       if (_isExpanded) {
         _controller.value = 1.0; // Ustawia ikonę w pozycji rozwiniętej
       }
     }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
       // Zapisz stan do PageStorage
       if (widget.expansionKey != null) {
         PageStorage.of(context).writeState(context, _isExpanded, identifier: widget.expansionKey);
       }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Nagłówek z gradientem
    Widget header = InkWell(
      onTap: _handleTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: widget.gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0), // Dopasuj padding
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white, // Biały tekst
                ),
              ),
            ),
            RotationTransition(
              turns: _iconTurns,
              child: const Icon(
                Icons.expand_more,
                color: Colors.white, // Biała ikona
              ),
            ),
          ],
        ),
      ),
    );

    // Rozwijana zawartość
    Widget expandableContent = AnimatedCrossFade(
      firstChild: Container(height: 0.0), // Pusty kontener, gdy zwinięte
      secondChild: Container(
          color: theme.cardColor, // Upewnij się, że tło dzieci jest białe/kolor karty
          width: double.infinity, // Pełna szerokość
          padding: widget.childrenPadding,
          child: Column(
            crossAxisAlignment: widget.expandedCrossAxisAlignment,
            children: widget.children,
          ),
        ),
      crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      duration: widget.animationDuration,
      sizeCurve: Curves.easeInOut, // Animacja zmiany rozmiaru
      firstCurve: Curves.easeInOut,
      secondCurve: Curves.easeInOut,
    );


    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        header,
        ClipRect( // ClipRect może pomóc w animacji rozmiaru
          child: expandableContent,
        ),
      ],
    );
  }
}
// --- Koniec niestandardowego widgetu ---


class SluzbaScreen extends StatefulWidget {
  const SluzbaScreen({super.key});

  @override
  State<SluzbaScreen> createState() => _SluzbaScreenState();
}

class _SluzbaScreenState extends State<SluzbaScreen> {
  bool _isLoading = true;
  List<String> _userRoles = [];

  @override
  void initState() {
    super.initState();
    _fetchUserRoles();
  }

  // _fetchUserRoles - BEZ ZMIAN
  Future<void> _fetchUserRoles() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { if (mounted) { setState(() { _isLoading = false; _userRoles = []; }); } print("Błąd: Użytkownik niezalogowany na ekranie Służba."); return; }
    final userId = user.uid; print("Pobieranie ról dla użytkownika: $userId");
    try { final userDoc = await FirebaseFirestore.instance .collection('users') .doc(userId) .get(); if (userDoc.exists && mounted) { final data = userDoc.data(); final rolesFromDb = data?['roles']; if (rolesFromDb is List) { _userRoles = rolesFromDb.whereType<String>().toList(); print("Pobrane role: $_userRoles"); } else { print("Pole 'roles' nie znalezione lub nie jest listą dla użytkownika $userId."); _userRoles = []; } } else if (mounted) { print("Dokument użytkownika $userId nie istnieje."); _userRoles = []; } } catch (e) { print("Błąd podczas pobierania ról użytkownika: $e"); if (mounted) { _userRoles = []; } } finally { if (mounted) { setState(() { _isLoading = false; }); } }
  }

  // _buildNoRolesView - BEZ ZMIAN
  Widget _buildNoRolesView(BuildContext context) {
    return Center( child: Padding( padding: const EdgeInsets.all(20.0), child: Column( mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [ Icon( Icons.info_outline, size: 60, color: Colors.grey[400], ), const SizedBox(height: 20), const Text( "Nie jesteś jeszcze nigdzie zaangażowany?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600), textAlign: TextAlign.center, ), const SizedBox(height: 10), Text( "Wypełnij formularz zgłoszeniowy, a my włączymy Cię do służby!", style: TextStyle(fontSize: 16, color: Colors.grey[600]), textAlign: TextAlign.center, ), const SizedBox(height: 30), ElevatedButton.icon( icon: const Icon(Icons.description_outlined), label: const Text("Wypełnij formularz"), onPressed: _handleFormAction, style: ElevatedButton.styleFrom( padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15), textStyle: const TextStyle(fontSize: 16), ), ), ], ), ), );
  }

  // --- ZMIANA TUTAJ: Użycie CustomGradientExpansionTile ---
  Widget _buildRolesView(BuildContext context) {
    // Definiujemy kolory gradientu pobrane z home_screen.dart
    const List<Color> gradientColors = [
      Color.fromARGB(255, 109, 196, 223),
      Color.fromARGB(255, 133, 221, 235),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(12.0), // Padding dla całej listy
      itemCount: _userRoles.length,
      itemBuilder: (context, index) {
        final role = _userRoles[index]; // Nazwa bieżącej roli

        // Używamy Card jako kontenera, ale wewnątrz niego nasz niestandardowy widget
        return Card(
          elevation: 1.5,
          margin: const EdgeInsets.only(bottom: 12.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          // Ważne: ClipBehavior przycina zawartość (w tym nasz tile) do kształtu karty
          clipBehavior: Clip.antiAlias,
          child: CustomGradientExpansionTile( // Używamy naszego widgetu
             expansionKey: PageStorageKey<String>(role), // Przekazujemy klucz dla PageStorage
             title: role,
             gradientColors: gradientColors,
             childrenPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0).copyWith(top: 8.0),
             expandedCrossAxisAlignment: CrossAxisAlignment.start,
             children: [
               // Zawartość ExpansionTile: Ogłoszenia, Divider, Materiały

               // --- Sekcja Ogłoszeń ---
               _buildSectionTitle(context, "Ogłoszenia"),
               const SizedBox(height: 8),
               StreamBuilder<QuerySnapshot>(
                 stream: FirebaseFirestore.instance
                     .collection('ogloszenia')
                     .where('rolaDocelowa', isEqualTo: role)
                     .orderBy('publishDate', descending: true)
                     .snapshots(),
                 builder: (context, announcementSnapshot) {
                   // Logika ładowania, błędów, braku danych - BEZ ZMIAN
                    if (announcementSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: Padding( padding: EdgeInsets.symmetric(vertical: 16.0), child: CircularProgressIndicator(strokeWidth: 2.0), ));
                   }
                   if (announcementSnapshot.hasError) {
                     print("Błąd pobierania ogłoszeń dla roli '$role': ${announcementSnapshot.error}");
                     return _buildErrorText('Nie można załadować ogłoszeń.');
                   }
                   if (!announcementSnapshot.hasData || announcementSnapshot.data!.docs.isEmpty) {
                     return _buildNoDataText("Brak aktualnych ogłoszeń.");
                   }
                   final announcementDocs = announcementSnapshot.data!.docs;
                   // Wyświetlanie ogłoszeń
                   return Column(
                     children: announcementDocs.map((doc) {
                       final data = doc.data() as Map<String, dynamic>? ?? {};
                       final title = data['title'] as String? ?? 'Brak tytułu';
                       final content = data['content'] as String? ?? 'Brak treści';
                       final timestamp = data['publishDate'] as Timestamp?;
                       String formattedDate = '';
                       if (timestamp != null) {
                         formattedDate = DateFormat('dd.MM.yyyy HH:mm').format(timestamp.toDate());
                       }
                       return Card(
                         elevation: 0.5,
                         // *** ZMIENIONY KOLOR TŁA ***
                         color: Theme.of(context).colorScheme.surfaceContainerLow,
                         // Alternatywy (jeśli powyższe nie pasuje):
                         // color: Theme.of(context).colorScheme.surfaceContainerLowest,
                         // color: Colors.grey[100],
                         // color: Colors.grey[200],
                         // *****************************
                         margin: const EdgeInsets.only(bottom: 12.0),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                         child: Padding(
                           padding: const EdgeInsets.all(12.0),
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.stretch, // Pozostaje stretch
                             children: [
                               Text( title, style: Theme.of(context).textTheme.titleMedium?.copyWith( fontWeight: FontWeight.bold, ), ),
                               if (formattedDate.isNotEmpty)
                                 Padding( padding: const EdgeInsets.only(top: 4.0, bottom: 8.0), child: Text( formattedDate, style: TextStyle( fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7)), ), )
                               else if (content.isNotEmpty)
                                 const SizedBox(height: 8), // Dodaj odstęp jeśli nie ma daty, a jest treść
                               Text( content, style: Theme.of(context).textTheme.bodyMedium, ),
                             ],
                           ),
                         ),
                       );
                     }).toList(),
                   );
                 },
               ), // Koniec StreamBuilder Ogłoszeń

               const Divider(height: 24.0, thickness: 0.5),

               // --- Sekcja Materiałów ---
               _buildSectionTitle(context, "Materiały"),
               const SizedBox(height: 8),
               StreamBuilder<QuerySnapshot>(
                 stream: FirebaseFirestore.instance
                     .collection('materialy')
                     .where('rolaDocelowa', isEqualTo: role)
                     .orderBy('uploadDate', descending: true)
                     .snapshots(),
                 builder: (context, snapshot) {
                   // Logika ładowania, błędów, braku danych - BEZ ZMIAN
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: Padding( padding: EdgeInsets.symmetric(vertical: 16.0), child: CircularProgressIndicator(strokeWidth: 2.0), ));
                   }
                   if (snapshot.hasError) {
                     print("Błąd pobierania materiałów dla roli '$role': ${snapshot.error}");
                     return _buildErrorText('Nie można załadować materiałów.');
                   }
                   if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                     return _buildNoDataText("Brak dostępnych materiałów.");
                   }
                   final materialDocs = snapshot.data!.docs;
                   // Wyświetlanie materiałów - BEZ ZMIAN
                   return Column(
                     children: materialDocs.map((doc) {
                       final data = doc.data() as Map<String, dynamic>? ?? {};
                       final title = data['title'] as String? ?? 'Brak tytułu';
                       final linkUrl = data['linkUrl'] as String?;
                       final description = data['description'] as String?;
                       return ListTile(
                         leading: Icon(Icons.link, color: Theme.of(context).colorScheme.primary),
                         title: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500)),
                         subtitle: description != null ? Text(description, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall) : null,
                         trailing: Icon(Icons.arrow_forward_ios, size: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                         onTap: linkUrl != null ? () => _launchURL(linkUrl) : null,
                         enabled: linkUrl != null,
                         dense: true,
                         contentPadding: EdgeInsets.zero,
                       );
                     }).toList(),
                   );
                 },
               ), // Koniec StreamBuilder Materiałów
               const SizedBox(height: 8),
             ], // Koniec children CustomGradientExpansionTile
           ), // Koniec CustomGradientExpansionTile
        ); // Koniec Card
      }, // Koniec itemBuilder
    ); // Koniec ListView.builder
  }


  // --- Helper Widgets - BEZ ZMIAN ---
  Widget _buildSectionTitle(BuildContext context, String title) {
    IconData sectionIcon = title == "Ogłoszenia" ? Icons.campaign_outlined : Icons.article_outlined;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(sectionIcon, size: 20, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.secondary,
                ),
          ),
        ],
      ),
    );
  }

 Widget _buildErrorText(String message) {
   return Padding(
     padding: const EdgeInsets.symmetric(vertical: 16.0),
     child: Row(
       mainAxisAlignment: MainAxisAlignment.center,
       children: [
         Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 18),
         const SizedBox(width: 8),
         Text(message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
       ],
     ),
   );
 }

 Widget _buildNoDataText(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
         mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), size: 18),
          const SizedBox(width: 8),
          Text(message, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
        ],
      ),
    );
  }
  // --- Koniec Helper Widgets ---

  // _launchURL - BEZ ZMIAN
  Future<void> _launchURL(String? urlString) async {
    if (urlString == null) return;
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch $url';
      }
    } catch (e) {
      print('Błąd otwierania URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nie można otworzyć linku: $urlString')),
        );
      }
    }
  }

  // _handleFormAction - BEZ ZMIAN
  void _handleFormAction() async {
    print("Przycisk formularza naciśnięty!");
    const String googleFormUrl = 'https://docs.google.com/forms/d/e/1FAIpQLSd9YNdZei9U0HnEs9ApPm6_mDcTuWJjN7sycOj9cxz2fENlng/viewform?usp=dialog';
    await _launchURL(googleFormUrl);
  }

  // build - BEZ ZMIAN
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Służba"),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0.5,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userRoles.isEmpty
              ? _buildNoRolesView(context)
              : _buildRolesView(context),
    );
  }
}