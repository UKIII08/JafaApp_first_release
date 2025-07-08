// lib/screens/jafa_games_screen.dart

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
// Upewnij się, że ta ścieżka jest poprawna do Twojej klasy MotorboatGame
import '../game/motorboat_game.dart';
// Import ekranu rankingu z folderu lib/game/
import '../game/leaderboard_screen.dart';
import 'package:audioplayers/audioplayers.dart';


class JafaGamesScreen extends StatefulWidget {
  const JafaGamesScreen({super.key});

  @override
  State<JafaGamesScreen> createState() => _JafaGamesScreenState();
}

class _JafaGamesScreenState extends State<JafaGamesScreen> {
  // Przechowujemy instancję gry, aby nie tworzyć jej za każdym razem
  late final MotorboatGame _gameInstance;

  // <<< POCZĄTEK KODU DLA MUZYKI >>>

  // 1. Stwórz instancję odtwarzacza audio
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _gameInstance = MotorboatGame();
    // 2. Uruchom muzykę, gdy ekran jest inicjowany
    _playBackgroundMusic();
  }

  Future<void> _playBackgroundMusic() async {
    try {
      // Ustaw pętlę, aby muzyka grała w kółko
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      // Odtwórz muzykę z folderu assets.
      // Używamy teraz ścieżki do Twojego pliku.
      await _audioPlayer.play(AssetSource('audio/spaceship-arcade-shooter-game-background-soundtrack-318508.mp3'));
    } catch (e) {
      // Obsłuż błąd, jeśli plik audio nie zostanie znaleziony lub wystąpi inny problem
      print("Nie udało się odtworzyć muzyki: $e");
    }
  }

  @override
  void dispose() {
    // 3. Zatrzymaj i zwolnij zasoby, gdy ekran jest zamykany
    // To BARDZO WAŻNE, aby uniknąć wycieków pamięci i odtwarzania muzyki po wyjściu z gry.
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  // <<< KONIEC KODU DLA MUZYKI >>>

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
              // Pauzuj grę i muzykę przed otwarciem rankingu
              _gameInstance.pauseEngine();
              _audioPlayer.pause(); 
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LeaderboardScreen()),
              ).then((_) {
                  // Wznów grę i muzykę po powrocie z rankingu
                  if (_gameInstance.state == GameState.playing && mounted) {
                    _gameInstance.resumeEngine();
                    _audioPlayer.resume();
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
            // Zatrzymaj muzykę w tle na ekranie Game Over
            _audioPlayer.pause();
            // Zwracamy widget Fluttera dla ekranu Game Over
            return GameOverOverlay(game: game, onRestart: () {
              // Po restarcie, wznów muzykę
              _audioPlayer.resume();
            });
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
  final VoidCallback onRestart; // Callback do wznowienia muzyki

  const GameOverOverlay({super.key, required this.game, required this.onRestart});

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
                  // Najpierw wywołaj restart gry
                  game.checkAndRestartGameFromOverlay();
                  // A potem callback, aby wznowić muzykę
                  onRestart();
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