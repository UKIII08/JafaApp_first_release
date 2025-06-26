// lib/screens/book_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Do formatowania dat

import '../models/book_model.dart'; // Upewnij się, że ścieżka jest poprawna

class BookDetailScreen extends StatefulWidget {
  final Book book; // Otrzymuje obiekt książki

  const BookDetailScreen({super.key, required this.book});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isBorrowing = false; // Stan do obsługi ładowania przycisku

  // Funkcja do wypożyczenia książki (bez zmian)
  Future<void> _borrowBook() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Musisz być zalogowany, aby wypożyczyć książkę.')),
        );
      }
      return;
    }
    setState(() { _isBorrowing = true; });
    final bookRef = _firestore.collection('books').doc(widget.book.isbn);
    DocumentReference? copyToBorrowRef;
    try {
      final availableCopiesSnapshot = await _firestore
          .collection('bookCopies')
          .where('bookRef', isEqualTo: bookRef)
          .where('status', isEqualTo: 'available')
          .limit(1)
          .get();
      if (availableCopiesSnapshot.docs.isEmpty) {
        throw Exception('Brak dostępnych egzemplarzy tej książki.');
      }
      copyToBorrowRef = availableCopiesSnapshot.docs.first.reference;
      await _firestore.runTransaction((transaction) async {
        final copySnapshot = await transaction.get(copyToBorrowRef!);
        if (!copySnapshot.exists) {
          throw Exception('Wybrany egzemplarz już nie istnieje.');
        }
        final copyData = copySnapshot.data() as Map<String, dynamic>?;
        if (copyData == null || copyData['status'] != 'available') {
          throw Exception('Ten egzemplarz został już wypożyczony przez kogoś innego.');
        }
        final now = DateTime.now();
        final dueDate = DateTime(now.year, now.month + 1, now.day);
        final dueDateTimestamp = Timestamp.fromDate(dueDate);
        transaction.update(copyToBorrowRef, {
          'status': 'borrowed',
          'borrowedBy': user.uid,
          'borrowedAt': FieldValue.serverTimestamp(),
          'dueDate': dueDateTimestamp,
        });
        print('Pomyślnie zarezerwowano egzemplarz w transakcji: ${copyToBorrowRef.id}');
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pomyślnie wypożyczono "${widget.book.title}"!')),
        );
      }
    } on FirebaseException catch (e) {
       print("Błąd Firestore podczas wypożyczania: ${e.code} - ${e.message}");
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Błąd podczas wypożyczania: ${e.message ?? "Nieznany błąd Firestore"}')),
         );
       }
    } catch (e) {
      print("Inny błąd podczas wypożyczania: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Wystąpił błąd: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isBorrowing = false; });
      }
    }
  }

  // *** NOWA FUNKCJA: Pobiera dane pierwszego dostępnego egzemplarza ***
  Future<BookCopy?> _getFirstAvailableCopy() async {
     final bookRef = _firestore.collection('books').doc(widget.book.isbn);
     try {
        final snapshot = await _firestore
            .collection('bookCopies')
            .where('bookRef', isEqualTo: bookRef)
            .where('status', isEqualTo: 'available')
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty) {
           return BookCopy.fromFirestore(snapshot.docs.first as DocumentSnapshot<Map<String, dynamic>>);
        } else {
           return null; // Brak dostępnych egzemplarzy
        }
     } catch (e) {
        print("Błąd pobierania dostępnego egzemplarza dla ${widget.book.isbn}: $e");
        return null; // Zwróć null w razie błędu
     }
  }
  // *******************************************************************

  @override
  Widget build(BuildContext context) {
    final bookRef = _firestore.collection('books').doc(widget.book.isbn);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book.title, overflow: TextOverflow.ellipsis),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Górna sekcja z okładką i podstawowymi informacjami
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Okładka
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: widget.book.coverUrl != null
                      ? Image.network(
                          widget.book.coverUrl!,
                          width: 120,
                          height: 180,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) =>
                              progress == null ? child : Container(width: 120, height: 180, alignment: Alignment.center, child: const CircularProgressIndicator()),
                          errorBuilder: (context, error, stackTrace) =>
                              Container(width: 120, height: 180, color: Colors.grey[200], child: const Icon(Icons.broken_image, size: 50, color: Colors.grey)),
                        )
                      : Container(width: 120, height: 180, color: Colors.grey[200], child: const Icon(Icons.book, size: 50, color: Colors.grey)),
                ),
                const SizedBox(width: 16),
                // Tytuł, autorzy, wydawca
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.book.title,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.book.authors.join(', '),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[800]),
                      ),
                      const SizedBox(height: 12),
                      if (widget.book.publisher != null && widget.book.publisher!.isNotEmpty)
                        Text('Wydawca: ${widget.book.publisher}', style: Theme.of(context).textTheme.bodyMedium),
                      if (widget.book.publishedDate != null && widget.book.publishedDate!.isNotEmpty)
                        Text('Data publikacji: ${widget.book.publishedDate}', style: Theme.of(context).textTheme.bodyMedium),
                      if (widget.book.pageCount != null && widget.book.pageCount! > 0)
                        Text('Liczba stron: ${widget.book.pageCount}', style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Opis książki
            if (widget.book.description != null && widget.book.description!.isNotEmpty) ...[
              Text(
                'Opis',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                widget.book.description!,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
                textAlign: TextAlign.justify,
              ),
              const SizedBox(height: 24),
            ],

            // Dostępność, Właściciel i przycisk wypożyczenia
            const Divider(),
            const SizedBox(height: 16),
            // Używamy FutureBuilder do pobrania danych pierwszego dostępnego egzemplarza
            FutureBuilder<BookCopy?>(
              future: _getFirstAvailableCopy(),
              builder: (context, copySnapshot) {
                int availableCount = 0; // Domyślnie 0
                String? ownerName; // Nazwa właściciela

                if (copySnapshot.connectionState == ConnectionState.done) {
                  if (copySnapshot.hasData && copySnapshot.data != null) {
                    // Jeśli mamy dane egzemplarza, to znaczy, że jest co najmniej 1 dostępny
                    availableCount = 1; // Wiemy, że jest co najmniej 1
                    // Można by tu pobrać dokładną liczbę, ale dla uproszczenia zostawiamy 1
                    ownerName = copySnapshot.data!.ownerName; // Pobierz nazwę właściciela
                  } else if (copySnapshot.hasError) {
                     print("Błąd pobierania danych egzemplarza w FutureBuilder: ${copySnapshot.error}");
                     // Można pokazać błąd
                  }
                  // Jeśli !hasData, to znaczy, że nie ma dostępnych (availableCount zostaje 0)
                }

                // Zawsze pokazujemy sekcję, ale dostosowujemy zawartość
                return Column(
                  children: [
                    // Wyświetlanie liczby dostępnych (lub informacji o braku)
                    Text(
                      availableCount > 0 ? 'Dostępna' : 'Aktualnie niedostępna',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: availableCount > 0 ? Colors.green.shade800 : Colors.red.shade800,
                        fontWeight: FontWeight.bold
                      ),
                    ),
                    const SizedBox(height: 6),

                    // *** WYŚWIETLANIE WŁAŚCICIELA (jeśli dostępna) ***
                    if (availableCount > 0)
                       (copySnapshot.connectionState == ConnectionState.waiting)
                       ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 1.5)) // Mały loader
                       : (ownerName != null && ownerName.isNotEmpty)
                         ? Text(
                             'Właściciel: $ownerName',
                             style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic, color: Colors.grey[700]),
                           )
                         : const SizedBox.shrink(), // Nie pokazuj nic, jeśli brak nazwy właściciela
                    // **************************************************

                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: _isBorrowing
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.bookmark_add_outlined),
                      label: const Text('Wypożycz'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        textStyle: const TextStyle(fontSize: 18),
                        disabledBackgroundColor: Colors.grey.shade300,
                      ),
                      // Wyłącz przycisk, jeśli brak dostępnych lub trwa wypożyczanie
                      // Sprawdzamy stan połączenia FutureBuilder, aby uniknąć wypożyczania przed załadowaniem danych
                      onPressed: (availableCount > 0 && !_isBorrowing && copySnapshot.connectionState == ConnectionState.done)
                                  ? _borrowBook
                                  : null,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
