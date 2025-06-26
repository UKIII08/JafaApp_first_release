// lib/game/components/motorboat.dart

import 'dart:math'; // Dla max, min
// Dla Canvas

import 'package:flame/collisions.dart'; // <<< DODANO DLA HITBOX I KOLIZJI
import 'package:flame/components.dart';
// Dla paint (może nie być już potrzebny)

// Poprawny import względny do głównego pliku gry (jeden folder wyżej)
import '../motorboat_game.dart';
// <<< DODANO IMPORT PRZESZKODY >>>
import 'obstacle.dart';
// Usunięto import miny: import 'mine_obstacle.dart';

// Zmieniono: Dodano CollisionCallbacks
class Motorboat extends SpriteComponent with HasGameRef<MotorboatGame>, CollisionCallbacks {
  int currentLane;
  final int _laneCount = MotorboatGame.laneCount;

  // Efekt płynnego przejścia między torami
  double _targetX = 0;
  final double _moveSpeed = 800.0; // Jak szybko zmienia tory

  Motorboat({required this.currentLane, required super.position, required super.size})
      : super(anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
     await super.onLoad();
     sprite = await gameRef.loadSprite('motorboat.png');
     _targetX = position.x;

     // <<< DODANO HITBOX DO MOTORÓWKI >>>
     add(RectangleHitbox());
     // <<< KONIEC DODAWANIA HITBOXU >>>
  }

  @override
  void update(double dt) {
    // Aktualizuj tylko jeśli gra jest w toku
    if (gameRef.state != GameState.playing) return;

    super.update(dt);

    // Płynne przesuwanie do docelowego X
    if ((position.x - _targetX).abs() > 1.0) {
      final double direction = (_targetX - position.x).sign;
      position.x += direction * _moveSpeed * dt;
      if ((direction > 0 && position.x > _targetX) || (direction < 0 && position.x < _targetX)) {
        position.x = _targetX;
      }
    }
  }

  // Funkcja do zmiany toru
  void changeLane(int direction) {
    if (gameRef.state != GameState.playing) return; // Zmieniaj tor tylko podczas gry
    int nextLane = currentLane + direction;
    nextLane = max(0, min(_laneCount - 1, nextLane));
    if (nextLane != currentLane) {
      currentLane = nextLane;
      _targetX = gameRef.calculateXForLane(currentLane);
    }
  }

   // Funkcja do resetowania toru
  void resetLane(int lane) {
     currentLane = lane;
     // Sprawdź, czy gameRef jest już dostępne (bezpieczniej robić to, gdy gra jest załadowana)
     if (gameRef.isLoaded) {
       _targetX = gameRef.calculateXForLane(lane);
     } else {
       // Jeśli nie, ustaw tymczasowo na podstawie pozycji (zostanie poprawione w onLoad/pierwszym update)
       _targetX = position.x;
     }
     position.x = _targetX;
  }

  // --- VVV DODANO OBSŁUGĘ KOLIZJI MOTORÓWKI (TYLKO ZWYKŁE PRZESZKODY) VVV ---
  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);

    // Zakończ grę, jeśli motorówka zderzy się ze zwykłą przeszkodą
    if (other is Obstacle) {
       print("Motorboat collided with Obstacle");
       gameRef.gameOver(); // Wywołaj Game Over z głównej klasy gry
    }
    // Usunięto logikę dla min
  }
  // --- ^^^ KONIEC OBSŁUGI KOLIZJI MOTORÓWKI ^^^ ---
}