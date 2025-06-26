// lib/screens/wydarzenie_detail_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Dodano import
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart'; // Dodano import

class WydarzenieDetailScreen extends StatefulWidget {
  final String eventId;

  const WydarzenieDetailScreen({
    super.key,
    required this.eventId,
  });

  @override
  State<WydarzenieDetailScreen> createState() => _WydarzenieDetailScreenState();
}

class _WydarzenieDetailScreenState extends State<WydarzenieDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance; // Dodano instancję FirebaseAuth

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Brak daty';
    return DateFormat('dd.MM.yyyy HH:mm', 'pl_PL').format(timestamp.toDate());
  }

  Future<String> _fetchUserName(String userId) async {
    // Bez zmian
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        return data?['displayName'] as String? ?? data?['name'] as String? ?? 'Brak imienia';
      } else {
        return 'Użytkownik nieznaleziony';
      }
    } catch (e) {
      print('Błąd pobierania nazwy użytkownika $userId: $e');
      return 'Błąd';
    }
  }

  // --- NOWA FUNKCJA DO OTWIERANIA LINKU ---
  Future<void> _launchMapUrl(String? urlString) async {
    if (urlString == null || urlString.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Brak linku do mapy dla tego wydarzenia.')),
      );
      return;
    }

    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie można otworzyć linku: $urlString')),
      );
    }
  }
  // --- KONIEC NOWEJ FUNKCJI ---

  @override
  Widget build(BuildContext context) {
    final String? currentUserId = _auth.currentUser?.uid; // Pobranie ID aktualnego użytkownika

    return Scaffold(
      appBar: AppBar(
        title: const Text('Szczegóły wydarzenia'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('events').doc(widget.eventId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Błąd ładowania danych wydarzenia.'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Nie znaleziono wydarzenia.'));
          }

          final eventData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final title = eventData['title'] as String? ?? 'Bez tytułu';
          final description = eventData['description'] as String? ?? '';
          final eventDate = eventData['eventDate'] as Timestamp?;
          final location = eventData['location'] as String?;
          final googleMapsLink = eventData['googleMapsLink'] as String?; // Odczytanie linku do mapy

          final attendeesData = eventData['attendees'];
          final Map<String, dynamic> attendees = (attendeesData is Map)
              ? attendeesData.cast<String, dynamic>()
              : {};

          // Sprawdzenie, czy aktualny użytkownik jest na liście uczestników
          final bool isCurrentUserAttending = currentUserId != null && attendees.containsKey(currentUserId);

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row( children: [ Icon(Icons.calendar_today, size: 18, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 8), Text( _formatDate(eventDate), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500), ), ], ),
              const SizedBox(height: 8),
              if (location != null && location.isNotEmpty) Padding( padding: const EdgeInsets.only(top: 4.0), child: Row( children: [ Icon(Icons.location_on_outlined, size: 18, color: Colors.grey[700]), const SizedBox(width: 8), Expanded(child: Text(location, style: TextStyle(fontSize: 16, color: Colors.grey[800]))), ], ), ),

              // --- NOWY PRZYCISK MAPY (warunkowy) ---
              if (isCurrentUserAttending && googleMapsLink != null && googleMapsLink.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: ElevatedButton.icon(
                    onPressed: () => _launchMapUrl(googleMapsLink),
                    icon: Icon(Icons.map_outlined, color: Theme.of(context).colorScheme.onPrimary),
                    label: Text('Pokaż na mapie', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary, // Użyj koloru podstawowego motywu
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              // --- KONIEC NOWEGO PRZYCISKU MAPY ---

              const SizedBox(height: 16),
              if (description.isNotEmpty) Text(description, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5, fontSize: 16)),

              const SizedBox(height: 24),
              const Divider(thickness: 1),
              const SizedBox(height: 16),

              Text(
                'Lista uczestników (${attendees.length}):',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              if (attendees.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text('Nikt jeszcze się nie zapisał.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: attendees.keys.map((attendeeId) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: FutureBuilder<String>(
                        future: _fetchUserName(attendeeId),
                        builder: (context, nameSnapshot) {
                          // Reszta FutureBuilder bez zmian...
                          if (nameSnapshot.connectionState == ConnectionState.waiting) {
                            return Row(children: [ SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 1.5)), SizedBox(width: 8), Text('Ładowanie...', style: TextStyle(color: Colors.grey))]);
                          }
                           String fallbackText = 'Brak danych (ID: ${attendeeId.substring(0, math.min(6, attendeeId.length))}...)';
                           bool displayFallback = true;
                           if (nameSnapshot.hasError) {
                              fallbackText = 'Błąd (ID: ${attendeeId.substring(0, math.min(6, attendeeId.length))}...)';
                           } else if (!nameSnapshot.hasData || nameSnapshot.data!.isEmpty || ['Użytkownik nieznaleziony', 'Brak imienia', 'Błąd'].contains(nameSnapshot.data)) {
                               fallbackText = '${nameSnapshot.data ?? 'Brak danych'} (ID: ${attendeeId.substring(0, math.min(6, attendeeId.length))}...)';
                           } else {
                              displayFallback = false;
                           }

                          return Row(
                            children: [
                              Icon(Icons.person_outline, size: 18, color: Colors.grey[700]),
                              const SizedBox(width: 8),
                              Text(
                                displayFallback ? fallbackText : nameSnapshot.data!,
                                style: displayFallback
                                       ? const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 15)
                                       : const TextStyle(fontSize: 16),
                              ),
                            ],
                          );
                        },
                      ),
                    );
                  }).toList(),
                ),
            ],
          );
        },
      ),
    );
  }
}
