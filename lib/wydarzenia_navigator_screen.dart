// lib/screens/main_wydarzenia_navigator_screen.dart
import 'package:flutter/material.dart';
import 'wydarzenia_list_screen.dart';
import 'wydarzenia_calendar_screen.dart';
import 'wydarzenia_saturday_screen.dart';

class MainWydarzeniaNavigatorScreen extends StatefulWidget {
  const MainWydarzeniaNavigatorScreen({super.key});

  @override
  State<MainWydarzeniaNavigatorScreen> createState() => _MainWydarzeniaNavigatorScreenState();
}

class _MainWydarzeniaNavigatorScreenState extends State<MainWydarzeniaNavigatorScreen> {
  int _selectedIndex = 0; // Indeks aktywnej zakładki

  // Lista ekranów odpowiadających indeksom paska nawigacji
  static const List<Widget> _widgetOptions = <Widget>[
    WydarzeniaListScreen(),    // Index 0: Lista
    WydarzeniaCalendarScreen(), // Index 1: Kalendarz
    WydarzeniaSaturdayScreen(), // Index 2: Spotkania Sobotnie
  ];

  // Lista tytułów dla AppBar
  static const List<String> _appBarTitles = <String>[
    'Wydarzenia',
    'Kalendarz',
    'Spotkania Sobotnie',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitles[_selectedIndex]), // Dynamiczny tytuł
      ),
      body: Center(
        // Wyświetlamy wybrany ekran
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Lista',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Kalendarz',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.groups), // Ikona dla spotkań
            label: 'Spotkania Sob.',
          ),
        ],
        currentIndex: _selectedIndex,
        // --- USUNIĘTO TĘ LINIĘ ---
        // selectedItemColor: Theme.of(context).colorScheme.primary,
        // -------------------------
        onTap: _onItemTapped, // Funkcja wywoływana przy kliknięciu
        // Dodaj type: BottomNavigationBarType.fixed, aby etykiety były zawsze widoczne
        // i tło z motywu było poprawnie stosowane.
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
