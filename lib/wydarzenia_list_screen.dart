// lib/screens/wydarzenia_list_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'wydarzenie_detail_screen.dart'; // Import ekranu szczegółów
import '../widgets/glowing_card_wrapper.dart'; // <<< DODAJ IMPORT WRAPPERA

class WydarzeniaListScreen extends StatefulWidget {
  const WydarzeniaListScreen({super.key});

  @override
  State<WydarzeniaListScreen> createState() => _WydarzeniaListScreenState();
}

class _WydarzeniaListScreenState extends State<WydarzeniaListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Funkcja _formatDate (bez zmian)
  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Brak daty';
    return DateFormat('dd.MM.yyyy HH:mm', 'pl_PL').format(timestamp.toDate());
  }

  // Funkcja _markAttendance (bez zmian)
  Future<void> _markAttendance(String eventId, String userId, bool isAttending) async {
     if (userId.isEmpty) return;
    final eventRef = _firestore.collection('events').doc(eventId);
    try {
      if (isAttending) {
        await eventRef.update({'attendees.$userId': Timestamp.now()});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zapisano na wydarzenie!'), backgroundColor: Colors.green));
        }
      } else {
        await eventRef.update({'attendees.$userId': FieldValue.delete()});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wypisano z wydarzenia.'), backgroundColor: Colors.orange));
        }
      }
    } catch (e) {
      print("Błąd podczas zapisywania obecności: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Wystąpił błąd: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? currentUserId = _auth.currentUser?.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('events')
          .where('eventDate', isGreaterThanOrEqualTo: Timestamp.now())
          .orderBy('eventDate', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Można dodać Shimmer dla listy wydarzeń, jeśli chcesz
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          print("Błąd ładowania wydarzeń listy: ${snapshot.error}");
          return const Center(child: Text('Nie można załadować wydarzeń.'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Brak nadchodzących wydarzeń.'));
        }

        final eventDocs = snapshot.data!.docs;

        return ListView.builder(
          // Dodano padding tylko na górze i na dole, marginesy boczne są w wrapperze/cardTheme
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          itemCount: eventDocs.length,
          itemBuilder: (context, index) {
            // ... (definicje zmiennych eventData, eventId, title, etc. bez zmian) ...
            final eventDoc = eventDocs[index];
            final eventData = eventDoc.data() as Map<String, dynamic>? ?? {};
            final eventId = eventDoc.id;
            final title = eventData['title'] as String? ?? 'Bez tytułu';
            final description = eventData['description'] as String? ?? '';
            final eventDate = eventData['eventDate'] as Timestamp?;
            final location = eventData['location'] as String?;
            final dynamic attendeesData = eventData['attendees'];
            final Map<String, dynamic> attendees = (attendeesData is Map)
                ? attendeesData.cast<String, dynamic>() : {};
            final bool isCurrentUserAttending = currentUserId != null && attendees.containsKey(currentUserId);


            // --- ZASTOSOWANIE GlowingCardWrapper ---
            return Padding(
              // Dodajemy padding poziomy tutaj, aby wrapper miał przestrzeń
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: GlowingCardWrapper(
                borderRadius: BorderRadius.circular(12.0), // Dopasuj do Card
                child: InkWell( // InkWell wewnątrz wrappera
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WydarzenieDetailScreen(eventId: eventId),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12.0), // Nadal potrzebne dla InkWell
                  child: Card(
                    // color: Colors.white, // Niepotrzebne, jeśli jest w CardTheme
                    margin: EdgeInsets.zero, // Usunięto margines Card
                    // elevation: 0, // Można usunąć lub zmniejszyć cień Card
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)), // Kształt z CardTheme lub zdefiniowany tutaj
                    clipBehavior: Clip.antiAlias, // Z CardTheme lub zdefiniowany tutaj
                    child: Padding(
                      padding: const EdgeInsets.all(16.0), // Wewnętrzny padding karty
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- Zawartość karty (bez zmian) ---
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
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 12),
                           if (currentUserId != null)
                            Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Flexible( child: Text( isCurrentUserAttending ? 'Jesteś na liście!' : 'Bierzesz udział?', style: TextStyle( fontSize: 15, fontWeight: FontWeight.w500, color: isCurrentUserAttending ? Colors.green.shade700 : Theme.of(context).textTheme.bodyLarge?.color, ), ), ), Row( children: [ ElevatedButton( style: ElevatedButton.styleFrom( backgroundColor: isCurrentUserAttending ? Colors.grey[300] : Colors.green.shade600, foregroundColor: isCurrentUserAttending ? Colors.grey[700] : Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), textStyle: const TextStyle(fontSize: 14), ), onPressed: isCurrentUserAttending ? null : () => _markAttendance(eventId, currentUserId, true), child: const Text('Będę'), ), const SizedBox(width: 8), OutlinedButton( style: OutlinedButton.styleFrom( foregroundColor: Colors.red.shade700, side: BorderSide(color: isCurrentUserAttending ? Colors.red.shade300 : Colors.transparent), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), textStyle: const TextStyle(fontSize: 14), ), onPressed: isCurrentUserAttending ? () => _markAttendance(eventId, currentUserId, false) : null, child: const Text('Nie będę'), ), ], ), ], )
                           else
                             const Text( 'Zaloguj się, aby móc zaznaczyć obecność.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic), ),
                          // --- Koniec zawartości karty ---
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
            // --- KONIEC ZASTOSOWANIA GlowingCardWrapper ---
          },
        );
      },
    );
  }
}
