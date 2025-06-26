import 'package:flutter/material.dart';
import 'package:gradient_borders/box_borders/gradient_box_border.dart'; // Importuj pakiet

class GlowingCardWrapper extends StatefulWidget {
  final Widget child; // Widget, który ma być otoczony poświatą (np. Card)
  final BorderRadius borderRadius; // Zaokrąglenie rogów, aby pasowało do dziecka
  final Duration animationDuration; // Czas trwania jednego cyklu animacji
  final Color baseColor; // Główny kolor poświaty
  final Color glowColor; // Kolor "rozbłysku" poświaty

  const GlowingCardWrapper({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(12.0)), // Domyślne zaokrąglenie
    this.animationDuration = const Duration(milliseconds: 1500), // Domyślny czas animacji
    this.baseColor = const Color.fromARGB(255, 109, 196, 223), // Domyślny niebieski (pasujący do seedColor)
    this.glowColor = const Color.fromARGB(255, 180, 230, 250), // Jaśniejszy niebieski dla rozbłysku
  });

  @override
  State<GlowingCardWrapper> createState() => _GlowingCardWrapperState();
}

class _GlowingCardWrapperState extends State<GlowingCardWrapper>
    with SingleTickerProviderStateMixin { // Potrzebne dla AnimationController
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    )..repeat(reverse: true); // Powtarzaj animację w przód i w tył (pulsowanie)

    // Używamy CurvedAnimation dla płynniejszego przejścia (ease-in-out)
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose(); // Pamiętaj o zwolnieniu kontrolera
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        // Interpolujemy kolor gradientu na podstawie animacji
        final animatedColor = Color.lerp(
          // Można lekko zmniejszyć opacity bazowego koloru dla kontrastu
          widget.baseColor.withOpacity(0.5), // Było 0.6
          // Zwiększamy opacity koloru poświaty dla intensywności
          widget.glowColor.withOpacity(1.0), // Było 0.9
          _animation.value, // Aktualna wartość animacji (0.0 do 1.0)
        );

        // Upewnijmy się, że kolor nie jest nullem, użyj glowColor jako fallback
        final currentGlowColor = animatedColor ?? widget.glowColor.withOpacity(1.0);

        return Container(
          decoration: BoxDecoration(
            // Używamy GradientBoxBorder do stworzenia obramowania
            border: GradientBoxBorder(
              gradient: SweepGradient( // Możesz eksperymentować z innymi gradientami
                center: Alignment.center,
                colors: [
                  currentGlowColor, // Użyj intensywniejszego koloru animowanego
                  // Zmniejsz opacity bazowego koloru w gradiencie
                  widget.baseColor.withOpacity(0.05), // Było 0.1
                  currentGlowColor, // Powtórzenie dla płynnego przejścia
                ],
                 stops: const [0.0, 0.5, 1.0], // Punkty zatrzymania gradientu
              ),
              // --- ZMIANA: Cieńsza ramka ---
              width: 1, // Było 2.5 (możesz dostosować do 1.0, 1.5 lub 2.0)
            ),
            borderRadius: widget.borderRadius, // Dopasuj zaokrąglenie do dziecka
             // --- ZMIANA: Intensywniejszy cień (glow) ---
             boxShadow: [
               BoxShadow(
                 // Użyj jaśniejszego, animowanego koloru dla cienia
                 color: currentGlowColor.withOpacity(0.7 * _animation.value), // Zwiększono opacity (było 0.3)
                 // Zwiększ rozmycie dla bardziej miękkiego efektu "glow"
                 blurRadius: 6.0, // Było 4.0
                 // Można lekko zwiększyć rozprzestrzenienie
                 spreadRadius: 1.0, // Było 0.5
               ),
             ],
          ),
          // Ważne: Użyj ClipRRect, aby dziecko (Card) nie "wystawało" poza zaokrąglone rogi obramowania
          child: ClipRRect(
             borderRadius: widget.borderRadius,
             child: widget.child, // Umieść oryginalne dziecko (Card) wewnątrz
          ),
        );
      },
      child: widget.child, // Przekaż dziecko do AnimatedBuilder (optymalizacja)
    );
  }
}