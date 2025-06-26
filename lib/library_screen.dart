// lib/screens/library_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shimmer/shimmer.dart'; // Do efektu ładowania
import 'dart:async'; // Dla debounce

import '../models/book_model.dart'; // Upewnij się, że ścieżka jest poprawna
import 'book_detail_screen.dart'; // Ekran szczegółów książki
import 'my_borrows_screen.dart'; // Ekran moich wypożyczeń

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Kontroler i stan dla wyszukiwarki
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  Timer? _debounce; // Timer do opóźnienia wyszukiwania

  // Cache dla nazw użytkowników (UID -> Nazwa)
  final Map<String, String> _userNamesCache = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text.trim();
        });
      }
    });
  }

  Future<Map<DocumentReference, Book>> _fetchBookDetails(List<DocumentReference> bookRefs) async {
    if (bookRefs.isEmpty) return {};
    final uniqueRefs = bookRefs.toSet().toList();
    final List<String> uniqueIds = uniqueRefs.map((ref) => ref.id).toList();
    // Upewnij się, że lista ID nie jest pusta przed zapytaniem 'whereIn'
    if (uniqueIds.isEmpty) return {};
    final QuerySnapshot<Map<String, dynamic>> bookSnapshots = await _firestore
        .collection('books').where(FieldPath.documentId, whereIn: uniqueIds).get();
    final Map<DocumentReference, Book> bookDetails = {};
    for (QueryDocumentSnapshot<Map<String, dynamic>> doc in bookSnapshots.docs) {
       try { bookDetails[doc.reference] = Book.fromFirestore(doc); }
       catch (e) { print("Błąd parsowania książki ${doc.id}: $e"); }
    }
    return bookDetails;
  }

  Future<Map<String, dynamic>> _getBookCopiesStatus(DocumentReference bookRef) async {
    int availableCount = 0;
    String? borrowedByUserId;
    try {
      final QuerySnapshot copiesSnapshot = await _firestore
          .collection('bookCopies')
          .where('bookRef', isEqualTo: bookRef)
          .get();
      for (var doc in copiesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          if (data['status'] == 'available') {
            availableCount++;
          } else if (data['status'] == 'borrowed' && borrowedByUserId == null) {
            borrowedByUserId = data['borrowedBy'] as String?;
          }
        }
      }
    } catch (e) {
      print("Błąd podczas pobierania statusu kopii dla ${bookRef.id}: $e");
    }
    return { 'availableCount': availableCount, 'borrowedByUserId': borrowedByUserId, };
  }

  Future<String> _getUserDisplayName(String userId) async {
    if (_userNamesCache.containsKey(userId)) { return _userNamesCache[userId]!; }
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        String name = data?['displayName'] as String? ?? data?['email'] as String? ?? 'Nieznany użytkownik';
        if (name.contains(' ') && data?['displayName'] != null) {
           name = (data!['displayName'] as String).split(' ').first;
        }
        _userNamesCache[userId] = name;
        return name;
      } else { return 'Nieznany użytkownik'; }
    } catch (e) {
      print("Błąd pobierania nazwy użytkownika $userId: $e");
      return 'Błąd ładowania';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteka'),
        actions: [
          IconButton(
            icon: const Icon(Icons.collections_bookmark_outlined),
            tooltip: 'Moje Wypożyczenia',
            onPressed: () {
              final user = _auth.currentUser;
              if (user != null) {
                Navigator.push( context, MaterialPageRoute(builder: (context) => const MyBorrowsScreen()), );
              } else {
                 ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text('Musisz być zalogowany.')), );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // --- Wyszukiwarka ---
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Szukaj po tytule...',
                hintText: 'Wpisz tytuł książki...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder( borderRadius: BorderRadius.circular(10.0), ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton( icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); }, )
                    : null,
              ),
            ),
          ),
          // --- Lista Książek ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('books').snapshots(),
              builder: (context, booksSnapshot) {
                if (booksSnapshot.connectionState == ConnectionState.waiting) {
                  return _buildShimmerList(); // Zaktualizowany shimmer bez okładki
                }
                if (booksSnapshot.hasError) {
                  print("Błąd StreamBuilder (books): ${booksSnapshot.error}");
                  return Center(child: Text('Błąd ładowania książek: ${booksSnapshot.error}'));
                }
                if (!booksSnapshot.hasData || booksSnapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Brak książek w bazie danych.'));
                }

                final allBooks = booksSnapshot.data!.docs
                    .map((doc) {
                       try { return Book.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>); }
                       catch(e) { print("Błąd parsowania książki ${doc.id} w głównym strumieniu: $e"); return null; }
                     })
                    .where((book) => book != null)
                    .cast<Book>()
                    .toList();

                final filteredBooks = _searchQuery.isEmpty
                    ? allBooks
                    : allBooks.where((book) => book.title.toLowerCase().contains(_searchQuery.toLowerCase()) ).toList();

                filteredBooks.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

                if (filteredBooks.isEmpty) {
                   return Center(child: Text(_searchQuery.isEmpty ? 'Brak książek.' : 'Nie znaleziono książek pasujących do wyszukiwania.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(left: 12.0, right: 12.0, bottom: 12.0),
                  itemCount: filteredBooks.length,
                  itemBuilder: (context, index) {
                    final book = filteredBooks[index];
                    final bookRef = _firestore.collection('books').doc(book.isbn);

                    return Card(
                       margin: const EdgeInsets.only(bottom: 12.0),
                       elevation: 3,
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                       clipBehavior: Clip.antiAlias,
                       child: InkWell( // Zmieniono na InkWell dla efektu kliknięcia
                         onTap: () {
                           Navigator.push( context, MaterialPageRoute( builder: (context) => BookDetailScreen(book: book), ), );
                         },
                         child: Padding( // Dodano Padding wokół ListTile
                           padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                           child: ListTile(
                              // *** ZMIANA: Usunięto okładkę, używamy ListTile ***
                              contentPadding: EdgeInsets.zero, // Usunięcie domyślnego paddingu ListTile
                              title: Text( book.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis, ),
                              subtitle: Column( // Kolumna dla autora i statusu
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                   const SizedBox(height: 4),
                                   Text( book.authors.join(', '), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]), maxLines: 1, overflow: TextOverflow.ellipsis, ),
                                   const SizedBox(height: 8),
                                   FutureBuilder<Map<String, dynamic>>(
                                     key: ValueKey(bookRef.id),
                                     future: _getBookCopiesStatus(bookRef),
                                     builder: (context, statusSnapshot) {
                                       if (statusSnapshot.connectionState == ConnectionState.waiting) {
                                         return const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 1.5));
                                       }
                                       if (statusSnapshot.hasError) {
                                          return Text('Błąd statusu', style: TextStyle(color: Colors.red.shade700, fontSize: 12));
                                       }
                                       final statusData = statusSnapshot.data ?? {'availableCount': 0, 'borrowedByUserId': null};
                                       final availableCount = statusData['availableCount'] as int;
                                       final borrowedByUserId = statusData['borrowedByUserId'] as String?;
                                       if (availableCount > 0) {
                                         return Text( 'Dostępnych egzemplarzy: $availableCount', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.green.shade700, fontWeight: FontWeight.w600), );
                                       } else if (borrowedByUserId != null) {
                                         return FutureBuilder<String>(
                                            future: _getUserDisplayName(borrowedByUserId),
                                            builder: (context, nameSnapshot) {
                                               final borrowerName = nameSnapshot.data ?? 'Ładowanie...';
                                               return Text( 'Wypożyczona przez: $borrowerName', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.orange.shade800, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis, );
                                            }
                                         );
                                       } else {
                                         return Text( 'Brak dostępnych egzemplarzy', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red.shade700, fontWeight: FontWeight.w600), );
                                       }
                                     },
                                   ),
                                ],
                              ),
                              trailing: const Icon(Icons.chevron_right, color: Colors.grey), // Ikona strzałki
                              // *** KONIEC ZMIAN ***
                           ),
                         ),
                       ),
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

  // *** ZMIANA: Zaktualizowany shimmer bez okładki ***
  Widget _buildShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12.0),
      itemCount: 6,
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Card(
          margin: const EdgeInsets.only(bottom: 12.0),
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0), // Dopasowany padding
            // Używamy ListTile dla spójności z rzeczywistym widokiem
            child: ListTile(
               contentPadding: EdgeInsets.zero,
               title: Container(width: double.infinity, height: 16.0, color: Colors.white),
               subtitle: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   const SizedBox(height: 8),
                   Container(width: double.infinity * 0.7, height: 14.0, color: Colors.white),
                   const SizedBox(height: 10),
                   Container(width: 100, height: 12.0, color: Colors.white),
                 ],
               ),
               trailing: Icon(Icons.chevron_right, color: Colors.grey[300]), // Placeholder dla ikony
            ),
          ),
        ),
      ),
    );
  }
  // *** KONIEC ZMIAN W SHIMMER ***
}
