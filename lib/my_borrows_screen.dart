// lib/screens/my_borrows_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Do formatowania dat
import 'package:shimmer/shimmer.dart'; // Efekt ładowania

import '../models/book_model.dart'; // Upewnij się, że ścieżka jest poprawna
import 'book_detail_screen.dart'; // Do nawigacji po kliknięciu

class MyBorrowsScreen extends StatefulWidget {
  const MyBorrowsScreen({super.key});

  @override
  State<MyBorrowsScreen> createState() => _MyBorrowsScreenState();
}

class _MyBorrowsScreenState extends State<MyBorrowsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser; // Przechowuje bieżącego użytkownika

  // Mapa do przechowywania stanu ładowania dla każdego przycisku "Zwróć"
  final Map<String, bool> _isReturningMap = {};

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser; // Pobierz użytkownika przy inicjalizacji
  }

  // Funkcja do zwrócenia książki (egzemplarza)
  Future<void> _returnBook(String copyId) async {
    if (_currentUser == null) return; // Powinno być sprawdzone wcześniej, ale dla pewności

    // Ustaw stan ładowania dla konkretnego przycisku
    setState(() { _isReturningMap[copyId] = true; });

    final copyRef = _firestore.collection('bookCopies').doc(copyId);

    try {
      // Użyj transakcji dla bezpieczeństwa
      await _firestore.runTransaction((transaction) async {
        // 1. Sprawdź, czy dokument nadal istnieje i jest wypożyczony przez tego użytkownika
        final copySnapshot = await transaction.get(copyRef);
        if (!copySnapshot.exists) {
          throw Exception('Ten egzemplarz już nie istnieje.');
        }
        final data = copySnapshot.data();
        if (data?['borrowedBy'] != _currentUser!.uid || data?['status'] != 'borrowed') {
          throw Exception('Nie możesz zwrócić tego egzemplarza.');
        }

        // 2. Zaktualizuj dokument egzemplarza
        transaction.update(copyRef, {
          'status': 'available', // Zmień status na dostępny
          'borrowedBy': null,    // Wyczyść ID użytkownika
          'borrowedAt': null,    // Wyczyść datę wypożyczenia
          'dueDate': null,       // Wyczyść termin zwrotu
        });
        print('Pomyślnie zwrócono egzemplarz: $copyId');
      });

      // Pomyślnie zakończono transakcję
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pomyślnie zwrócono książkę!')),
        );
      }

    } on FirebaseException catch (e) {
       print("Błąd Firestore podczas zwracania: ${e.code} - ${e.message}");
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Błąd podczas zwracania: ${e.message ?? "Nieznany błąd Firestore"}')),
         );
       }
    } catch (e) {
      print("Inny błąd podczas zwracania: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Wystąpił błąd: ${e.toString()}')),
        );
      }
    } finally {
      // Zresetuj stan ładowania dla konkretnego przycisku, jeśli widget nadal istnieje
      if (mounted) {
        setState(() { _isReturningMap[copyId] = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      // Jeśli użytkownik nie jest zalogowany, pokaż komunikat
      // (AuthWrapper powinien zapobiec tej sytuacji, ale to dodatkowe zabezpieczenie)
      return Scaffold(
        appBar: AppBar(title: const Text('Moje Wypożyczenia')),
        body: const Center(
          child: Text('Musisz być zalogowany, aby zobaczyć swoje wypożyczenia.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moje Wypożyczenia'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Pobierz egzemplarze wypożyczone przez bieżącego użytkownika
        stream: _firestore
            .collection('bookCopies')
            .where('borrowedBy', isEqualTo: _currentUser!.uid)
            .where('status', isEqualTo: 'borrowed') // Upewnij się, że status to 'borrowed'
            .snapshots(),
        builder: (context, copiesSnapshot) {
          if (copiesSnapshot.connectionState == ConnectionState.waiting) {
            return _buildShimmerList(); // Pokaż shimmer podczas ładowania
          }
          if (copiesSnapshot.hasError) {
            print("Błąd StreamBuilder (MyBorrows): ${copiesSnapshot.error}");
            return Center(child: Text('Błąd ładowania wypożyczeń: ${copiesSnapshot.error}'));
          }
          if (!copiesSnapshot.hasData || copiesSnapshot.data!.docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Nie masz aktualnie żadnych wypożyczonych książek.', textAlign: TextAlign.center),
              )
            );
          }

          final borrowedCopiesDocs = copiesSnapshot.data!.docs;

          // Lista do przechowywania Future dla każdego elementu listy
          // Łączy dane egzemplarza (copy) i dane książki (book)
          List<Future<Map<String, dynamic>?>> futures = borrowedCopiesDocs.map((copyDoc) async {
             final copyData = copyDoc.data() as Map<String, dynamic>;
             final bookRef = copyData['bookRef'] as DocumentReference?;
             if (bookRef == null) return null; // Pomiń, jeśli brakuje referencji

             try {
                final bookSnapshot = await bookRef.get();
                if (bookSnapshot.exists) {
                   final book = Book.fromFirestore(bookSnapshot as DocumentSnapshot<Map<String, dynamic>>);
                   return {'copy': BookCopy.fromFirestore(copyDoc as DocumentSnapshot<Map<String, dynamic>>), 'book': book};
                } else {
                   print("Książka dla referencji ${bookRef.id} nie istnieje.");
                   return null; // Pomiń, jeśli książka nie istnieje
                }
             } catch (e) {
                print("Błąd pobierania książki ${bookRef.id} dla egzemplarza ${copyDoc.id}: $e");
                return null; // Pomiń w razie błędu
             }
          }).toList();


          // Użyj FutureBuilder do poczekania na wszystkie dane
          return FutureBuilder<List<Map<String, dynamic>?>>(
             future: Future.wait(futures),
             builder: (context, allDetailsSnapshot) {
                if (allDetailsSnapshot.connectionState == ConnectionState.waiting) {
                   return _buildShimmerList();
                }
                 if (allDetailsSnapshot.hasError) {
                   print("Błąd FutureBuilder (allDetails): ${allDetailsSnapshot.error}");
                   return Center(child: Text('Błąd ładowania szczegółów wypożyczeń: ${allDetailsSnapshot.error}'));
                 }

                 // Odfiltruj nulle (błędy lub brakujące dane)
                 final validBorrows = allDetailsSnapshot.data?.where((item) => item != null).cast<Map<String, dynamic>>().toList() ?? [];

                 if (validBorrows.isEmpty) {
                    return const Center(child: Text('Nie udało się załadować informacji o wypożyczonych książkach.'));
                 }

                 // Sortowanie (np. wg terminu zwrotu rosnąco)
                 validBorrows.sort((a, b) {
                     final dueDateA = (a['copy'] as BookCopy).dueDate;
                     final dueDateB = (b['copy'] as BookCopy).dueDate;
                     if (dueDateA == null && dueDateB == null) return 0;
                     if (dueDateA == null) return 1; // Null na końcu
                     if (dueDateB == null) return -1; // Null na końcu
                     return dueDateA.compareTo(dueDateB);
                 });


                // Wyświetl listę wypożyczonych książek
                return ListView.builder(
                  padding: const EdgeInsets.all(12.0),
                  itemCount: validBorrows.length,
                  itemBuilder: (context, index) {
                    final borrowData = validBorrows[index];
                    final copy = borrowData['copy'] as BookCopy;
                    final book = borrowData['book'] as Book;

                    // Formatowanie daty zwrotu
                    String dueDateString = 'Brak terminu';
                    bool isOverdue = false;
                    if (copy.dueDate != null) {
                      dueDateString = DateFormat('dd.MM.yyyy', 'pl_PL').format(copy.dueDate!.toDate());
                      // Sprawdź, czy termin minął (porównaj z początkiem dzisiejszego dnia)
                      final today = DateTime.now();
                      final startOfToday = DateTime(today.year, today.month, today.day);
                      isOverdue = copy.dueDate!.toDate().isBefore(startOfToday);
                    }

                    // Sprawdź stan ładowania dla tego konkretnego przycisku
                    final bool isCurrentlyReturning = _isReturningMap[copy.id] ?? false;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12.0),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                         borderRadius: BorderRadius.circular(10),
                         // Czerwona ramka dla przeterminowanych
                         side: isOverdue ? BorderSide(color: Colors.red.shade300, width: 1.5) : BorderSide.none,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            InkWell( // Cały górny wiersz klikalny, prowadzi do szczegółów
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => BookDetailScreen(book: book)),
                                );
                              },
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Okładka
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: book.coverUrl != null
                                        ? Image.network(
                                            book.coverUrl!,
                                            width: 70,
                                            height: 100,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => Container(width: 70, height: 100, color: Colors.grey[200], child: const Icon(Icons.broken_image, color: Colors.grey)),
                                          )
                                        : Container(width: 70, height: 100, color: Colors.grey[200], child: const Icon(Icons.book, color: Colors.grey)),
                                  ),
                                  const SizedBox(width: 16),
                                  // Informacje
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          book.title,
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          book.authors.join(', '),
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Termin zwrotu: $dueDateString',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: isOverdue ? Colors.red.shade700 : Colors.grey.shade800,
                                            fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                        if (isOverdue)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4.0),
                                            child: Text(
                                              'PO TERMINIE!',
                                              style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, color: Colors.grey), // Wskazuje klikalność
                                ],
                              ),
                            ),
                            const Divider(height: 20), // Separator przed przyciskiem
                            // Przycisk "Zwróć"
                            SizedBox( // Ogranicz szerokość przycisku
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: isCurrentlyReturning
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.assignment_return_outlined, size: 20),
                                label: const Text('Zwróć'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                // Wyłącz przycisk podczas operacji zwracania
                                onPressed: isCurrentlyReturning ? null : () => _returnBook(copy.id),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
             },
          );
        },
      ),
    );
  }

  // Widget pomocniczy do budowania listy z efektem shimmer
  Widget _buildShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12.0),
      itemCount: 3, // Mniej elementów dla "Moje wypożyczenia"
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Card(
          margin: const EdgeInsets.only(bottom: 12.0),
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Placeholder okładki
                    Container(width: 70, height: 100, color: Colors.white),
                    const SizedBox(width: 16),
                    // Placeholder informacji
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(width: double.infinity, height: 16.0, color: Colors.white),
                          const SizedBox(height: 8),
                          Container(width: double.infinity * 0.7, height: 14.0, color: Colors.white),
                          const SizedBox(height: 10),
                          Container(width: 120, height: 12.0, color: Colors.white), // Placeholder daty
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                // Placeholder przycisku
                Container(width: double.infinity, height: 40, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
