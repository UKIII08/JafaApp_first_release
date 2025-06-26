// lib/services/google_books_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/book_model.dart'; // Upewnij się, że ścieżka jest poprawna

class GoogleBooksService {
  final String _baseUrl = 'https://www.googleapis.com/books/v1/volumes';
  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _getApiKey() {
    final apiKey = _remoteConfig.getString('google_books_api_key');
    if (apiKey.isEmpty || apiKey == 'TWOJ_DOMYSLNY_KLUCZ_API_LUB_PUSTY_STRING') {
      print('BŁĄD: Klucz API Google Books nie został pobrany z Firebase Remote Config lub jest nieprawidłowy!');
      throw Exception('Klucz API Google Books nie jest dostępny w Remote Config.');
    }
    return apiKey;
  }

  String? _getQuotaUser() {
    return _auth.currentUser?.uid;
  }

  Future<Book?> fetchBookByIsbn(String isbn) async {
    final apiKey = _getApiKey();
    final quotaUser = _getQuotaUser();
    // *** DODANO KOD KRAJU ***
    const String countryCode = 'PL'; // Zahardkodowany kod kraju (Polska)

    final cleanIsbn = isbn.replaceAll('-', '').trim();

    // Budowanie URL z parametrami
    final queryParameters = {
      'q': 'isbn:$cleanIsbn',
      'key': apiKey,
      'country': countryCode, // *** DODANO PARAMETR country ***
      // Dodaj quotaUser tylko jeśli nie jest nullem
      if (quotaUser != null) 'quotaUser': quotaUser,
    };

    // Użyj Uri.https do zbudowania bezpiecznego URL z parametrami
    final url = Uri.https('www.googleapis.com', '/books/v1/volumes', queryParameters);
    // ***********************************************************

    print('Wysyłanie zapytania do Google Books API (ISBN): $url'); // URL będzie teraz zawierał quotaUser i country

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final totalItems = data['totalItems'] as int?;

        if (totalItems != null && totalItems > 0) {
          final items = data['items'] as List<dynamic>?;
          if (items != null && items.isNotEmpty) {
            final bookData = items[0] as Map<String, dynamic>;
            final identifiers = (bookData['volumeInfo']?['industryIdentifiers'] as List<dynamic>?)?.cast<Map<String, dynamic>>();
            String? foundIsbn13 = identifiers?.firstWhere((id) => id['type'] == 'ISBN_13', orElse: () => {})['identifier'];
            String? foundIsbn10 = identifiers?.firstWhere((id) => id['type'] == 'ISBN_10', orElse: () => {})['identifier'];
            final resultIsbn = foundIsbn13 ?? foundIsbn10 ?? isbn;
            return Book.fromGoogleBooksJson(resultIsbn, bookData);
          }
        }
        print('Google Books API nie znalazło książki dla ISBN: $isbn (totalItems: $totalItems)');
        return null;
      } else {
        print('Błąd zapytania do Google Books API (ISBN): ${response.statusCode}');
        print('Odpowiedź: ${response.body}');
        throw Exception('Błąd podczas pobierania danych z Google Books API: ${response.statusCode}');
      }
    } catch (e) {
      print('Wystąpił błąd podczas komunikacji z Google Books API (ISBN): $e');
      throw Exception('Błąd sieci lub parsowania podczas komunikacji z Google Books API: $e');
    }
  }

  Future<List<Book>> searchBooks(String query, {int maxResults = 10}) async {
    final apiKey = _getApiKey();
    final quotaUser = _getQuotaUser();
    // *** DODANO KOD KRAJU ***
    const String countryCode = 'PL';

    final encodedQuery = Uri.encodeComponent(query);

    // Budowanie URL z parametrami
    final queryParameters = {
      'q': encodedQuery,
      'maxResults': maxResults.toString(), // Konwertuj na string
      'key': apiKey,
      'country': countryCode, // *** DODANO PARAMETR country ***
      if (quotaUser != null) 'quotaUser': quotaUser,
    };
    final url = Uri.https('www.googleapis.com', '/books/v1/volumes', queryParameters);
    // ***********************************************************

    print('Wysyłanie zapytania do Google Books API (Search): $url');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final totalItems = data['totalItems'] as int?;
        List<Book> books = [];

        if (totalItems != null && totalItems > 0) {
          final items = data['items'] as List<dynamic>?;
          if (items != null) {
            for (var itemData in items) {
              final bookData = itemData as Map<String, dynamic>;
              final volumeInfo = bookData['volumeInfo'] as Map<String, dynamic>?;
              final identifiers = (volumeInfo?['industryIdentifiers'] as List<dynamic>?)?.cast<Map<String, dynamic>>();

              if (identifiers != null) {
                 String? isbn13 = identifiers.firstWhere((id) => id['type'] == 'ISBN_13', orElse: () => {})['identifier'];
                 String? isbn10 = identifiers.firstWhere((id) => id['type'] == 'ISBN_10', orElse: () => {})['identifier'];
                 final String? resultIsbn = isbn13 ?? isbn10;

                 if (resultIsbn != null && resultIsbn.isNotEmpty) {
                    books.add(Book.fromGoogleBooksJson(resultIsbn, bookData));
                 } else { print("Pominięto książkę bez ISBN w wynikach wyszukiwania: ${volumeInfo?['title']}"); }
              } else { print("Pominięto książkę bez identyfikatorów w wynikach wyszukiwania: ${volumeInfo?['title']}"); }
            }
          }
        }
        return books;
      } else {
        print('Błąd zapytania do Google Books API (Search): ${response.statusCode}');
        print('Odpowiedź: ${response.body}');
        throw Exception('Błąd podczas wyszukiwania książek w Google Books API: ${response.statusCode}');
      }
    } catch (e) {
       print('Wystąpił błąd podczas komunikacji z Google Books API (Search): $e');
       throw Exception('Błąd sieci lub parsowania podczas komunikacji z Google Books API: $e');
    }
  }
}
