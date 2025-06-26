// lib/game/motorboat_game.dart

import 'dart:math';
// Potrzebny dla Color, Canvas, ImageRepeat

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/palette.dart'; // Dla BasicPalette
import 'package:flutter/material.dart'; // Dla TextStyle, Widgets etc. i ValueNotifier
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Dla DateFormat

// Importy komponentów
import 'components/motorboat.dart';
import 'components/obstacle.dart';
import 'components/towable_tube.dart';

enum GameState { startMenu, playing, gameOver }

class MotorboatGame extends FlameGame with HasCollisionDetection, PanDetector, HasGameRef, TapCallbacks {
  late Motorboat motorboat;
  late TowableTube tube;
  double scrollSpeed = 200.0;
  final double maxScrollSpeed = 500.0; // Można też zwiększać maxSpeed z poziomem
  final double speedIncreaseFactor = 5.0;
  static const int laneCount = 3;
  late double laneWidth;
  final Random _random = Random();
  late TimerComponent obstacleSpawnerComponent;
  GameState state = GameState.startMenu;
  double score = 0.0;
  late TextComponent scoreText;
  // Usunięto gameOverText, bo używamy nakładki
  late SpriteComponent background1;
  late SpriteComponent background2;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  double _panStartX = 0;
  double _panLastX = 0;
  final double _minSwipeDistance = 50.0;
  final ValueNotifier<String> gameOverMessageNotifier = ValueNotifier('');
  SpriteComponent? gameLogo;
  TextComponent? startText;

  // --- VVV ZMIENNE DLA SYSTEMU POZIOMÓW VVV ---
  int level = 1; // Aktualny poziom
  static const int pointsPerLevel = 400; // Punktów na poziom
  final double baseSpawnDelay = 1.0; // Początkowe opóźnienie (poziom 1)
  final double minSpawnDelay = 0.3; // Minimalne możliwe opóźnienie
  // Jak bardzo skracać opóźnienie na każdy poziom (np. o 0.05 sekundy)
  final double spawnDelayDecreasePerLevel = 0.05;
  late TextComponent levelText; // Do wyświetlania poziomu (opcjonalne)
  // --- ^^^ KONIEC ZMIENNYCH DLA POZIOMÓW ^^^ ---


  @override
  Future<void> onLoad() async {
    await super.onLoad();
    laneWidth = size.x / laneCount;

    // Tło
    final waterSprite = await loadSprite('water_texture.png');
    background1 = SpriteComponent(sprite: waterSprite, size: Vector2(size.x, size.y), position: Vector2(0, 0));
    background2 = SpriteComponent(sprite: waterSprite, size: Vector2(size.x, size.y), position: Vector2(0, -size.y));
    add(background1..priority = -1);
    add(background2..priority = -1);

    // Timer przeszkód (tworzymy z bazowym opóźnieniem)
    obstacleSpawnerComponent = TimerComponent(period: baseSpawnDelay, repeat: true, onTick: _spawnObstacle);
    // Nie dodajemy go jeszcze do gry

    // UI Wyniku (tworzymy, ale dodamy później)
    scoreText = TextComponent(text: 'Score: 0', position: Vector2(10, 10), textRenderer: TextPaint(style: TextStyle(color: BasicPalette.white.color, fontSize: 24.0)));
    // Nie dodajemy go jeszcze do gry

    // --- VVV DODANO UI POZIOMU VVV ---
    levelText = TextComponent(
      text: 'Level: $level',
      position: Vector2(size.x - 10, 10), // Prawy górny róg
      anchor: Anchor.topRight, // Wyrównanie do prawej
      textRenderer: TextPaint(style: TextStyle(color: BasicPalette.white.color, fontSize: 20.0)),
    );
    // Nie dodajemy go jeszcze do gry
    // --- ^^^ KONIEC UI POZIOMU ^^^ ---

    // Pokaż menu startowe
    showStartMenu();
  }

