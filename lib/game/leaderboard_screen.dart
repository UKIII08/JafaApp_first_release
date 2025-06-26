// lib/game/leaderboard_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Do formatowania daty

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Funkcja do formatowania Timestamp na czytelną datę
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      return DateFormat('dd.MM.yyyy HH:mm', 'pl_PL').format(timestamp.toDate());
    } catch (e) {
      print("Błąd formatowania daty: $e");
      return 'Błąd daty';
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? currentUserId = _auth.currentUser?.uid;
    // --- VVV ZMIANA KOLORU AKCENTU NA NIEBIESKI VVV ---
    const Color accentColor = Color(0xFF00B0FF); // Jaskrawy niebieski (Light Blue Accent 400)
    // --- ^^^ KONIEC ZMIANY KOLORU AKCENTU ^^^ ---
    final Color darkBackgroundColor = Colors.grey[900]!;
    final Color listTileColor = Colors.grey[850]!;
    final Color highlightTileColor = accentColor.withOpacity(0.15);

    return Scaffold(
      backgroundColor: darkBackgroundColor, // Ciemne tło dla całego ekranu
      appBar: AppBar(
        title: const Text(
          'RANKING GRACZY', // Wielkie litery dla stylu
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, color: accentColor), // Użycie nowego accentColor
        ),
        backgroundColor: Colors.grey[850], // Ciemniejszy AppBar
        foregroundColor: Colors.white, // Biały tekst i ikony w AppBar
        elevation: 0, // Usuwamy cień
        centerTitle: true, // Wyśrodkowanie tytułu
      ),
      body: Column(
        children: [
          // Sekcja z najlepszym wynikiem zalogowanego użytkownika
          if (currentUserId != null)
            _buildPersonalBestSection(currentUserId, accentColor, listTileColor), // Przekazanie nowego accentColor

          // Nagłówek Top Graczy
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 12.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'TOP 20',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withOpacity(0.9),
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),

          // Lista Top Graczy
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('gameScores')
                  .orderBy('bestScore', descending: true)
                  .limit(20)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: accentColor)); // Użycie nowego accentColor
                }
                if (snapshot.hasError) {
                  print("Błąd ładowania rankingu: ${snapshot.error}");
                  return Center(child: Text('Nie można załadować rankingu.', style: TextStyle(color: Colors.red[300])));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('Brak wyników w rankingu.', style: TextStyle(color: Colors.grey[400])));
                }

                final scoreDocs = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  itemCount: scoreDocs.length,
                  itemBuilder: (context, index) {
                    final docData = scoreDocs[index].data();
                    final scoreData = (docData is Map<String, dynamic>) ? docData : <String, dynamic>{};

                    final String docUserId = scoreDocs[index].id;
                    final String displayName = scoreData['displayName'] as String? ?? 'Gracz';
                    final int bestScore = scoreData['bestScore'] as int? ?? 0;

                    final bool isCurrentUser = currentUserId == docUserId;
                    // Użycie nowego accentColor do wyróżnienia
                    final Color nameColor = isCurrentUser ? accentColor : Colors.white.withOpacity(0.85);
                    final Color scoreColor = isCurrentUser ? accentColor : Colors.white;
                    final FontWeight nameWeight = isCurrentUser ? FontWeight.bold : FontWeight.normal;
                    final FontWeight scoreWeight = isCurrentUser ? FontWeight.bold : FontWeight.w600;
                    // Użycie nowego accentColor do tła i ramki
                    final Color tileBgColor = isCurrentUser ? highlightTileColor : listTileColor;
                    final BorderSide borderSide = isCurrentUser
                          ? BorderSide(color: accentColor.withOpacity(0.5), width: 1)
                          : BorderSide.none;

                    return Card(
                      color: tileBgColor,
                      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                      elevation: isCurrentUser ? 4.0 : 1.0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        side: borderSide, // Użycie zdefiniowanej ramki
                      ),
                      child: ListTile(
                        leading: SizedBox(
                           width: 35,
                           child: Row(
                             mainAxisAlignment: MainAxisAlignment.end,
                             children: [
                               if (index < 3)
                                 Icon(Icons.emoji_events, color: index == 0 ? Colors.amber[600] : (index == 1 ? Colors.grey[400] : Colors.brown[400]), size: 18),
                               if (index >= 3)
                                 Text(
                                   '${index + 1}.',
                                   textAlign: TextAlign.right,
                                   style: TextStyle(
                                     fontSize: 15,
                                     fontWeight: nameWeight,
                                     color: nameColor.withOpacity(0.7),
                                   ),
                                 ),
                             ],
                           ),
                        ),
                        title: Text(
                          displayName,
                          style: TextStyle(
                            fontWeight: nameWeight,
                            color: nameColor,
                            fontSize: 16,
                          ),
                        ),
                        trailing: Text(
                          '$bestScore',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: scoreWeight,
                            color: scoreColor,
                            fontFamily: 'monospace',
                            letterSpacing: 1.1,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                        dense: true,
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

  // Widget do wyświetlania sekcji "Twój Najlepszy Wynik"
  Widget _buildPersonalBestSection(String userId, Color accentColor, Color tileColor) { // Przyjmuje accentColor
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _firestore.collection('gameScores').doc(userId).get()
          .then((doc) => doc),
      builder: (context, snapshot) {
        Widget content;
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Użycie przekazanego accentColor
          content = Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: accentColor)));
        } else if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          content = const Center(child: Text('Brak zapisanego rekordu.', style: TextStyle(color: Colors.grey)));
        } else {
          final scoreData = snapshot.data!.data() ?? <String, dynamic>{};
          final int bestScore = scoreData['bestScore'] as int? ?? 0;
          final Timestamp? lastPlayed = scoreData['lastScoreTimestamp'] as Timestamp?;

          content = Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TWÓJ REKORD',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withOpacity(0.8),
                        letterSpacing: 1.1,
                      ),
                    ),
                    if (lastPlayed != null)
                       Padding(
                         padding: const EdgeInsets.only(top: 4.0),
                         child: Text(
                           'Ostatnia gra: ${_formatTimestamp(lastPlayed)}',
                           style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                           overflow: TextOverflow.ellipsis,
                         ),
                       ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '$bestScore',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: accentColor, // Użycie przekazanego accentColor
                  fontFamily: 'monospace',
                  letterSpacing: 1.2,
                ),
              ),
            ],
          );
        }

        // Zwracamy kontener z zawartością
        return Container(
          color: tileColor,
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
          child: content,
        );
      },
    );
  }
}
