// lib/game/components/towable_tube.dart

import 'dart:ui'; // Dla lerpDouble, Canvas, Offset

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/palette.dart'; // Potrzebne dla linePaint
import 'package:flutter/painting.dart'; // Dla paint

// Poprawne importy względne
import '../motorboat_game.dart';
import 'motorboat.dart';
import 'obstacle.dart';
// Usunięto import miny: import 'mine_obstacle.dart';

class TowableTube extends SpriteComponent with HasGameRef<MotorboatGame>, CollisionCallbacks {
  final Motorboat motorboat;
  final double ropeLength;

  late CircleHitbox hitbox;

  // --- VVV ZMIENNE DLA BEZWŁADNOŚCI VVV ---
  Vector2 velocity = Vector2.zero(); // Aktualna prędkość kółka
  // Współczynnik tłumienia/interpolacji (mniejsza wartość = większa bezwładność)
  // --- VVV ZMIANA TUTAJ: Zwiększono dampingFactor VVV ---
  final double dampingFactor = 0.08; // Zwiększono z 0.08 na 0.16 (mniejsza bezwładność)
  // --- ^^^ KONIEC ZMIANY ^^^ ---
  // Maksymalna prędkość (zapobiega "wystrzeleniu" kółka)
  final double maxSpeed = 800.0;
  // --- ^^^ KONIEC ZMIENNYCH DLA BEZWŁADNOŚCI ^^^ ---


  TowableTube({required this.motorboat, required this.ropeLength, required super.size})
      : super(anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sprite = await gameRef.loadSprite('tube.png');
    hitbox = CircleHitbox();
    add(hitbox);
    // Ustaw pozycję początkową od razu za motorówką
    position = Vector2(motorboat.position.x, motorboat.position.y + ropeLength);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas); // Rysuje sprite'a
    // Rysuj linię (linę)
    final linePaint = BasicPalette.white.paint()..strokeWidth = 2;
    final Offset motorboatCenterOffset = Offset(motorboat.absoluteCenter.x, motorboat.absoluteCenter.y);
    final Offset tubeCenterOffset = Offset(absoluteCenter.x, absoluteCenter.y);
    canvas.drawLine(motorboatCenterOffset, tubeCenterOffset, linePaint);
  }


  @override
  void update(double dt) {
    // Aktualizuj tylko jeśli gra jest w toku
    if (gameRef.state != GameState.playing) {
       if (gameRef.state == GameState.gameOver) velocity = Vector2.zero();
       return;
    }

    super.update(dt);

    // --- VVV NOWA LOGIKA RUCHU Z BEZWŁADNOŚCIĄ VVV ---
    // 1. Oblicz idealną pozycję docelową (dokładnie za motorówką)
    final Vector2 targetPosition = Vector2(motorboat.position.x, motorboat.position.y + ropeLength);

    // 2. Oblicz wektor kierunku do pozycji docelowej
    final Vector2 direction = targetPosition - position;
    // final double distance = direction.length; // Dystans może być użyty do bardziej złożonej fizyki

    // 3. Oblicz "docelową" prędkość - proporcjonalną do wektora kierunku
    // Mnożnik (np. 3.0) wpływa na to, jak szybko kółko "chce" dogonić motorówkę
    Vector2 targetVelocity = direction * 3.0;

    // Ogranicz maksymalną prędkość docelową
    if (targetVelocity.length > maxSpeed) {
       targetVelocity = targetVelocity.normalized() * maxSpeed;
    }

    // 4. Płynnie interpoluj aktualną prędkość w kierunku prędkości docelowej
    // Używamy lerp na prędkości, co daje efekt tłumienia/opóźnienia
    velocity.lerp(targetVelocity, dampingFactor); // Używamy zmienionego dampingFactor

    // 5. Zaktualizuj pozycję na podstawie aktualnej (interpolowanej) prędkości
    position += velocity * dt;

    // --- ^^^ KONIEC NOWEJ LOGIKI RUCHU ^^^ ---

    // Sprawdzenie NaN
    if (position.x.isNaN || position.y.isNaN) {
      position = Vector2(motorboat.position.x, motorboat.position.y + ropeLength);
      velocity = Vector2.zero();
    }
  }

  // Reakcja na kolizję (tylko ze zwykłymi przeszkodami)
  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Obstacle) {
      print("Tube collided with Obstacle");
      gameRef.gameOver();
    }
    // Usunięto logikę dla min
  }
}
