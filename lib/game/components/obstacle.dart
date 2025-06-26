// lib/game/components/obstacle.dart

import 'dart:math'; // Potrzebne dla Random i pi
// Dla Canvas

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/foundation.dart'; // Potrzebne dla kDebugMode
import 'package:flutter/animation.dart'; // Zawiera klasę Curves
// Dla paint

// Poprawny import względny do głównego pliku gry (jeden folder wyżej)
import '../motorboat_game.dart';

class Obstacle extends SpriteComponent with HasGameRef<MotorboatGame>, CollisionCallbacks {
  final int lane;
  static final _random = Random();
  late RectangleHitbox hitbox;
  String spriteName = '';

  // Zmienne dla ruchu poziomego (tylko dla kaczki)
  bool isMoving = false;
  double horizontalSpeed = 75.0; // Zwiększono lekko prędkość kaczki
  // Usunięto: double movementRange = 0.0;
  double direction = 1.0;
  // Usunięto: double initialX = 0.0; // Nie potrzebujemy już środka toru jako punktu odniesienia

  Obstacle({required this.lane, required super.position, required super.size})
      : super(anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Logika losowania sprite'a
    final List<String> obstacleSprites = [
      'obstacle_rock.png',
      'obstacle_boya1.png',
      'obstacle_kaczka.png'
    ];
    spriteName = obstacleSprites[_random.nextInt(obstacleSprites.length)];

    if (kDebugMode) {
      print('Losowanie przeszkody: wybrano "$spriteName"');
    }

    try {
      sprite = await gameRef.loadSprite(spriteName);
      hitbox = RectangleHitbox();
      add(hitbox);

      // Logika ruchu i animacji zależna od typu
      // Usunięto: initialX = position.x;

      // Ustaw ruch tylko dla kaczki
      if (spriteName == 'obstacle_kaczka.png') {
         isMoving = true;
         // Usunięto: movementRange = gameRef.laneWidth / 3;
         direction = _random.nextBool() ? 1.0 : -1.0; // Losowy kierunek startowy
         print("Obstacle at lane $lane is a MOVING DUCK.");
      }
      // Dodaj animację kołysania tylko dla boi
      else if (spriteName == 'obstacle_boya1.png') {
        isMoving = false;
        print("Obstacle at lane $lane is a BUOY.");
        add(
          RotateEffect.by(
            pi / 18,
            EffectController(
              duration: 1.5, alternate: true, infinite: true, curve: Curves.easeInOut,
            ),
          )
        );
         add(
           MoveEffect.by(
             Vector2(0, 5),
             EffectController(
               duration: 1.8, alternate: true, infinite: true, curve: Curves.easeInOutSine,
             ),
           )
         );
      }
      // Skała (rock) - nic nie rób
      else {
         isMoving = false;
         print("Obstacle at lane $lane is a ROCK.");
      }

    } catch (e) {
      if (kDebugMode) {
        print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
        print('BŁĄD: Nie można załadować sprite\'a przeszkody: $spriteName');
        print('Błąd szczegółowy: $e');
        print('Upewnij się, że plik istnieje w assets/images/ i jest poprawnie zadeklarowany w pubspec.yaml');
        print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
      }
      removeFromParent();
    }
  }

  @override
  void update(double dt) {
    if (!isMounted) return;
    super.update(dt); // Ważne, aby efekty działały

    // Ruch pionowy (zawsze)
    position.y += gameRef.scrollSpeed * dt;

    // --- VVV ZAKTUALIZOWANY RUCH POZIOMY (DLA KACZKI) VVV ---
    if (isMoving) {
       // Przesuń w poziomie
       position.x += horizontalSpeed * direction * dt;

       // Sprawdź granice ekranu, uwzględniając połowę szerokości kaczki
       final halfWidth = size.x / 2;
       final screenWidth = gameRef.size.x;

       // Sprawdź lewą krawędź
       if (position.x - halfWidth <= 0) {
          position.x = halfWidth; // Ustaw dokładnie na lewej krawędzi
          direction = 1.0; // Zmień kierunek na prawo
       }
       // Sprawdź prawą krawędź
       else if (position.x + halfWidth >= screenWidth) {
          position.x = screenWidth - halfWidth; // Ustaw dokładnie na prawej krawędzi
          direction = -1.0; // Zmień kierunek na lewo
       }
    }
    // --- ^^^ KONIEC ZAKTUALIZOWANEGO RUCHU POZIOMEGO ^^^ ---

    // Usuwanie przeszkody, gdy wyjdzie poza ekran
    if (position.y > gameRef.size.y + size.y / 2) {
      removeFromParent();
    }
  }
}