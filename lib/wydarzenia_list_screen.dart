// lib/screens/wydarzenia_list_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'wydarzenie_detail_screen.dart'; // Import ekranu szczegółów
import '../widgets/glowing_card_wrapper.dart'; // Import wrappera

// Helper class to unify all event types
class UnifiedEvent {
  final String id;
  final String title;
  final String type; // 'event', 'smallGroup', 'serviceMeeting'
  final DateTime date;
  final String? description;
  final String? location;
  final Map<String, dynamic> attendees;

  UnifiedEvent({
    required this.id,
    required this.title,
    required this.type,
    required this.date,
    this.description,
    this.location,
    this.attendees = const {},
  });
}


class WydarzeniaListScreen extends StatefulWidget {
  const WydarzeniaListScreen({super.key});

  @override
  State<WydarzeniaListScreen> createState() => _WydarzeniaListScreenState();
}

class _WydarzeniaListScreenState extends State<WydarzeniaListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  StreamSubscription? _streamSubscription;
  bool _isLoading = true;
  List<UnifiedEvent> _allEvents = [];

  @override
  void initState() {
    super.initState();
    _setupStreamsListener();
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }
  
  // --- NOWA LOGIKA POBIERANIA DANYCH ---

  Future<void> _setupStreamsListener() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userRoles = List<String>.from(userDoc.data()?['roles'] ?? []);
    
    // Definicja wszystkich strumieni danych
    Stream<QuerySnapshot> generalEventsStream = _firestore.collection('events').snapshots();
    Stream<QuerySnapshot> smallGroupStream = _firestore.collection('smallGroups').where('members', arrayContains: user.uid).limit(1).snapshots();
    List<Stream<QuerySnapshot>> serviceStreams = await _getServiceMeetingStreams(userRoles);

    List<Stream<dynamic>> allStreams = [generalEventsStream, smallGroupStream, ...serviceStreams];
    
    // Słuchaj zmian na połączonych strumieniach
    _streamSubscription = Stream.periodic(const Duration(seconds: 1)).asyncMap((_) {
      return Future.wait(allStreams.map((s) => s.first));
    }).listen((snapshots) {
      final allDocs = snapshots.expand((snapshot) => (snapshot as QuerySnapshot).docs).toList();
      _processAndUpdateEventList(allDocs);
    });
  }

  Future<List<Stream<QuerySnapshot>>> _getServiceMeetingStreams(List<String> userRoles) async {
    if (userRoles.isEmpty) return [];
    List<Stream<QuerySnapshot>> streams = [];
    final servicesSnapshot = await _firestore.collection('services').where('name', whereIn: userRoles).get();
    for (var serviceDoc in servicesSnapshot.docs) {
      streams.add(_firestore.collection('services').doc(serviceDoc.id).collection('meetings').snapshots());
    }
    return streams;
  }

  void _processAndUpdateEventList(List<QueryDocumentSnapshot> docs) {
      final newEvents = <UnifiedEvent>[];
      
      for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final String collectionName = doc.reference.parent.id;
          final String docId = doc.id;

          if (collectionName == 'smallGroups') {
              _addSmallGroupEvents(docId, data, newEvents);
          } else {
              _addGeneralEvent(docId, data, collectionName, newEvents);
          }
      }

      // Filtrowanie (tylko przyszłe wydarzenia) i sortowanie
      final today = DateTime.now();
      final midnightToday = DateTime(today.year, today.month, today.day);
      
      newEvents.removeWhere((event) => event.date.isBefore(midnightToday));
      newEvents.sort((a, b) => a.date.compareTo(b.date));

      if (mounted) {
          setState(() {
              _allEvents = newEvents;
              _isLoading = false;
          });
      }
  }

  void _addSmallGroupEvents(String id, Map<String, dynamic> data, List<UnifiedEvent> eventsList) {
      final tempDate = (data['temporaryMeetingDateTime'] as Timestamp?)?.toDate();
      DateTime? startOfWeekWithTempMeeting;
      if (tempDate != null) {
          startOfWeekWithTempMeeting = _getStartOfWeek(tempDate);
      }

      if (tempDate != null) {
          eventsList.add(UnifiedEvent(id: id, date: tempDate, title: 'Spotkanie małej grupy (jednorazowe)', type: 'smallGroup'));
      }

      final recurringDay = data['recurringMeetingDay'] as int?;
      final recurringTime = data['recurringMeetingTime'] as String?;

      if (recurringDay != null && recurringTime != null) {
          final recurringDates = _calculateRecurringMeetingDates(recurringDay, recurringTime);
          for (var date in recurringDates) {
              final startOfCurrentRecurringWeek = _getStartOfWeek(date);
              if (startOfWeekWithTempMeeting != null && startOfCurrentRecurringWeek.isAtSameMomentAs(startOfWeekWithTempMeeting)) {
                  continue;
              }
              eventsList.add(UnifiedEvent(id: id, date: date, title: 'Spotkanie małej grupy', type: 'smallGroup'));
          }
      }
  }

  void _addGeneralEvent(String id, Map<String, dynamic> data, String collectionName, List<UnifiedEvent> eventsList) {
      DateTime? eventDate;
      String title = "Brak tytułu";
      String type = "event";
      String? description, location;
      Map<String, dynamic> attendees = {};

      if(collectionName == 'events') {
        eventDate = (data['eventDate'] as Timestamp?)?.toDate(); // Używamy pola eventDate, które masz w kodzie
        title = data['title'] ?? 'Wydarzenie bez nazwy';
        type = 'event';
        description = data['description'];
        location = data['location'];
        attendees = (data['attendees'] is Map) ? (data['attendees'] as Map).cast<String, dynamic>() : {};
      } else if (collectionName == 'meetings') {
        eventDate = (data['date'] as Timestamp?)?.toDate(); // Tutaj może być inne pole
        title = data['title'] ?? 'Spotkanie służby';
        type = 'serviceMeeting';
      }
      
      if (eventDate != null) {
        eventsList.add(UnifiedEvent(id: id, date: eventDate, title: title, type: type, description: description, location: location, attendees: attendees));
      }
  }

  List<DateTime> _calculateRecurringMeetingDates(int weekDayNumber, String time) {
    List<DateTime> dates = [];
    final timeParts = time.split(':');
    if (timeParts.length != 2) return dates;
    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);
    if (hour == null || minute == null) return dates;

    DateTime today = DateTime.now();
    DateTime startDate = DateTime(today.year, today.month, 1);
    DateTime endDate = DateTime(today.year, today.month + 4, 1);

    for (var day = startDate; day.isBefore(endDate); day = day.add(const Duration(days: 1))) {
      if (day.weekday == weekDayNumber) {
        dates.add(DateTime(day.year, day.month, day.day, hour, minute));
      }
    }
    return dates;
  }

  DateTime _getStartOfWeek(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return normalizedDate.subtract(Duration(days: normalizedDate.weekday - 1));
  }
  
  // --- STARE FUNKCJE (BEZ ZMIAN) ---

  String _formatDate(DateTime date) {
    return DateFormat('dd.MM.yyyy HH:mm', 'pl_PL').format(date);
  }

  Future<void> _markAttendance(String eventId, String userId, bool isAttending) async {
    if (userId.isEmpty) return;
    final eventRef = _firestore.collection('events').doc(eventId);
    try {
      if (isAttending) {
        await eventRef.update({'attendees.$userId': Timestamp.now()});
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zapisano na wydarzenie!'), backgroundColor: Colors.green));
      } else {
        await eventRef.update({'attendees.$userId': FieldValue.delete()});
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wypisano z wydarzenia.'), backgroundColor: Colors.orange));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Wystąpił błąd: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? currentUserId = _auth.currentUser?.uid;

    return _isLoading
      ? const Center(child: CircularProgressIndicator())
      : _allEvents.isEmpty
        ? const Center(child: Text('Brak nadchodzących wydarzeń.'))
        : ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            itemCount: _allEvents.length,
            itemBuilder: (context, index) {
              final event = _allEvents[index];
              final bool isEvent = event.type == 'event';
              final bool isCurrentUserAttending = currentUserId != null && event.attendees.containsKey(currentUserId);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: GlowingCardWrapper(
                  borderRadius: BorderRadius.circular(12.0),
                  child: InkWell(
                    onTap: isEvent ? () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => WydarzenieDetailScreen(eventId: event.id)));
                    } : null, // Brak akcji dla spotkań grup i służb
                    borderRadius: BorderRadius.circular(12.0),
                    child: Card(
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(event.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            Row(children: [ Icon(Icons.calendar_today, size: 16, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 8), Text(_formatDate(event.date), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500)), ], ),
                            if (isEvent && event.location != null && event.location!.isNotEmpty) Padding( padding: const EdgeInsets.only(top: 6.0), child: Row( children: [ Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[600]), const SizedBox(width: 8), Expanded(child: Text(event.location!, style: TextStyle(color: Colors.grey[700]))), ], ), ),
                            const SizedBox(height: 12),
                            if (isEvent && event.description != null && event.description!.isNotEmpty)
                              Text(
                                event.description!,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[800]),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            
                            // Wyświetlaj przyciski tylko dla wydarzeń typu 'event'
                            if (isEvent) ...[
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 12),
                              if (currentUserId != null)
                                Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Flexible( child: Text( isCurrentUserAttending ? 'Jesteś na liście!' : 'Bierzesz udział?', style: TextStyle( fontSize: 15, fontWeight: FontWeight.w500, color: isCurrentUserAttending ? Colors.green.shade700 : Theme.of(context).textTheme.bodyLarge?.color, ), ), ), Row( children: [ ElevatedButton( style: ElevatedButton.styleFrom( backgroundColor: isCurrentUserAttending ? Colors.grey[300] : Colors.green.shade600, foregroundColor: isCurrentUserAttending ? Colors.grey[700] : Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), textStyle: const TextStyle(fontSize: 14), ), onPressed: isCurrentUserAttending ? null : () => _markAttendance(event.id, currentUserId, true), child: const Text('Będę'), ), const SizedBox(width: 8), OutlinedButton( style: OutlinedButton.styleFrom( foregroundColor: Colors.red.shade700, side: BorderSide(color: isCurrentUserAttending ? Colors.red.shade300 : Colors.transparent), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), textStyle: const TextStyle(fontSize: 14), ), onPressed: isCurrentUserAttending ? () => _markAttendance(event.id, currentUserId, false) : null, child: const Text('Nie będę'), ), ], ), ], )
                              else
                                const Text( 'Zaloguj się, aby móc zaznaczyć obecność.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic), ),
                            ]
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
  }
}