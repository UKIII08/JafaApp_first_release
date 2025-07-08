import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:async/async.dart';

// Model wydarzenia (bez zmian)
class _Event {
  final String title;
  final String type;
  _Event(this.title, this.type);
}

class WydarzeniaCalendarScreen extends StatefulWidget {
  const WydarzeniaCalendarScreen({super.key});

  @override
  State<WydarzeniaCalendarScreen> createState() => _WydarzeniaCalendarScreenState();
}

class _WydarzeniaCalendarScreenState extends State<WydarzeniaCalendarScreen> {
  // Stan kalendarza
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  // Strumień i dane
  Stream<dynamic>? _combinedStream;
  final Map<DateTime, List<_Event>> _eventsByDate = {};

  // Osobne "pamięci podręczne" dla każdego typu danych
  List<QueryDocumentSnapshot> _generalEventsCache = [];
  DocumentSnapshot? _smallGroupDataCache;
  final Map<String, List<QueryDocumentSnapshot>> _serviceMeetingsCache = {};


  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _setupEventStream();
  }
  
  void _setupEventStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    // Pobieramy role użytkownika, aby wiedzieć, które służby go dotyczą
    FirebaseFirestore.instance.collection('users').doc(user.uid).get().then((userDoc) async {
      if (!mounted) return;
      
      final List<String> userRoles = List<String>.from(userDoc.data()?['roles'] ?? []);
      
      // 1. Strumień ogólnych wydarzeń
      Stream<QuerySnapshot> generalEventsStream = FirebaseFirestore.instance.collection('events').snapshots();
      
      // 2. Strumień małej grupy użytkownika
      Stream<QuerySnapshot> smallGroupStream = FirebaseFirestore.instance
        .collection('smallGroups')
        .where('members', arrayContains: user.uid)
        .limit(1)
        .snapshots();
        
      // 3. Strumienie spotkań dla służb użytkownika
      List<Stream<QuerySnapshot>> serviceMeetingStreams = [];
      if (userRoles.isNotEmpty) {
        final servicesSnapshot = await FirebaseFirestore.instance.collection('services').where('name', whereIn: userRoles).get();
        for (var serviceDoc in servicesSnapshot.docs) {
            serviceMeetingStreams.add(
              FirebaseFirestore.instance.collection('services').doc(serviceDoc.id).collection('meetings').snapshots()
            );
        }
      }

      // Łączymy wszystkie POTRZEBNE strumienie w jeden.
      setState(() {
        _combinedStream = StreamGroup.merge([
          generalEventsStream,
          smallGroupStream,
          ...serviceMeetingStreams,
        ]).asBroadcastStream();
      });
    });
  }

  // Funkcja, która aktualizuje odpowiedni cache na podstawie danych ze strumienia
  void _updateCacheAndRebuild(AsyncSnapshot<dynamic> snapshot) {
    if (snapshot.data is QuerySnapshot) {
      final querySnapshot = snapshot.data as QuerySnapshot;
      if (querySnapshot.docs.isEmpty) return; // Ignoruj puste aktualizacje

      final path = querySnapshot.docs.first.reference.path;
      
      if (path.startsWith('events')) { _generalEventsCache = querySnapshot.docs; } 
      else if (path.startsWith('smallGroups')) { _smallGroupDataCache = querySnapshot.docs.first; } 
      else if (path.contains('/meetings/')) {
        final serviceId = path.split('/')[1];
        _serviceMeetingsCache[serviceId] = querySnapshot.docs;
      }
    }
    
    // Po każdej aktualizacji cache, przebuduj całą mapę od zera
    _rebuildEventMap();
  }

  void _rebuildEventMap() {
    _eventsByDate.clear();

    // 1. Przetwarzanie wydarzeń ogólnych z cache
    for (var doc in _generalEventsCache) {
      final data = doc.data() as Map<String, dynamic>;
      final date = (data['eventDate'] as Timestamp).toDate();
      final dayOnly = DateTime.utc(date.year, date.month, date.day);
      _eventsByDate.putIfAbsent(dayOnly, () => []).add(_Event(data['title'], 'event'));
    }

    // 2. Przetwarzanie spotkań służb z cache
    _serviceMeetingsCache.forEach((serviceId, meetings) {
      for (var doc in meetings) {
        final data = doc.data() as Map<String, dynamic>;
        final date = (data['date'] as Timestamp).toDate();
        final dayOnly = DateTime.utc(date.year, date.month, date.day);
        _eventsByDate.putIfAbsent(dayOnly, () => []).add(_Event("Służba: ${data['title']}", 'serviceMeeting'));
      }
    });
    
    // 3. Przetwarzanie małych grup z cache
    if (_smallGroupDataCache != null) {
      final data = _smallGroupDataCache!.data() as Map<String, dynamic>;
      final groupName = data['groupName'] ?? 'Mała Grupa';
      final temporaryMeetingTimestamp = data['temporaryMeetingDateTime'] as Timestamp?;
      bool temporaryMeetingAdded = false;

      if (temporaryMeetingTimestamp != null) {
        final temporaryDate = temporaryMeetingTimestamp.toDate();
        if (temporaryDate.isAfter(DateTime.now().subtract(const Duration(days: 1)))) {
          final dayOnly = DateTime.utc(temporaryDate.year, temporaryDate.month, temporaryDate.day);
          _eventsByDate.putIfAbsent(dayOnly, () => []).add(_Event('Mała grupa (jednorazowo)', 'smallGroup'));
          temporaryMeetingAdded = true;
        }
      } 
      
      if (!temporaryMeetingAdded) {
        final recurringDay = data['recurringMeetingDay'] as int?;
        if (recurringDay != null) {
          for (int i = 0; i < 60; i++) {
            DateTime dateToCheck = DateTime.now().add(Duration(days: i));
            if (dateToCheck.weekday == recurringDay) {
              final dayOnly = DateTime.utc(dateToCheck.year, dateToCheck.month, dateToCheck.day);
              _eventsByDate.putIfAbsent(dayOnly, () => []);
              if (!_eventsByDate[dayOnly]!.any((e) => e.type == 'smallGroup')) {
                 _eventsByDate[dayOnly]!.add(_Event('Mała grupa: $groupName', 'smallGroup'));
              }
            }
          }
        }
      }
    }
  }
  
  List<_Event> _getEventsForDay(DateTime day) {
    return _eventsByDate[DateTime.utc(day.year, day.month, day.day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          StreamBuilder<dynamic>(
            stream: _combinedStream,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                // Bezpiecznie aktualizuj dane i przebuduj mapę
                _updateCacheAndRebuild(snapshot);
              }
              // Ten StreamBuilder nie buduje niczego widocznego,
              // służy tylko do aktualizacji danych w tle.
              // Widoczny UI jest poniżej.
              return const SizedBox.shrink(); 
            },
          ),
          
          // Widoczna część UI, która zawsze używa aktualnej mapy _eventsByDate
          TableCalendar<_Event>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            locale: 'pl_PL',
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: _getEventsForDay,
            onDaySelected: (selectedDay, focusedDay) => setState(() { _selectedDay = selectedDay; _focusedDay = focusedDay; }),
            onFormatChanged: (format) => setState(() { if (_calendarFormat != format) _calendarFormat = format; }),
            onPageChanged: (focusedDay) => setState(() { _focusedDay = focusedDay; }),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isEmpty) return null;
                final eventTypes = events.map((e) => e.type).toSet();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: eventTypes.take(4).map((type) {
                    Color color;
                    switch (type) {
                      case 'event': color = Colors.blue; break;
                      case 'smallGroup': color = Colors.green; break;
                      case 'serviceMeeting': color = Colors.purple; break; 
                      default: color = Colors.grey;
                    }
                    return Container(width: 7, height: 7, margin: const EdgeInsets.symmetric(horizontal: 1.5), decoration: BoxDecoration(shape: BoxShape.circle, color: color));
                  }).toList(),
                );
              },
            ),
          ),
          const SizedBox(height: 8.0),
          Expanded(
            child: ListView.builder(
              itemCount: _getEventsForDay(_selectedDay!).length,
              itemBuilder: (context, index) {
                final event = _getEventsForDay(_selectedDay!)[index];
                late Color color;
                late IconData icon;

                 switch (event.type) {
                    case 'event': color = Colors.blue; icon = Icons.event; break;
                    case 'smallGroup': color = Colors.green; icon = Icons.groups; break;
                    case 'serviceMeeting': color = Colors.purple; icon = Icons.work_outline; break;
                    default: color = Colors.grey; icon = Icons.circle;
                  }
                return ListTile(leading: Icon(icon, color: color), title: Text(event.title));
              },
            ),
          ),
        ],
      ),
    );
  }
}