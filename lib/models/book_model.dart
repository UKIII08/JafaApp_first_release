// lib/models/book_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Book {
  final String isbn; // Używany jako ID dokumentu w kolekcji 'books'
  final String title;
  final List<String> authors;
  final String? description;
  final String? coverUrl;
  final String? publisher;
  final String? publishedDate;
  final int? pageCount;
  final List<String>? categories;
  final String? googleBooksId; // ID z Google Books API
  final Timestamp? addedAt; // Kiedy książka została dodana do kolekcji 'books'

  Book({
    required this.isbn,
    required this.title,
    required this.authors,
    this.description,
    this.coverUrl,
    this.publisher,
    this.publishedDate,
    this.pageCount,
    this.categories,
    this.googleBooksId,
    this.addedAt,
  });

  // Metoda do konwersji danych z Firestore na obiekt Book
  factory Book.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    final isbn = snapshot.id;

    List<String> authorsList = [];
    if (data?['authors'] is List) {
      authorsList = List<String>.from(data!['authors'].map((item) => item.toString()));
    }

    List<String> categoriesList = [];
     if (data?['categories'] is List) {
      categoriesList = List<String>.from(data!['categories'].map((item) => item.toString()));
    }

    return Book(
      isbn: isbn,
      title: data?['title'] as String? ?? 'Brak tytułu',
      authors: authorsList,
      description: data?['description'] as String?,
      coverUrl: data?['coverUrl'] as String?,
      publisher: data?['publisher'] as String?,
      publishedDate: data?['publishedDate'] as String?,
      pageCount: data?['pageCount'] as int?,
      categories: categoriesList,
      googleBooksId: data?['googleBooksId'] as String?,
      addedAt: data?['addedAt'] as Timestamp?,
    );
  }

  // Metoda do konwersji obiektu Book na mapę dla Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'authors': authors,
      if (description != null) 'description': description,
      if (coverUrl != null) 'coverUrl': coverUrl,
      if (publisher != null) 'publisher': publisher,
      if (publishedDate != null) 'publishedDate': publishedDate,
      if (pageCount != null) 'pageCount': pageCount,
      if (categories != null && categories!.isNotEmpty) 'categories': categories,
      if (googleBooksId != null) 'googleBooksId': googleBooksId,
      'addedAt': addedAt ?? FieldValue.serverTimestamp(),
    };
  }

  // Metoda do tworzenia obiektu Book z danych JSON z Google Books API
  factory Book.fromGoogleBooksJson(String isbn, Map<String, dynamic> json) {
    final volumeInfo = json['volumeInfo'] as Map<String, dynamic>? ?? {};
    final imageLinks = volumeInfo['imageLinks'] as Map<String, dynamic>?;
    String? cover = imageLinks?['thumbnail'] as String? ?? imageLinks?['smallThumbnail'] as String?;
    if (cover != null && cover.startsWith('http://')) {
      cover = cover.replaceFirst('http://', 'https://');
    }

     List<String> authorsList = [];
    if (volumeInfo['authors'] is List) {
       authorsList = List<String>.from(volumeInfo['authors'].map((item) => item.toString()));
    } else if (volumeInfo['authors'] != null) {
       authorsList = [volumeInfo['authors'].toString()];
    }
     if (authorsList.isEmpty) authorsList = ['Brak autora'];

     List<String> categoriesList = [];
     if (volumeInfo['categories'] is List) {
        categoriesList = List<String>.from(volumeInfo['categories'].map((item) => item.toString()));
     } else if (volumeInfo['categories'] != null) {
        categoriesList = [volumeInfo['categories'].toString()];
     }

    return Book(
      isbn: isbn,
      googleBooksId: json['id'] as String?,
      title: volumeInfo['title'] as String? ?? 'Brak tytułu',
      authors: authorsList,
      description: volumeInfo['description'] as String?,
      coverUrl: cover,
      publisher: volumeInfo['publisher'] as String?,
      publishedDate: volumeInfo['publishedDate'] as String?,
      pageCount: volumeInfo['pageCount'] as int?,
      categories: categoriesList.isNotEmpty ? categoriesList : null,
    );
  }
}

// Model dla egzemplarza książki
class BookCopy {
  final String id; // ID dokumentu z Firestore
  final DocumentReference bookRef; // Referencja do 'books'
  final String isbn;
  final int copyIndex;
  final String status; // 'available', 'borrowed', 'unavailable'
  final String addedBy; // UID admina, który dodał
  final Timestamp addedAt;
  final String? borrowedBy; // UID użytkownika
  final Timestamp? borrowedAt;
  final Timestamp? dueDate;
  // *** NOWE POLA WŁAŚCICIELA ***
  final String ownerId; // UID właściciela egzemplarza
  final String? ownerName; // Nazwa wyświetlana właściciela (snapshot w momencie dodania)
  // ***************************

  BookCopy({
    required this.id,
    required this.bookRef,
    required this.isbn,
    required this.copyIndex,
    required this.status,
    required this.addedBy, // Kto fizycznie dodał do systemu
    required this.addedAt,
    required this.ownerId, // Kto jest właścicielem
    this.ownerName, // Opcjonalna nazwa właściciela
    this.borrowedBy,
    this.borrowedAt,
    this.dueDate,
  });

  factory BookCopy.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null) {
       throw Exception("Brak danych dla dokumentu BookCopy: ${snapshot.id}");
    }
    return BookCopy(
      id: snapshot.id,
      bookRef: data['bookRef'] as DocumentReference,
      isbn: data['isbn'] as String,
      copyIndex: data['copyIndex'] as int,
      status: data['status'] as String,
      addedBy: data['addedBy'] as String,
      addedAt: data['addedAt'] as Timestamp,
      // *** ODCZYT PÓL WŁAŚCICIELA ***
      // Używamy ?? aby zapewnić fallback dla starych danych bez ownerId
      ownerId: data['ownerId'] as String? ?? data['addedBy'] as String,
      ownerName: data['ownerName'] as String?,
      // ***************************
      borrowedBy: data['borrowedBy'] as String?,
      borrowedAt: data['borrowedAt'] as Timestamp?,
      dueDate: data['dueDate'] as Timestamp?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'bookRef': bookRef,
      'isbn': isbn,
      'copyIndex': copyIndex,
      'status': status,
      'addedBy': addedBy,
      'addedAt': addedAt,
      // *** ZAPIS PÓL WŁAŚCICIELA ***
      'ownerId': ownerId,
      if (ownerName != null) 'ownerName': ownerName,
      // ***************************
      'borrowedBy': borrowedBy,
      'borrowedAt': borrowedAt,
      'dueDate': dueDate,
    };
  }
}
