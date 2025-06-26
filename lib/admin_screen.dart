import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
// Importy modeli i serwisów
import '../models/book_model.dart'; // Upewnij się, że ścieżka jest poprawna
import '../services/google_books_service.dart'; // Upewnij się, że ścieżka jest poprawna

// Import ekranów
import 'admin_users_screen.dart'; // Upewnij się, że plik istnieje
import 'isbn_scanner_screen.dart'; // Ekran skanera

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  // Klucz dla formularza zarządzania treścią
  final _contentFormKey = GlobalKey<FormState>();

  // Kontrolery dla formularza zarządzania treścią
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _locationController = TextEditingController();
  final _googleMapsLinkController = TextEditingController();

  // Kontrolery dla powiadomień
  final _notificationTitleController = TextEditingController();
  final _notificationBodyController = TextEditingController();

  // Zmienne stanu dla zarządzania treścią
  DateTime? _selectedDate;
  String _selectedCollection = 'aktualnosci'; // Domyślna kolekcja
  String? _editingDocumentId;
  bool _isSaturdayMeeting = false;

  // Zmienne stanu dla powiadomień i ról
  List<String> _availableTopics = ['all'];
  String? _selectedNotificationTopic = 'all';
  bool _isLoadingTopics = true;
  String? _selectedTargetRole;

  // Firebase
  final functions = FirebaseFunctions.instanceFor(region: 'europe-west10');
  final _firestore = FirebaseFirestore.instance;

  // --- ZMIENNE STANU DLA BIBLIOTEKI ---
  final GoogleBooksService _googleBooksService = GoogleBooksService();
  bool _isLoadingBookData = false;
  String? _scanError;
  Book? _foundBook;
  bool _isAddingBook = false;
  final _manualIsbnController = TextEditingController();
  // *** NOWY KONTROLER DLA NAZWY WŁAŚCICIELA ***
  final _ownerNameController = TextEditingController();
  // -----------------------------------------

  @override
  void initState() {
    super.initState();
    _fetchUniqueRolesAndBuildTopics();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _locationController.dispose();
    _googleMapsLinkController.dispose();
    _notificationTitleController.dispose();
    _notificationBodyController.dispose();
    _manualIsbnController.dispose();
    _ownerNameController.dispose(); // *** DODANO DISPOSE ***
    super.dispose();
  }

  // --- FUNKCJE DLA BIBLIOTEKI ---

  Future<void> _scanIsbn() async {
    if (_isLoadingBookData || _isAddingBook) return;
    setState(() { _scanError = null; _foundBook = null; _editingDocumentId = null; });
    try {
      final String? scannedIsbn = await Navigator.push<String>(
        context, MaterialPageRoute(builder: (context) => const IsbnScannerScreen()),
      );
      if (!mounted) return;
      if (scannedIsbn != null && scannedIsbn.isNotEmpty) {
        print("Otrzymano ISBN z ekranu skanera: $scannedIsbn");
        await _fetchBookDetails(scannedIsbn);
      } else {
        print("Skanowanie anulowane lub nie zwrócono wartości.");
      }
    } catch (e) {
      if (mounted) {
        print("Błąd podczas nawigacji do/z ekranu skanera: $e");
        setState(() { _scanError = 'Wystąpił błąd podczas procesu skanowania.'; });
      }
    }
  }

  Future<void> _fetchManualIsbn() async {
     if (_isLoadingBookData || _isAddingBook) return;
     final String isbn = _manualIsbnController.text.trim();
     if (isbn.isEmpty) {
        setState(() { _scanError = 'Wprowadź numer ISBN.'; });
        return;
     }
     if (isbn.length != 10 && isbn.length != 13) {
        setState(() { _scanError = 'Niepoprawna długość numeru ISBN (oczekiwano 10 lub 13 cyfr).'; });
        return;
     }
     setState(() { _scanError = null; _foundBook = null; _editingDocumentId = null; });
     print("Pobieranie danych dla ręcznie wprowadzonego ISBN: $isbn");
     await _fetchBookDetails(isbn);
  }

  Future<void> _fetchBookDetails(String isbn) async {
    setState(() { _isLoadingBookData = true; _scanError = null; });
    try {
      final book = await _googleBooksService.fetchBookByIsbn(isbn);
      if (!mounted) return;
      if (book != null) {
        // Wyczyść pole właściciela przy nowym wyszukiwaniu
        _ownerNameController.clear();
        setState(() { _foundBook = book; _isLoadingBookData = false; });
      } else {
        setState(() { _scanError = 'Nie znaleziono książki dla ISBN: $isbn w Google Books.'; _isLoadingBookData = false; });
      }
    } catch (e, s) {
       if (!mounted) return;
      print("==== Błąd pobierania danych książki ====");
      print("ISBN: $isbn");
      print("Wyjątek: $e");
      print("Stack Trace: $s");
      print("========================================");
      setState(() {
        if (e.toString().contains('Klucz API Google Books')) {
             _scanError = 'Błąd konfiguracji: Sprawdź klucz API Google Books.';
        } else if (e.toString().contains('NetworkException') || e.toString().contains('SocketException')) {
             _scanError = 'Błąd sieci podczas pobierania danych książki.';
        } else {
             _scanError = 'Błąd podczas pobierania danych książki. Sprawdź konsolę.';
        }
        _isLoadingBookData = false;
      });
    }
  }

  // *** ZAKTUALIZOWANA FUNKCJA _addBookCopyToLibrary Z POLEM WŁAŚCICIELA ***
  Future<void> _addBookCopyToLibrary() async {
    if (_foundBook == null || _isAddingBook) return;
    final user = FirebaseAuth.instance.currentUser; // Admin dodający
    if (user == null) {
       if (mounted) { ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Błąd: Musisz być zalogowany.')), ); } return;
    }

    // Pobierz wpisaną nazwę właściciela
    final String ownerNameInput = _ownerNameController.text.trim();
    // Walidacja: Można dodać wymóg wpisania nazwy właściciela
    // if (ownerNameInput.isEmpty) {
    //    if (mounted) { ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Wprowadź nazwę właściciela książki.')), ); } return;
    // }


    setState(() { _isAddingBook = true; });

    final String isbn = _foundBook!.isbn;
    final DocumentReference bookDocRef = _firestore.collection('books').doc(isbn);
    int nextCopyIndex = 1;

    try {
      // KROK 1: Znajdź następny copyIndex POZA transakcją
      final copiesQuery = _firestore.collection('bookCopies').where('isbn', isEqualTo: isbn).orderBy('copyIndex', descending: true).limit(1);
      final copiesSnapshot = await copiesQuery.get();
      if (copiesSnapshot.docs.isNotEmpty) {
        final lastCopyData = copiesSnapshot.docs.first.data();
        if (lastCopyData.containsKey('copyIndex') && lastCopyData['copyIndex'] is int) {
          nextCopyIndex = (lastCopyData['copyIndex'] as int) + 1;
        } else { print("Ostrzeżenie: Błędny 'copyIndex' w ostatnim egzemplarzu ISBN $isbn."); }
      }
      print("Obliczony następny indeks egzemplarza: $nextCopyIndex");
      //---------------------------------------------------------

      String? finalMessage;
      // KROK 2: Rozpocznij transakcję
      await _firestore.runTransaction((transaction) async {
        // KROK 3: Sprawdź/Dodaj książkę w transakcji
        final bookSnapshot = await transaction.get(bookDocRef);
        if (!bookSnapshot.exists) {
          transaction.set(bookDocRef, _foundBook!.toFirestore());
          print("Dodano nową książkę do 'books' w transakcji: $isbn");
        } else { print("Książka już istnieje w 'books': $isbn"); }

        // KROK 4: Dodaj nowy egzemplarz w transakcji Z INFORMACJĄ O WŁAŚCICIELU
        final newCopyRef = _firestore.collection('bookCopies').doc();
        transaction.set(newCopyRef, {
          'bookRef': bookDocRef,
          'isbn': isbn,
          'copyIndex': nextCopyIndex,
          'status': 'available',
          'addedBy': user.uid, // Kto dodał do systemu
          'addedAt': FieldValue.serverTimestamp(),
          // *** ZAPIS INFORMACJI O WŁAŚCICIELU ***
          // Zapisz UID admina jako właściciela (uproszczenie)
          'ownerId': user.uid,
          // Zapisz wpisaną nazwę, jeśli nie jest pusta, inaczej domyślną nazwę admina
          'ownerName': ownerNameInput.isNotEmpty ? ownerNameInput : (user.displayName ?? user.email),
          // **************************************
          'borrowedBy': null,
          'borrowedAt': null,
          'dueDate': null,
        });
        print("Dodano nowy egzemplarz (index: $nextCopyIndex) w transakcji dla: $isbn, właściciel: ${user.uid}");
      }); // Koniec transakcji

      finalMessage = 'Dodano egzemplarz "${_foundBook!.title}" (Index: $nextCopyIndex)!';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text(finalMessage ?? 'Dodano egzemplarz!')), );
        setState(() {
           _foundBook = null;
           _manualIsbnController.clear();
           _ownerNameController.clear(); // Wyczyść pole właściciela
        });
      }
    } catch (e) {
      print("Błąd podczas dodawania egzemplarza książki: $e");
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Błąd dodawania egzemplarza: ${e.toString()}')), ); }
    } finally {
       if (mounted) { setState(() { _isAddingBook = false; }); }
    }
  }


  // --- FUNKCJE ZARZĄDZANIA TREŚCIĄ ---
   Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context, initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000), lastDate: DateTime(2030),
    );
    if (picked != null) {
        if (_selectedCollection == 'events') {
             final TimeOfDay? pickedTime = await showTimePicker(
                 context: context, initialTime: TimeOfDay.fromDateTime(_selectedDate ?? DateTime.now()),
             );
             if (pickedTime != null) {
                 setState(() { _selectedDate = DateTime(picked.year, picked.month, picked.day, pickedTime.hour, pickedTime.minute); });
             }
        } else { if (picked != _selectedDate) { setState(() { _selectedDate = picked; }); } }
    }
  }

  Future<void> _submitContentForm() async {
    if (!_contentFormKey.currentState!.validate()) return;
    if (_foundBook != null || _isLoadingBookData || _isAddingBook) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zakończ dodawanie książki przed zarządzaniem treścią.')));
       return;
    }
    try {
      final collection = _firestore.collection(_selectedCollection);
      Map<String, dynamic> data = {
        'title': _titleController.text.trim(),
        _selectedCollection == 'events' ? 'description' : 'content': _contentController.text.trim(),
        _selectedCollection == 'events' ? 'eventDate' : 'publishDate': _selectedDate != null ? Timestamp.fromDate(_selectedDate!) : FieldValue.serverTimestamp(),
      };
      if (_selectedCollection == 'ogloszenia') { data['rolaDocelowa'] = _selectedTargetRole; }
      else if (_selectedCollection == 'events') {
        data['location'] = _locationController.text.trim();
        data['googleMapsLink'] = _googleMapsLinkController.text.trim();
        data['sobota'] = _isSaturdayMeeting;
        if (_editingDocumentId == null) { data['attendees'] = {}; }
      }
      if (_editingDocumentId == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
        await collection.add(data);
        if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dodano!'))); }
      } else {
        data['updatedAt'] = FieldValue.serverTimestamp();
        await collection.doc(_editingDocumentId).update(data);
        if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zaktualizowano!'))); }
      }
      _clearForm();
    } catch (e) {
      print("Błąd podczas zapisu do kolekcji $_selectedCollection: $e");
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Wystąpił błąd zapisu: $e'))); }
    }
  }

  Future<void> _deleteDocument(String documentId) async {
      bool confirm = await showDialog<bool>(
        context: context, builder: (dialogContext) => AlertDialog(
            title: const Text('Potwierdzenie'), content: const Text('Czy na pewno chcesz usunąć ten element?'),
            actions: [ TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Anuluj')),
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Usuń', style: TextStyle(color: Colors.red))), ], ),
      ) ?? false;
      if (!confirm || !mounted) return;
    try {
      await _firestore.collection(_selectedCollection).doc(documentId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usunięto!')));
         if (documentId == _editingDocumentId) { _clearForm(); }
      }
    } catch (e) {
       print("Błąd podczas usuwania dokumentu $documentId z $_selectedCollection: $e");
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Wystąpił błąd usuwania: $e'))); }
    }
  }

  void _startEditingDocument(String documentId, Map<String, dynamic> data) {
    setState(() {
      _foundBook = null; _scanError = null; _isLoadingBookData = false; _isAddingBook = false;
      _manualIsbnController.clear();
      _ownerNameController.clear(); // Wyczyść pole właściciela przy edycji treści
      _editingDocumentId = documentId;
      _titleController.text = data['title'] ?? '';
      _contentController.text = data[_selectedCollection == 'events' ? 'description' : 'content'] ?? '';
      final dateField = _selectedCollection == 'events' ? 'eventDate' : 'publishDate';
      _selectedDate = (data[dateField] is Timestamp) ? (data[dateField] as Timestamp).toDate() : null;
      if (_selectedCollection == 'ogloszenia') {
        String? roleFromDb = data['rolaDocelowa'];
        _selectedTargetRole = (roleFromDb != null && _availableTopics.contains(roleFromDb) && roleFromDb != 'all') ? roleFromDb : null;
        _locationController.clear(); _googleMapsLinkController.clear(); _isSaturdayMeeting = false;
      } else if (_selectedCollection == 'events') {
        _locationController.text = data['location'] ?? '';
        _googleMapsLinkController.text = data['googleMapsLink'] ?? '';
        _isSaturdayMeeting = data['sobota'] as bool? ?? false;
        _selectedTargetRole = null;
      } else {
        _selectedTargetRole = null; _locationController.clear(); _googleMapsLinkController.clear(); _isSaturdayMeeting = false;
      }
    });
  }

  void _clearForm() {
    setState(() {
      _editingDocumentId = null; _titleController.clear(); _contentController.clear(); _locationController.clear();
      _googleMapsLinkController.clear(); _selectedDate = null; _selectedTargetRole = null; _isSaturdayMeeting = false;
      _foundBook = null; _scanError = null; _isLoadingBookData = false; _isAddingBook = false;
      _manualIsbnController.clear();
      _ownerNameController.clear(); // *** DODANO CZYSZCZENIE POLA WŁAŚCICIELA ***
    });
     _contentFormKey.currentState?.reset();
  }

   // --- POZOSTAŁE FUNKCJE ---
   Future<void> _fetchUniqueRolesAndBuildTopics() async {
       if (!mounted) return;
    setState(() { _isLoadingTopics = true; });
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      final Set<String> uniqueRoles = {};
      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        if (data.containsKey('roles') && data['roles'] is List) {
          final rolesList = List<dynamic>.from(data['roles']);
          for (var role in rolesList) { if (role is String && role.trim().isNotEmpty) { uniqueRoles.add(role.trim()); } }
        }
      }
      final List<String> finalTopics = ['all', ...uniqueRoles.toList()..sort()];
      if (mounted) {
          setState(() {
            _availableTopics = finalTopics;
            if (!_availableTopics.contains(_selectedNotificationTopic)) { _selectedNotificationTopic = 'all'; }
            if (_selectedTargetRole != null && !_availableTopics.contains(_selectedTargetRole)) { _selectedTargetRole = null; }
            _isLoadingTopics = false;
          });
      }
    } catch (e) {
       print("Błąd podczas pobierania unikalnych ról: $e");
      if (mounted) { setState(() { _availableTopics = ['all']; _selectedNotificationTopic = 'all'; _selectedTargetRole = null; _isLoadingTopics = false; }); }
    }
  }

   Future<void> _sendPushMessage() async {
    if (_notificationTitleController.text.trim().isEmpty || _notificationBodyController.text.trim().isEmpty || _selectedNotificationTopic == null) {
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Wprowadź tytuł, treść i wybierz temat/rolę.')), ); } return;
    }
    bool confirm = await showDialog<bool>( context: context, builder: (context) => AlertDialog(
         title: const Text('Potwierdzenie wysyłki'), content: Text('Wysłać powiadomienie do grupy "$_selectedNotificationTopic"?'),
         actions: [ TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Anuluj')), TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Wyślij')), ], ),
    ) ?? false;
    if (!confirm || !mounted) return;
    try {
      final callable = functions.httpsCallable('sendManualNotification');
      print('Wywoływanie funkcji sendManualNotification z parametrami: title=${_notificationTitleController.text.trim()}, body=${_notificationBodyController.text.trim()}, targetRole=${_selectedNotificationTopic == 'all' ? null : _selectedNotificationTopic}');
      final result = await callable.call({ 'title': _notificationTitleController.text.trim(), 'body': _notificationBodyController.text.trim(), 'targetRole': _selectedNotificationTopic == 'all' ? null : _selectedNotificationTopic, });
      print('Odpowiedź z funkcji sendManualNotification: ${result.data}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text(result.data['message'] ?? 'Wysłano powiadomienie!')), );
        _notificationTitleController.clear(); _notificationBodyController.clear(); setState(() { _selectedNotificationTopic = 'all'; });
      }
    } on FirebaseFunctionsException catch (e) {
       print("Błąd Cloud Function (sendManualNotification): ${e.code} - ${e.message}");
       if (mounted) { ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Błąd wysyłania powiadomienia: ${e.message ?? e.code}')), ); }
    } catch (e) {
       print("Nieznany błąd podczas wysyłania powiadomienia: $e");
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Wystąpił nieoczekiwany błąd: $e')), ); }
    }
  }
  // ---------------------------------


  @override
  Widget build(BuildContext context) {
    // Logika budowania Query dla listy treści
     Query contentQuery = _firestore.collection(_selectedCollection);
    try {
       if (_selectedCollection == 'aktualnosci') { contentQuery = contentQuery.orderBy('publishDate', descending: true); }
       else if (_selectedCollection == 'events') { contentQuery = contentQuery.orderBy('eventDate', descending: false); }
       else if (_selectedCollection == 'ogloszenia') { contentQuery = contentQuery.orderBy('createdAt', descending: true); }
       else { contentQuery = contentQuery.orderBy('createdAt', descending: true); }
    } catch (e) {
       print("Błąd podczas ustawiania sortowania dla kolekcji $_selectedCollection: $e");
       contentQuery = contentQuery.orderBy('createdAt', descending: true);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Administratora'),
        actions: [
            IconButton( icon: const Icon(Icons.refresh), tooltip: 'Odśwież listę ról', onPressed: _isLoadingTopics ? null : _fetchUniqueRolesAndBuildTopics, ),
            IconButton( icon: const Icon(Icons.exit_to_app), tooltip: 'Wyloguj', onPressed: () async { await FirebaseAuth.instance.signOut(); } ),
            if (_editingDocumentId != null || _foundBook != null) IconButton( icon: const Icon(Icons.cancel), tooltip: 'Anuluj', onPressed: _clearForm, ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
             crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- SEKCJA ZARZĄDZANIA TREŚCIĄ --- (Na górze)
              Text( _editingDocumentId == null ? 'Zarządzaj Treścią' : 'Edytuj Treść',
                   style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                 value: _selectedCollection,
                 items: const [ DropdownMenuItem(value: 'aktualnosci', child: Text('Aktualności')), DropdownMenuItem(value: 'ogloszenia', child: Text('Ogłoszenia')), DropdownMenuItem(value: 'events', child: Text('Wydarzenia')), ],
                 onChanged: (val) {
                   if (_editingDocumentId == null && val != null && val != _selectedCollection) {
                     setState(() { _selectedCollection = val; _clearForm(); });
                   } else if (_editingDocumentId != null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zakończ edycję przed zmianą kolekcji.')));
                   }
                 },
                 decoration: InputDecoration( labelText: 'Typ Treści', border: const OutlineInputBorder(), filled: _editingDocumentId != null, fillColor: Colors.grey[100] ),
                 disabledHint: Text("Edytujesz: $_selectedCollection"),
                 onTap: _editingDocumentId != null ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zakończ edycję przed zmianą kolekcji.'))) : null,
               ),
              const SizedBox(height: 16),
              Form( key: _contentFormKey, child: Column( children: [
                     TextFormField( controller: _titleController, decoration: InputDecoration( labelText: 'Tytuł', border: const OutlineInputBorder(), suffixIcon: _titleController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 20), onPressed: () => _titleController.clear()) : null, ),
                       validator: (value) => value == null || value.trim().isEmpty ? 'Wprowadź tytuł' : null, onChanged: (_) => setState(() {}), ),
                     const SizedBox(height: 12),
                     TextFormField( controller: _contentController, decoration: InputDecoration( labelText: _selectedCollection == 'events' ? 'Opis Wydarzenia' : 'Treść', border: const OutlineInputBorder(), suffixIcon: _contentController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 20), onPressed: () => _contentController.clear()) : null, ),
                       maxLines: 4, validator: (value) => value == null || value.trim().isEmpty ? 'Wprowadź treść/opis' : null, onChanged: (_) => setState(() {}), ),
                     const SizedBox(height: 12),
                    if (_selectedCollection == 'events') ...[
                      TextFormField( controller: _locationController, decoration: InputDecoration( labelText: 'Lokalizacja (np. adres)', border: const OutlineInputBorder(), suffixIcon: _locationController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 20), onPressed: () => _locationController.clear()) : null, ),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Wprowadź lokalizację' : null, onChanged: (_) => setState(() {}), ),
                      const SizedBox(height: 12),
                      TextFormField( controller: _googleMapsLinkController, decoration: InputDecoration( labelText: 'Link Google Maps (opcjonalnie)', border: const OutlineInputBorder(), suffixIcon: _googleMapsLinkController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 20), onPressed: () => _googleMapsLinkController.clear()) : null, ),
                         validator: (value) { if (value != null && value.trim().isNotEmpty) { final uri = Uri.tryParse(value.trim()); if (uri == null || !uri.hasAbsolutePath || !uri.hasScheme || (!uri.isScheme('http') && !uri.isScheme('https'))) { return 'Wprowadź poprawny link (http://... lub https://...)'; } } return null; },
                         onChanged: (_) => setState(() {}), ),
                      const SizedBox(height: 12),
                      CheckboxListTile( title: const Text("Spotkanie sobotnie?"), value: _isSaturdayMeeting, onChanged: (bool? value) { setState(() { _isSaturdayMeeting = value ?? false; }); },
                        controlAffinity: ListTileControlAffinity.leading, contentPadding: EdgeInsets.zero, dense: true, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), tileColor: Colors.grey[100], ),
                      const SizedBox(height: 12),
                    ],
                     ListTile( leading: const Icon(Icons.calendar_today), title: Text(_selectedDate == null ? 'Wybierz datę${_selectedCollection == 'events' ? ' i godzinę' : ''}' : 'Data: ${DateFormat(_selectedCollection == 'events' ? 'dd.MM.yyyy HH:mm' : 'dd.MM.yyyy', 'pl_PL').format(_selectedDate!)}'),
                       trailing: _selectedDate != null ? IconButton(icon: const Icon(Icons.clear, size: 20), tooltip: 'Wyczyść datę', onPressed: () => setState(() => _selectedDate = null)) : null,
                       onTap: () => _selectDate(context), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade400)), tileColor: Colors.grey[50], ),
                     const SizedBox(height: 12),
                     if (_selectedCollection == 'ogloszenia') Padding( padding: const EdgeInsets.only(bottom: 12.0), child: DropdownButtonFormField<String?>( value: _selectedTargetRole, hint: const Text('Wybierz rolę docelową...'),
                           items: [ const DropdownMenuItem<String?>( value: null, child: Text('Brak (dla wszystkich)'), ), ..._availableTopics .where((topic) => topic != 'all') .map((role) => DropdownMenuItem<String?>( value: role, child: Text(role), )), ],
                           onChanged: _isLoadingTopics ? null : (String? newValue) { setState(() { _selectedTargetRole = newValue; }); },
                           decoration: InputDecoration( labelText: 'Rola Docelowa (Opcjonalnie)', border: const OutlineInputBorder(), suffixIcon: _isLoadingTopics ? const Padding(padding: EdgeInsets.all(10), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))) : (_selectedTargetRole != null ? IconButton(icon: const Icon(Icons.clear, size: 20), onPressed: () => setState(() => _selectedTargetRole = null)) : null), ),
                            disabledHint: const Text('Ładowanie ról...'), ), ),
                     ElevatedButton.icon( icon: Icon(_editingDocumentId == null ? Icons.add_circle_outline : Icons.save),
                       label: Text(_editingDocumentId == null ? 'Dodaj Treść' : 'Zapisz Zmiany'),
                       onPressed: _submitContentForm,
                       style: ElevatedButton.styleFrom( minimumSize: const Size.fromHeight(45), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), textStyle: const TextStyle(fontSize: 16), ), ),
                    const SizedBox(height: 24),
                  ],
                 ),
               ),

              // Lista elementów danej kolekcji
               StreamBuilder<QuerySnapshot>( stream: contentQuery.snapshots(), builder: (context, snapshot) {
                   if (snapshot.hasError) { print("Błąd StreamBuilder dla kolekcji $_selectedCollection: ${snapshot.error}"); return Center(child: Text('Błąd ładowania danych: ${snapshot.error}')); }
                   if (snapshot.connectionState == ConnectionState.waiting) { return const Center(child: Padding( padding: EdgeInsets.symmetric(vertical: 20.0), child: CircularProgressIndicator(), )); }
                   if (!snapshot.hasData || snapshot.data!.docs.isEmpty) { return Center(child: Padding( padding: const EdgeInsets.symmetric(vertical: 16.0), child: Text('Brak danych w kolekcji "$_selectedCollection".'), )); }
                   return ListView.builder( shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: snapshot.data!.docs.length, itemBuilder: (context, index) {
                       final doc = snapshot.data!.docs[index]; final data = doc.data() as Map<String, dynamic>? ?? {};
                       final dateField = _selectedCollection == 'events' ? 'eventDate' : (_selectedCollection == 'aktualnosci' ? 'publishDate' : 'createdAt');
                       final dateFormat = _selectedCollection == 'events' ? 'dd.MM.yyyy HH:mm' : 'dd.MM.yyyy';
                       final datePrefix = _selectedCollection == 'events' ? 'Data: ' : (_selectedCollection == 'aktualnosci' ? 'Pub: ' : 'Dod: ');
                       String formattedDate = 'Brak daty'; if (data[dateField] is Timestamp) { try { formattedDate = DateFormat(dateFormat, 'pl_PL').format((data[dateField] as Timestamp).toDate()); } catch (e) { print("Błąd formatowania daty: $e"); formattedDate = 'Błędna data'; } }
                       final bool isCurrentlyEditing = doc.id == _editingDocumentId;
                       return Card(
                         color: isCurrentlyEditing ? Colors.blue[50] : null,
                         margin: const EdgeInsets.symmetric(vertical: 6.0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), clipBehavior: Clip.antiAlias,
                         child: ListTile( title: Text(data['title'] ?? 'Brak tytułu', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('$datePrefix$formattedDate', style: Theme.of(context).textTheme.bodySmall), const SizedBox(height: 4),
                                Text(data[_selectedCollection == 'events' ? 'description' : 'content'] ?? 'Brak treści/opisu', maxLines: 2, overflow: TextOverflow.ellipsis),
                                if (_selectedCollection == 'events' && data['location'] != null && (data['location'] as String).isNotEmpty) Padding( padding: const EdgeInsets.only(top: 4.0), child: Text('Lok: ${data['location']}', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)), ),
                                if (_selectedCollection == 'events' && data.containsKey('sobota')) Padding( padding: const EdgeInsets.only(top: 4.0), child: Text('Sobotnie: ${data['sobota'] == true ? "Tak" : "Nie"}', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic, color: data['sobota'] == true ? Colors.green.shade700 : Colors.grey.shade600)), ),
                                if (_selectedCollection == 'ogloszenia' && data['rolaDocelowa'] != null && (data['rolaDocelowa'] as String).isNotEmpty) Padding( padding: const EdgeInsets.only(top: 4.0), child: Text('Rola: ${data['rolaDocelowa']}', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)), ),
                              ],
                            ),
                           trailing: Row( mainAxisSize: MainAxisSize.min, children: [
                               IconButton( icon: Icon(Icons.edit, size: 20, color: isCurrentlyEditing ? Colors.grey : Theme.of(context).iconTheme.color), tooltip: 'Edytuj', onPressed: isCurrentlyEditing ? null : () => _startEditingDocument(doc.id, data), padding: const EdgeInsets.all(8), constraints: const BoxConstraints(), ),
                               IconButton( icon: Icon(Icons.delete, size: 20, color: Colors.red.shade700), tooltip: 'Usuń', onPressed: () => _deleteDocument(doc.id), padding: const EdgeInsets.all(8), constraints: const BoxConstraints(), ),
                             ],
                           ),
                         ),
                       );
                     },
                   );
                 },
               ),
              // --- KONIEC SEKCJI ZARZĄDZANIA TREŚCIĄ ---

              const Divider(height: 32, thickness: 1),

              // --- SEKCJA POWIADOMIEŃ ---
              Text('Wyślij Powiadomienie Push', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
               TextFormField( controller: _notificationTitleController, decoration: InputDecoration( labelText: 'Tytuł Powiadomienia', border: const OutlineInputBorder(), suffixIcon: _notificationTitleController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 20), onPressed: () => _notificationTitleController.clear()) : null, ), onChanged: (_) => setState(() {}), ),
               const SizedBox(height: 12),
               TextFormField( controller: _notificationBodyController, decoration: InputDecoration( labelText: 'Treść Powiadomienia', border: const OutlineInputBorder(), suffixIcon: _notificationBodyController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 20), onPressed: () => _notificationBodyController.clear()) : null, ), maxLines: 3, onChanged: (_) => setState(() {}), ),
               const SizedBox(height: 12),
               DropdownButtonFormField<String>( value: _selectedNotificationTopic, items: _availableTopics.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                 onChanged: _isLoadingTopics ? null : (val) { if (val != null) setState(() => _selectedNotificationTopic = val); },
                 decoration: InputDecoration( labelText: 'Temat/Rola', border: const OutlineInputBorder(), suffixIcon: _isLoadingTopics ? const Padding(padding: EdgeInsets.all(10), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))) : (_selectedNotificationTopic != 'all' ? IconButton(icon: const Icon(Icons.clear, size: 20), onPressed: () => setState(() => _selectedNotificationTopic = 'all')) : null), ),
                  disabledHint: const Text('Ładowanie ról...'), ),
               const SizedBox(height: 12),
               ElevatedButton.icon( icon: const Icon(Icons.send), label: const Text('Wyślij Powiadomienie'), onPressed: _isLoadingTopics ? null : _sendPushMessage,
                 style: ElevatedButton.styleFrom( minimumSize: const Size.fromHeight(45), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), textStyle: const TextStyle(fontSize: 16), ), ),
              // --- KONIEC SEKCJI POWIADOMIEŃ ---

              const Divider(height: 32, thickness: 1),

              // *** SEKCJA DODAWANIA KSIĄŻKI (Na dole) ***
              Card( elevation: 2, margin: const EdgeInsets.only(bottom: 24.0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), clipBehavior: Clip.antiAlias,
                child: Padding( padding: const EdgeInsets.all(16.0), child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text( 'Dodaj Egzemplarz Książki', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold), ),
                      const SizedBox(height: 16),
                      Row( children: [
                          Expanded( child: TextField( controller: _manualIsbnController, decoration: InputDecoration( labelText: 'Wpisz ISBN (do testów)', hintText: 'np. 978xxxxxxxxxx', border: const OutlineInputBorder(), suffixIcon: _manualIsbnController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 20), onPressed: () => _manualIsbnController.clear()) : null, ), keyboardType: TextInputType.number, onChanged: (_) => setState((){}), ), ),
                          const SizedBox(width: 8),
                          ElevatedButton( onPressed: (_isLoadingBookData || _isAddingBook) ? null : _fetchManualIsbn, style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)), child: const Text('Pobierz'), ), ], ),
                      const SizedBox(height: 12),
                      Center(child: Text('lub', style: TextStyle(color: Colors.grey[600]))),
                      const SizedBox(height: 12),
                      Center( child: ElevatedButton.icon( icon: const Icon(Icons.barcode_reader), label: const Text('Skanuj Kod ISBN'),
                          style: ElevatedButton.styleFrom( padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), ),
                          onPressed: (_isLoadingBookData || _isAddingBook) ? null : _scanIsbn, ), ),
                      const SizedBox(height: 12),
                      if (_scanError != null) Padding( padding: const EdgeInsets.only(top: 8.0), child: Center( child: Text( _scanError!, style: TextStyle(color: Theme.of(context).colorScheme.error), textAlign: TextAlign.center, ), ), ),
                      if (_foundBook != null) ...[
                        const Divider(height: 24),
                        Text( 'Znaleziona książka:', style: Theme.of(context).textTheme.titleMedium, ),
                        const SizedBox(height: 12),
                        ListTile( leading: ClipRRect( borderRadius: BorderRadius.circular(4), child: _foundBook!.coverUrl != null
                                ? Image.network( _foundBook!.coverUrl!, width: 50, height: 70, fit: BoxFit.cover,
                                    loadingBuilder: (context, child, progress) => progress == null ? child : const SizedBox(width: 50, height: 70, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 50), )
                                : Container( width: 50, height: 70, color: Colors.grey[300], child: const Icon(Icons.book, size: 30, color: Colors.grey), ), ),
                          title: Text(_foundBook!.title, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(_foundBook!.authors.join(', ')), dense: true, ),
                        // *** DODANO POLE NAZWY WŁAŚCICIELA ***
                        const SizedBox(height: 12),
                        TextField(
                          controller: _ownerNameController,
                          decoration: InputDecoration(
                            labelText: 'Właściciel Egzemplarza',
                            hintText: 'Imię/Nazwa (opcjonalnie)',
                            border: const OutlineInputBorder(),
                            suffixIcon: _ownerNameController.text.isNotEmpty
                              ? IconButton(icon: const Icon(Icons.clear, size: 20), onPressed: () => _ownerNameController.clear())
                              : null,
                          ),
                           onChanged: (_) => setState((){}),
                        ),
                        // ************************************
                        const SizedBox(height: 16),
                        Center( child: ElevatedButton.icon(
                            icon: _isAddingBook ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.add_circle_outline),
                            label: const Text('Dodaj Ten Egzemplarz'), style: ElevatedButton.styleFrom( backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), ),
                             onPressed: _isAddingBook ? null : _addBookCopyToLibrary, ), ), ],
                      if (_isLoadingBookData) const Center(child: Padding( padding: EdgeInsets.symmetric(vertical: 16.0), child: CircularProgressIndicator(), )), ], ), ), ),
              // *** KONIEC SEKCJI DODAWANIA KSIĄŻKI ***

              // Przycisk zarządzania użytkownikami (pozostaje na samym dole)
              const Divider(height: 32, thickness: 1),
              Center( child: ElevatedButton.icon( icon: const Icon(Icons.manage_accounts), label: const Text('Zarządzaj Użytkownikami'),
                  style: ElevatedButton.styleFrom( padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), ),
                  onPressed: () { Navigator.push( context, MaterialPageRoute(builder: (context) => const AdminUsersScreen()), ); }, ), ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
