import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Potrzebne dla Timestamp
import 'package:intl/intl.dart'; // Potrzebne dla formatowania daty

class NewsDetailScreen extends StatelessWidget {
  final String title;
  final String content;
  final Timestamp? timestamp; // Przekazujemy Timestamp dla elastyczności
  final String? imageUrl;

  const NewsDetailScreen({
    super.key,
    required this.title,
    required this.content,
    this.timestamp,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    // Formatowanie daty wewnątrz ekranu szczegółów
    final formattedDate = timestamp != null
        ? DateFormat('dd.MM.yyyy HH:mm', 'pl_PL').format(timestamp!.toDate())
        : 'Brak daty';

    return Scaffold(
      appBar: AppBar(
        title: Text(title), // Tytuł aktualności jako tytuł AppBar
        flexibleSpace: Container( // Opcjonalny gradient w AppBar
          decoration: BoxDecoration(
          ),
        ),
      ),
      body: SingleChildScrollView( // Umożliwia przewijanie, jeśli treść jest długa
        padding: const EdgeInsets.all(16.0), // Dodaj padding wokół całej treści
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Obrazek (jeśli istnieje)
            if (imageUrl != null && Uri.tryParse(imageUrl!)?.isAbsolute == true)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10.0),
                  child: Image.network(
                    imageUrl!,
                    width: double.infinity, // Obrazek na całą szerokość
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 200,
                        color: Colors.grey[300],
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      print("Błąd ładowania obrazka w szczegółach: $error");
                      return Container(
                        height: 200,
                        color: Colors.grey[300],
                        child: const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 50)),
                      );
                    },
                  ),
                ),
              ),
            // Tytuł
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColorDark),
            ),
            const SizedBox(height: 12),
            // Data publikacji
            Text(
              'Opublikowano: $formattedDate',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                    fontStyle: FontStyle.italic,
                  ),
            ),
            const SizedBox(height: 20),
            // Pełna treść aktualności
            Text(
              content,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 20), // Dodatkowy odstęp na dole
          ],
        ),
      ),
    );
  }
}