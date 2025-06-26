// lib/screens/wydarzenia_calendar_screen.dart
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'wydarzenie_detail_screen.dart';
import 'dart:collection';

// Klasa Event (bez zmian)
class Event {
  final String id;
  final String title;
  final DateTime date; // Przechowuje czas lokalny!

  Event({required this.id, required this.title, required this.date});

  @override
  String toString() => title;
}

class WydarzeniaCalendarScreen extends StatefulWidget {
  const WydarzeniaCalendarScreen({super.key});

  @override
  State<WydarzeniaCalendarScreen> createState() => _WydarzeniaCalendarScreenState();
}

class _WydarzeniaCalendarScreenState extends State<WydarzeniaCalendarScreen> {
  // ... (Zmienne stanu _firestore, _selectedEvents, etc. bez zmian) ...
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final ValueNotifier<List<Event>> _selectedEvents;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final LinkedHashMap<DateTime, List<Event>> _events = LinkedHashMap<DateTime, List<Event>>(
    equals: isSameDay,
    hashCode: (key) => key.day * 1000000 + key.month * 10000 + key.year,
  );
  bool _isLoading = true;


  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));
    _loadFirestoreEvents();
  }

  @override
  void dispose() {
    _selectedEvents.dispose();
    super.dispose();
  }

  // ... (Funkcje _loadFirestoreEvents, _getEventsForDay, _formatDateTime bez zmian) ...
  Future<void> _loadFirestoreEvents() async {
    _events.clear();
    setState(() { _isLoading = true; });

    try {
      final snap = await _firestore.collection('events').get();
      for (var doc in snap.docs) {
        final data = doc.data();
        final eventId = doc.id;
        final timestamp = data['eventDate'] as Timestamp?;
        final title = data['title'] as String? ?? 'Bez tytułu';

        if (timestamp != null) {
          final utcDateTime = timestamp.toDate();
          final localEventDate = utcDateTime.toLocal();
          final dateKey = DateTime.utc(localEventDate.year, localEventDate.month, localEventDate.day);
          final newEvent = Event(id: eventId, title: title, date: localEventDate);

          if (_events.containsKey(dateKey)) {
            _events[dateKey]!.add(newEvent);
          } else {
            _events[dateKey] = [newEvent];
          }
        }
      }
       if (_selectedDay != null) {
         _selectedEvents.value = _getEventsForDay(_selectedDay!);
       }

    } catch (e) {
      print("Błąd ładowania wydarzeń z Firestore: $e");
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Błąd ładowania wydarzeń: $e'), backgroundColor: Colors.red),
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

  List<Event> _getEventsForDay(DateTime day) {
    return _events[DateTime.utc(day.year, day.month, day.day)] ?? [];
  }

  String _formatDateTime(DateTime dateTime) {
    final localDateTime = dateTime.toLocal();
    return DateFormat('HH:mm', 'pl_PL').format(localDateTime);
  }


  @override
  Widget build(BuildContext context) {
    // --- Definicja gradientu (możesz dostosować kolory) ---
    // Użyjemy kolorów podobnych do tych z Twojego HomeScreen
    const List<Color> gradientColors = [
      Color.fromARGB(255, 109, 196, 223), // Jasnoniebieski/turkusowy
      Color.fromARGB(255, 133, 221, 235)  // Bardzo jasny niebieski/cyjan
      // Możesz dodać więcej kolorów, jeśli chcesz bardziej złożony gradient
    ];
    // ----------------------------------------------------

    return Column(
      children: [
         _isLoading
           ? const Expanded(child: Center(child: CircularProgressIndicator()))
           : TableCalendar<Event>(
               locale: 'pl_PL',
               firstDay: DateTime.utc(2020, 1, 1),
               lastDay: DateTime.utc(2030, 12, 31),
               focusedDay: _focusedDay,
               selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
               calendarFormat: _calendarFormat,
               eventLoader: _getEventsForDay,
               startingDayOfWeek: StartingDayOfWeek.monday,

               // --- ZMIANY W STYLIZACJI KALENDARZA ---
               calendarStyle: CalendarStyle(
                 // Styl dla wybranego dnia
                 selectedDecoration: BoxDecoration(
                   // Używamy zdefiniowanego gradientu
                   gradient: const LinearGradient(
                     colors: gradientColors, // Nasze kolory gradientu
                     begin: Alignment.topLeft, // Początek gradientu
                     end: Alignment.bottomRight, // Koniec gradientu
                   ),
                   shape: BoxShape.circle, // Kształt kółka
                   // Można dodać cień, jeśli chcesz
                   // boxShadow: [
                   //   BoxShadow(
                   //     color: gradientColors.last.withOpacity(0.5),
                   //     blurRadius: 4,
                   //     offset: Offset(0, 2),
                   //   )
                   // ],
                 ),
                 // Styl tekstu dla wybranego dnia (ważne dla kontrastu)
                 selectedTextStyle: const TextStyle(
                   color: Colors.white, // Biały tekst na gradiencie
                   fontWeight: FontWeight.bold,
                   fontSize: 16.0, // Możesz dostosować rozmiar
                 ),

                 // Styl dla dzisiejszego dnia (opcjonalnie, możesz zostawić domyślny lub dostosować)
                 todayDecoration: BoxDecoration(
                   color: Theme.of(context).colorScheme.primary.withOpacity(0.2), // Lekko podświetlony
                   shape: BoxShape.circle,
                 ),
                 todayTextStyle: TextStyle(
                   color: Theme.of(context).colorScheme.primary, // Kolor tekstu dla dzisiaj
                   fontWeight: FontWeight.bold,
                 ),

                 // Styl dla markerów wydarzeń (kropek pod dniami)
                 markerDecoration: BoxDecoration(
                   color: Theme.of(context).colorScheme.secondary, // Użyj koloru drugorzędnego lub innego
                   shape: BoxShape.circle,
                 ),
                 markersMaxCount: 1,
               ),
               // --- KONIEC ZMIAN W STYLIZACJI ---

               headerStyle: const HeaderStyle(
                 formatButtonVisible: false,
                 titleCentered: true,
               ),
               onDaySelected: (selectedDay, focusedDay) {
                 if (!isSameDay(_selectedDay, selectedDay)) {
                   setState(() {
                     _selectedDay = selectedDay;
                     _focusedDay = focusedDay;
                   });
                   _selectedEvents.value = _getEventsForDay(selectedDay);
                 }
               },
               onFormatChanged: (format) {
                 if (_calendarFormat != format) {
                   setState(() {
                     _calendarFormat = format;
                   });
                 }
               },
               onPageChanged: (focusedDay) {
                 _focusedDay = focusedDay;
               },
             ),

        const SizedBox(height: 8.0),
        // Lista wydarzeń (bez zmian, używa Card z motywu globalnego)
        if (!_isLoading)
          Expanded(
            child: ValueListenableBuilder<List<Event>>(
              valueListenable: _selectedEvents,
              builder: (context, events, _) {
                 if (events.isEmpty && _selectedDay != null) {
                     return Center(
                        child: Text('Brak wydarzeń w dniu ${DateFormat('dd.MM.yyyy').format(_selectedDay!)}'),
                     );
                  }
                 return ListView.builder(
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final event = events[index];
                      return Card( // Używa stylu z CardTheme (białe tło)
                        // margin usunięty, bo jest w CardTheme lub Padding poniżej
                        // elevation usunięty, bo jest w CardTheme
                         margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0), // Dodano z powrotem margines dla odstępów
                         // Jeśli używasz GlowingCardWrapper, opakuj Card tutaj
                         // child: GlowingCardWrapper( ... child: ListTile(...) )
                        child: ListTile(
                          title: Text(event.title),
                          subtitle: Text('Godzina: ${_formatDateTime(event.date)}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => WydarzenieDetailScreen(eventId: event.id),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
              },
            ),
          ),
      ],
    );
  }
}
