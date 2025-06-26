// lib/screens/wydarzenia_saturday_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'wydarzenie_detail_screen.dart'; // Import ekranu szczegółów
import '../widgets/glowing_card_wrapper.dart'; // Import wrappera dla poświaty

class WydarzeniaSaturdayScreen extends StatefulWidget {
  const WydarzeniaSaturdayScreen({super.key});

  @override
  State<WydarzeniaSaturdayScreen> createState() => _WydarzeniaSaturdayScreenState();
}

class _WydarzeniaSaturdayScreenState extends State<WydarzeniaSaturdayScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Funkcja _formatDate (taka sama jak w list_screen)
  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Brak daty';
    return DateFormat('dd.MM.yyyy HH:mm', 'pl_PL').format(timestamp.toDate());
  }

  // Funkcja _markAttendance (taka sama jak w list_screen)
  // Zakładamy, że zapis na spotkania sobotnie działa tak samo jak na inne wydarzenia
  Future<void> _markAttendance(String eventId, String userId, bool isAttending) async {
     if (userId.isEmpty) return;
    // Nadal odwołujemy się do kolekcji 'events'
    final eventRef = _firestore.collection('events').doc(eventId);
    try {
      if (isAttending) {
        await eventRef.update({'attendees.$userId': Timestamp.now()});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zapisano na spotkanie!'), backgroundColor: Colors.green));
        }
      } else {
        await eventRef.update({'attendees.$userId': FieldValue.delete()});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wypisano ze spotkania.'), backgroundColor: Colors.orange));
        }
      }
    } catch (e) {
      print("Błąd podczas zapisywania obecności na spotkanie sobotnie: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Wystąpił błąd: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
     final String? currentUserId = _auth.currentUser?.uid;

    // Zwracamy StreamBuilder, który pobiera dane z Firestore
    return StreamBuilder<QuerySnapshot>(
      // --- ZMIENIONE ZAPYTANIE DO FIRESTORE ---
      stream: _firestore
          .collection('events') // Nadal kolekcja 'events'
          .where('sobota', isEqualTo: true) // <<< DODANO FILTR: tylko te z polem sobota == true
          .where('eventDate', isGreaterThanOrEqualTo: Timestamp.now()) // Nadal tylko przyszłe
          .orderBy('eventDate', descending: false) // Sortowanie wg daty
          .snapshots(),
      // -----------------------------------------
      builder: (context, snapshot) {
        // Logika ładowania, błędów, braku danych (taka sama jak w list_screen)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          print("Błąd ładowania spotkań sobotnich: ${snapshot.error}");
          return const Center(child: Text('Nie można załadować spotkań sobotnich.'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Brak nadchodzących spotkań sobotnich.'));
        }

        final eventDocs = snapshot.data!.docs;

        // Używamy ListView.builder do wyświetlenia listy (taki sam jak w list_screen)
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 12.0), // Padding góra/dół
          itemCount: eventDocs.length,
          itemBuilder: (context, index) {
            // Pobieranie danych dokumentu (tak samo jak w list_screen)
            final eventDoc = eventDocs[index];
            final eventData = eventDoc.data() as Map<String, dynamic>? ?? {};
            final eventId = eventDoc.id;
            final title = eventData['title'] as String? ?? 'Spotkanie Sobotnie'; // Można zmienić domyślny tytuł
            final description = eventData['description'] as String? ?? '';
            final eventDate = eventData['eventDate'] as Timestamp?;
            final location = eventData['location'] as String?;
            final dynamic attendeesData = eventData['attendees'];
            final Map<String, dynamic> attendees = (attendeesData is Map)
                ? attendeesData.cast<String, dynamic>() : {};
            final bool isCurrentUserAttending = currentUserId != null && attendees.containsKey(currentUserId);

            // Używamy GlowingCardWrapper i Card (tak samo jak w list_screen)
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: GlowingCardWrapper(
                borderRadius: BorderRadius.circular(12.0),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WydarzenieDetailScreen(eventId: eventId),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12.0),
                  child: Card(
                    margin: EdgeInsets.zero,
                    // elevation i color brane z CardTheme
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- Wyświetlanie danych (tak samo jak w list_screen) ---
                          Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Row( children: [ Icon(Icons.calendar_today, size: 16, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 8), Text(_formatDate(eventDate), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500)), ], ),
                          const SizedBox(height: 6),
                          if (location != null && location.isNotEmpty) Padding( padding: const EdgeInsets.only(top: 4.0), child: Row( children: [ Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[600]), const SizedBox(width: 8), Expanded(child: Text(location, style: TextStyle(color: Colors.grey[700]))), ], ), ),
                          const SizedBox(height: 12),
                          if (description.isNotEmpty)
                            Text(
                              description,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[800]),
                              maxLines: 2, // Można pokazać więcej linii, jeśli chcesz
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 12),
                          // --- Sekcja obecności (tak samo jak w list_screen) ---
                           if (currentUserId != null)
                            Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Flexible( child: Text( isCurrentUserAttending ? 'Jesteś na liście!' : 'Bierzesz udział?', style: TextStyle( fontSize: 15, fontWeight: FontWeight.w500, color: isCurrentUserAttending ? Colors.green.shade700 : Theme.of(context).textTheme.bodyLarge?.color, ), ), ), Row( children: [ ElevatedButton( style: ElevatedButton.styleFrom( backgroundColor: isCurrentUserAttending ? Colors.grey[300] : Colors.green.shade600, foregroundColor: isCurrentUserAttending ? Colors.grey[700] : Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), textStyle: const TextStyle(fontSize: 14), ), onPressed: isCurrentUserAttending ? null : () => _markAttendance(eventId, currentUserId, true), child: const Text('Będę'), ), const SizedBox(width: 8), OutlinedButton( style: OutlinedButton.styleFrom( foregroundColor: Colors.red.shade700, side: BorderSide(color: isCurrentUserAttending ? Colors.red.shade300 : Colors.transparent), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), textStyle: const TextStyle(fontSize: 14), ), onPressed: isCurrentUserAttending ? () => _markAttendance(eventId, currentUserId, false) : null, child: const Text('Nie będę'), ), ], ), ], )
                           else
                             const Text( 'Zaloguj się, aby móc zaznaczyć obecność.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic), ),
                          // --- Koniec sekcji obecności ---
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
