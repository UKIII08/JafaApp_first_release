// lib/screens/jafa_games_screen.dart

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
// Upewnij się, że ta ścieżka jest poprawna do Twojej klasy MotorboatGame
import '../game/motorboat_game.dart';
// Import ekranu rankingu z folderu lib/game/
import '../game/leaderboard_screen.dart';


class JafaGamesScreen extends StatefulWidget {
  const JafaGamesScreen({super.key});

  @override
  State<JafaGamesScreen> createState() => _JafaGamesScreenState();
}

class _JafaGamesScreenState extends State<JafaGamesScreen> {
  // Przechowujemy instancję gry, aby nie tworzyć jej za każdym razem
  late final MotorboatGame _gameInstance;

  @override
  void initState() {
    super.initState();
    _gameInstance = MotorboatGame();
  }

  @override
  Widget build(BuildContext context) {
    // Definicje kolorów dla stylu "gamerskiego"
    const Color accentColorBlue = Color(0xFF00B0FF);
    final Color darkBackgroundColor = Colors.grey[900]!;
    final Color appBarColor = Colors.grey[850]!;

    return Scaffold(
      backgroundColor: darkBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'JAFA GAMES',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: accentColorBlue
          ),
        ),
        backgroundColor: appBarColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard_outlined),
            tooltip: 'Pokaż Ranking',
            color: Colors.white,
            onPressed: () {
              // Pauzuj grę przed otwarciem rankingu
              _gameInstance.pauseEngine();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LeaderboardScreen()),
              ).then((_) {
                 // Wznów grę po powrocie z rankingu, jeśli nadal trwa
                 if (_gameInstance.state == GameState.playing && mounted) {
                    _gameInstance.resumeEngine();
                 }
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: GameWidget<MotorboatGame>( // Określ typ gry dla `game`
        game: _gameInstance,
        // Definiujemy, jak budować nakładki
        overlayBuilderMap: {
          // Klucz nakładki 'gameOver'
          'gameOver': (BuildContext context, MotorboatGame game) {
            // Zwracamy widget Fluttera dla ekranu Game Over
            return GameOverOverlay(game: game);
          },
        },
        loadingBuilder: (context) => const Center(
          child: CircularProgressIndicator(color: accentColorBlue),
        ),
      ),
    );
  }
}


// Widget Nakładki Game Over
class GameOverOverlay extends StatelessWidget {
  final MotorboatGame game; // Referencja do gry

  const GameOverOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: Colors.grey[850],
            borderRadius: BorderRadius.circular(15.0),
            border: Border.all(color: const Color(0xFF00B0FF).withOpacity(0.5), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 10,
                spreadRadius: 2,
              )
            ]
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'GAME OVER',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[400],
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Wynik: ${game.score.toInt()}',
                style: const TextStyle(
                  fontSize: 24,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Spróbuj Ponownie'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B0FF),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  game.checkAndRestartGameFromOverlay();
                },
              ),
              const SizedBox(height: 12),
               // Komunikat o limicie (nasłuchuje na notifier)
               ValueListenableBuilder<String>(
                 valueListenable: game.gameOverMessageNotifier, // Użycie publicznego notifiera
                 builder: (context, message, child) {
                   if (message.isNotEmpty) {
                     return Padding(
                       padding: const EdgeInsets.only(top: 12.0),
                       child: Text(
                         message,
                         textAlign: TextAlign.center,
                         style: TextStyle(color: Colors.orange[300], fontSize: 14),
                       ),
                     );
                   } else {
                     return const SizedBox.shrink();
                   }
                 }
               ),
            ],
          ),
        ),
      ),
    );
  }
}
