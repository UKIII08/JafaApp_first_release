// lib/screens/wydarzenia_calendar_screen.dart

import 'dart:async';
import 'dart:collection';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

// Klasa pomocnicza do reprezentowania wydarzeń
class _Event {
  final String title;
  final String type; // 'event', 'smallGroup', 'serviceMeeting'
  final dynamic originalData;

  _Event({required this.title, required this.type, this.originalData});

  @override
  String toString() => title;
}

class WydarzeniaCalendarScreen extends StatefulWidget {
  const WydarzeniaCalendarScreen({super.key});

  @override
  State<WydarzeniaCalendarScreen> createState() =>
      _WydarzeniaCalendarScreenState();
}

class _WydarzeniaCalendarScreenState extends State<WydarzeniaCalendarScreen> {
  late final ValueNotifier<List<_Event>> _selectedEvents;
  final LinkedHashMap<DateTime, List<_Event>> _eventsByDate =
      LinkedHashMap<DateTime, List<_Event>>(
    equals: isSameDay,
    hashCode: (key) => key.day * 1000000 + key.month * 10000 + key.year,
  );
  
  StreamSubscription? _streamSubscription;
  bool _isLoading = true;

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));
    _setupStreamsListener();
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _selectedEvents.dispose();
    super.dispose();
  }

  // ✅ NOWA, STABILNA ARCHITEKTURA
  Future<void> _setupStreamsListener() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // Połącz wszystkie potrzebne strumienie w jeden
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final userRoles = List<String>.from(userDoc.data()?['roles'] ?? []);
    
    Stream<QuerySnapshot> generalEventsStream = FirebaseFirestore.instance.collection('events').snapshots();
    Stream<QuerySnapshot> smallGroupStream = FirebaseFirestore.instance.collection('smallGroups').where('members', arrayContains: user.uid).limit(1).snapshots();
    List<Stream<QuerySnapshot>> serviceStreams = await _getServiceMeetingStreams(userRoles);

    // Połącz strumienie w jeden
    List<Stream<QuerySnapshot>> allStreams = [generalEventsStream, smallGroupStream, ...serviceStreams];
    
    // Słuchaj zmian na połączonych strumieniach
    _streamSubscription = Stream<List<QuerySnapshot>>.periodic(const Duration(milliseconds: 50), (count) => [])
      .asyncMap((_) => Future.wait(allStreams.map((s) => s.first)))
      .listen((snapshots) {
        final allDocs = snapshots.expand((snapshot) => snapshot.docs).toList();
        _processAndUpdateCalendar(allDocs);
      });
  }


  Future<List<Stream<QuerySnapshot>>> _getServiceMeetingStreams(List<String> userRoles) async {
    if (userRoles.isEmpty) return [];
    List<Stream<QuerySnapshot>> streams = [];
    final servicesSnapshot = await FirebaseFirestore.instance.collection('services').where('name', whereIn: userRoles).get();
    for (var serviceDoc in servicesSnapshot.docs) {
      streams.add(FirebaseFirestore.instance.collection('services').doc(serviceDoc.id).collection('meetings').snapshots());
    }
    return streams;
  }
  
  void _processAndUpdateCalendar(List<QueryDocumentSnapshot> docs) {
      final newEvents = <DateTime, List<_Event>>{};
      
      for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final String collectionName = doc.reference.parent.id;

          if (collectionName == 'smallGroups') {
              _addSmallGroupEvents(data, newEvents);
          } else {
              _addGeneralEvent(data, collectionName, newEvents);
          }
      }

      if (mounted) {
          setState(() {
              _eventsByDate.clear();
              _eventsByDate.addAll(newEvents);
              _selectedEvents.value = _getEventsForDay(_selectedDay!);
              _isLoading = false;
          });
      }
  }
  
  void _addSmallGroupEvents(Map<String, dynamic> data, Map<DateTime, List<_Event>> eventsMap) {
      final tempDate = (data['temporaryMeetingDateTime'] as Timestamp?)?.toDate();
      DateTime? startOfWeekWithTempMeeting;
      if (tempDate != null) {
          startOfWeekWithTempMeeting = _getStartOfWeek(tempDate);
      }

      if (tempDate != null && tempDate.isAfter(DateTime.now().subtract(const Duration(hours: 3)))) {
          final dateKey = DateTime.utc(tempDate.year, tempDate.month, tempDate.day);
          eventsMap.putIfAbsent(dateKey, () => []).add(_Event(title: 'Spotkanie małej grupy (jednorazowe)', type: 'smallGroup', originalData: data));
      }

      final recurringDay = data['recurringMeetingDay'] as int?;
      final recurringTime = data['recurringMeetingTime'] as String?;

      if (recurringDay != null && recurringTime != null) {
          final recurringDates = _calculateRecurringMeetingDates(recurringDay, recurringTime);
          for (var date in recurringDates) {
              if (date.isAfter(DateTime.now().subtract(const Duration(days: 1)))) {
                  final startOfCurrentRecurringWeek = _getStartOfWeek(date);
                  if (startOfWeekWithTempMeeting != null && isSameDay(startOfCurrentRecurringWeek, startOfWeekWithTempMeeting)) {
                      continue;
                  }
                  final dateKey = DateTime.utc(date.year, date.month, date.day);
                  eventsMap.putIfAbsent(dateKey, () => []).add(_Event(title: 'Spotkanie małej grupy', type: 'smallGroup', originalData: data));
              }
          }
      }
  }

  void _addGeneralEvent(Map<String, dynamic> data, String collectionName, Map<DateTime, List<_Event>> eventsMap) {
      DateTime? eventDate;
      String title = "Brak tytułu";
      String type = "event";

      if(collectionName == 'events') {
        eventDate = (data['date'] as Timestamp?)?.toDate();
        title = data['title'] ?? 'Wydarzenie bez nazwy';
        type = 'event';
      } else if (collectionName == 'meetings') {
        eventDate = (data['date'] as Timestamp?)?.toDate();
        title = data['title'] ?? 'Spotkanie służby';
        type = 'serviceMeeting';
      }
      
      if (eventDate != null) {
        final dateKey = DateTime.utc(eventDate.year, eventDate.month, eventDate.day);
        eventsMap.putIfAbsent(dateKey, () => []).add(_Event(title: title, type: type, originalData: data));
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
        dates.add(DateTime.utc(day.year, day.month, day.day, hour, minute));
      }
    }
    return dates;
  }

  DateTime _getStartOfWeek(DateTime date) {
    final normalizedDate = DateTime.utc(date.year, date.month, date.day);
    return normalizedDate.subtract(Duration(days: normalizedDate.weekday - 1));
  }

  List<_Event> _getEventsForDay(DateTime day) {
    return _eventsByDate[DateTime.utc(day.year, day.month, day.day)] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
        _selectedEvents.value = _getEventsForDay(selectedDay);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kalendarz wydarzeń'),
        elevation: 1,
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              TableCalendar<_Event>(
                firstDay: DateTime.utc(2022, 1, 1),
                lastDay: DateTime.utc(2032, 12, 31),
                focusedDay: _focusedDay,
                locale: 'pl_PL',
                calendarFormat: _calendarFormat,
                eventLoader: _getEventsForDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: _onDaySelected,
                onFormatChanged: (format) {
                  if (_calendarFormat != format) {
                    setState(() => _calendarFormat = format);
                  }
                },
                onPageChanged: (focusedDay) {
                  setState(() {
                    _focusedDay = focusedDay;
                  });
                },
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
                        return Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8.0),
              Expanded(
                child: ValueListenableBuilder<List<_Event>>(
                  valueListenable: _selectedEvents,
                  builder: (context, value, _) {
                    return ListView.builder(
                      itemCount: value.length,
                      itemBuilder: (context, index) {
                        final event = value[index];
                        late Color color;
                        late IconData icon;
                        switch (event.type) {
                          case 'event': color = Colors.blue; icon = Icons.event; break;
                          case 'smallGroup': color = Colors.green; icon = Icons.groups; break;
                          case 'serviceMeeting': color = Colors.purple; icon = Icons.work_outline; break;
                          default: color = Colors.grey; icon = Icons.circle;
                        }
                        return ListTile(
                          leading: Icon(icon, color: color),
                          title: Text(event.title),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
    );
  }
}