  // Funkcja pokazująca menu startowe (bez zmian)
  void showStartMenu() async { /* ... bez zmian ... */
     final logoSprite = await loadSprite('game_logo.png');
     gameLogo = SpriteComponent(sprite: logoSprite, size: Vector2(size.x * 0.8, size.x * 0.8 * (logoSprite.srcSize.y / logoSprite.srcSize.x)), position: Vector2(size.x / 2, size.y * 0.35), anchor: Anchor.center, priority: 5 ); add(gameLogo!);
     startText = TextComponent(text: 'Dotknij, aby rozpocząć', position: Vector2(size.x / 2, size.y * 0.7), anchor: Anchor.center, textRenderer: TextPaint(style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 4, offset: Offset(1,1))])), priority: 5 );
     startText!.add( SequenceEffect([ ScaleEffect.to(Vector2.all(1.1), EffectController(duration: 0.7, alternate: true)), ScaleEffect.to(Vector2.all(1.0), EffectController(duration: 0.7, alternate: true)), ], infinite: true) ); add(startText!);
     state = GameState.startMenu;
  }

  // Funkcja rozpoczynająca grę
  void startGame() {
    print("Starting game...");
    // Usuń elementy menu
    if (gameLogo != null && gameLogo!.isMounted) remove(gameLogo!);
    if (startText != null && startText!.isMounted) remove(startText!);

    // Dodaj elementy gry, jeśli jeszcze nie istnieją
    if (!scoreText.isMounted) add(scoreText);
    if (!levelText.isMounted) add(levelText); // <<< DODANO levelText
    if (!obstacleSpawnerComponent.isMounted) add(obstacleSpawnerComponent);

    // Stwórz gracza
    final initialLane = (laneCount / 2).floor();
    final startX = calculateXForLane(initialLane);
    motorboat = Motorboat(currentLane: initialLane, position: Vector2(startX, size.y * 0.7), size: Vector2(50, 80));
    add(motorboat);
    tube = TowableTube(motorboat: motorboat, ropeLength: 100.0, size: Vector2(30, 30));
    add(tube);

    // Zresetuj i uruchom timer przeszkód z bazowym opóźnieniem
    obstacleSpawnerComponent.timer.limit = baseSpawnDelay; // Ustaw bazowe opóźnienie
    obstacleSpawnerComponent.timer.reset();
    obstacleSpawnerComponent.timer.start();

    // Zresetuj stan gry
    score = 0.0;
    level = 1; // Zresetuj poziom
    scrollSpeed = 200.0;
    scoreText.text = 'Score: 0';
    levelText.text = 'Level: $level'; // Zresetuj tekst poziomu
    state = GameState.playing;

    if (paused) resumeEngine();
  }


  @override
  void update(double dt) {
    if (state == GameState.playing) {
      super.update(dt);
      if (scrollSpeed < maxScrollSpeed) {
        scrollSpeed += speedIncreaseFactor * dt;
        scrollSpeed = min(scrollSpeed, maxScrollSpeed);
      }
      final double displacement = scrollSpeed * dt;
      background1.position.y += displacement;
      background2.position.y += displacement;
      if (background1.position.y >= size.y) {
        background1.position.y = background2.position.y - size.y;
      }
      if (background2.position.y >= size.y) {
        background2.position.y = background1.position.y - size.y;
      }

      // Aktualizacja wyniku
      score += dt * 10; // Można uzależnić punkty od prędkości/poziomu
      scoreText.text = 'Score: ${score.toInt()}';

      // --- VVV LOGIKA ZMIANY POZIOMU VVV ---
      int newLevel = (score / pointsPerLevel).floor() + 1;
      if (newLevel > level) {
         level = newLevel;
         levelText.text = 'Level: $level'; // Zaktualizuj tekst poziomu
         // Oblicz nowe opóźnienie spawnowania
         double newSpawnDelay = baseSpawnDelay - (level - 1) * spawnDelayDecreasePerLevel;
         // Ogranicz do minimalnego opóźnienia
         newSpawnDelay = max(minSpawnDelay, newSpawnDelay);
         // Ustaw nowy limit (okres) timera
         obstacleSpawnerComponent.timer.limit = newSpawnDelay;
         print("Level Up! Level: $level, New Spawn Delay: $newSpawnDelay");
         // Można dodać efekt wizualny/dźwiękowy dla level up
      }
      // --- ^^^ KONIEC LOGIKI ZMIANY POZIOMU ^^^ ---

    } else {
       super.update(dt); // Aktualizuj efekty np. w menu
    }
  }

  @override
  void onTapUp(TapUpEvent event) {
    super.onTapUp(event);
    if (state == GameState.startMenu) {
       startGame();
    }
  }

  double calculateXForLane(int lane) { return (lane + 0.5) * laneWidth; }

  void _spawnObstacle() {
    if (state != GameState.playing) return;
    final lane = _random.nextInt(laneCount);
    final positionX = calculateXForLane(lane);
    final obstacleSize = Vector2(laneWidth * 0.6, 60);
    final obstacle = Obstacle(lane: lane, position: Vector2(positionX, -obstacleSize.y), size: obstacleSize);
    add(obstacle);
  }

  @override void onPanStart(DragStartInfo info) { if (state != GameState.playing) return; _panStartX = info.eventPosition.global.x; _panLastX = _panStartX; }
  @override void onPanUpdate(DragUpdateInfo info) { if (state != GameState.playing) return; _panLastX = info.eventPosition.global.x; }
  @override void onPanEnd(DragEndInfo info) { if (state != GameState.playing) return; final double distance = _panLastX - _panStartX; if (distance.abs() > _minSwipeDistance) { if (distance > 0) {
    motorboat.changeLane(1);
  } else {
    motorboat.changeLane(-1);
  } } _panStartX = 0; _panLastX = 0; }

  void gameOver() async {
    if (state == GameState.playing) {
      state = GameState.gameOver;
      pauseEngine();
      obstacleSpawnerComponent.timer.pause();
      final int finalScore = score.toInt();
      await _saveScoreAndAttempts(finalScore);
      overlays.add('gameOver');
      gameOverMessageNotifier.value = '';
    }
  }

  Future<void> _saveScoreAndAttempts(int finalScore) async {
      // ... (logika zapisu wyniku bez zmian) ...
      final User? currentUser = _auth.currentUser; if (currentUser != null) { final String userId = currentUser.uid; final String displayName = currentUser.displayName ?? currentUser.email ?? 'Anonim'; final DocumentReference scoreDocRef = _firestore.collection('gameScores').doc(userId); final String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now()); try { await _firestore.runTransaction((transaction) async { final DocumentSnapshot snapshot = await transaction.get(scoreDocRef); int currentBestScore = 0; int attemptsToday = 0; String lastDate = ''; if (snapshot.exists && snapshot.data() != null) { final data = snapshot.data() as Map<String, dynamic>; currentBestScore = data['bestScore'] as int? ?? 0; attemptsToday = data['dailyAttempts'] as int? ?? 0; lastDate = data['lastAttemptDate'] as String? ?? ''; } if (lastDate != todayDate) { attemptsToday = 0; } attemptsToday++; Map<String, dynamic> dataToUpdate = { 'userId': userId, 'displayName': displayName, 'lastScoreTimestamp': FieldValue.serverTimestamp(), 'dailyAttempts': attemptsToday, 'lastAttemptDate': todayDate, }; if (finalScore > currentBestScore) { dataToUpdate['bestScore'] = finalScore; } else if (!snapshot.exists || !(snapshot.data() as Map<String, dynamic>).containsKey('bestScore')) { dataToUpdate['bestScore'] = currentBestScore; } transaction.set(scoreDocRef, dataToUpdate, SetOptions(merge: true)); print("Score and attempts updated for $userId. Attempts today: $attemptsToday"); }); } catch (e) { print("Error saving/updating score/attempts for user $userId: $e"); } } else { print("User not logged in. Score and attempts not saved."); }
  }

  Future<void> checkAndRestartGameFromOverlay() async {
    // ... (logika sprawdzania limitu bez zmian) ...
    final User? currentUser = _auth.currentUser; if (currentUser == null) { restartGame(); return; } final String userId = currentUser.uid; final DocumentReference scoreDocRef = _firestore.collection('gameScores').doc(userId); final String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now()); try { final DocumentSnapshot snapshot = await scoreDocRef.get(); bool canPlay = true; int attemptsToday = 0; if (snapshot.exists && snapshot.data() != null) { final data = snapshot.data() as Map<String, dynamic>; final String lastAttemptDate = data['lastAttemptDate'] as String? ?? ''; attemptsToday = data['dailyAttempts'] as int? ?? 0; if (lastAttemptDate == todayDate && attemptsToday >= 3) { canPlay = false; } } if (canPlay) { restartGame(); } else { gameOverMessageNotifier.value = 'Limit prób na dziś!\nPoczytaj Biblię ;)'; } } catch (e) { print("Błąd sprawdzania limitu prób przed restartem: $e"); restartGame(); }
  }

  // Funkcja restartująca grę (wraca do menu startowego)
  void restartGame() {
    print("Restarting game (returning to start menu)...");
    overlays.remove('gameOver');
    print("Game Over overlay removed.");

    // Usuwanie komponentów gry
    children.whereType<Obstacle>().toList().forEach(remove);
    if (motorboat.isMounted) remove(motorboat);
    if (tube.isMounted) remove(tube);
    if (scoreText.isMounted) remove(scoreText);
    if (levelText.isMounted) remove(levelText); // <<< DODANO USUNIĘCIE levelText
    if (obstacleSpawnerComponent.isMounted) remove(obstacleSpawnerComponent);

    // Pokaż menu startowe (zresetuje stan i doda potrzebne komponenty)
    showStartMenu();

    // Resetowanie pozycji tła
    background1.position = Vector2(0, 0);
    background2.position = Vector2(0, -size.y);

    // Upewnij się, że silnik jest wznowiony
    if (paused) {
       resumeEngine();
       print("Engine resumed for start menu.");
    }

    print("Game reset to start menu.");
  }
}