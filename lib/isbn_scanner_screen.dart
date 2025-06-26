// lib/screens/isbn_scanner_screen.dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class IsbnScannerScreen extends StatefulWidget {
  const IsbnScannerScreen({super.key});

  @override
  State<IsbnScannerScreen> createState() => _IsbnScannerScreenState();
}

class _IsbnScannerScreenState extends State<IsbnScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _handleDetection(BarcodeCapture capture) {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? scannedValue = barcodes.first.rawValue;

      if (scannedValue != null && scannedValue.isNotEmpty) {
        if (scannedValue.length == 10 || scannedValue.length == 13) {
          print("Zeskanowano potencjalny ISBN: $scannedValue");
          setState(() { _isProcessing = true; });
          if(mounted) {
             Navigator.pop(context, scannedValue);
          }
        } else {
           print("Zeskanowano kod, ale nie jest to ISBN (niepoprawna długość): $scannedValue");
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skanuj Kod ISBN'),
        actions: [
          // *** POPRAWKA: Uproszczony przycisk latarki bez dynamicznej ikony ***
          IconButton(
            icon: const Icon(Icons.flash_on), // Zawsze pokazuj ikonę włączonej latarki
            tooltip: 'Przełącz latarkę',
            onPressed: () => _scannerController.toggleTorch(),
          ),
          // *** POPRAWKA: Uproszczony przycisk kamery bez dynamicznej ikony ***
          IconButton(
            icon: const Icon(Icons.switch_camera), // Użyj standardowej ikony przełączania
            tooltip: 'Przełącz kamerę',
            onPressed: () => _scannerController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _handleDetection,
          ),
          // Nakładka wizualna (bez zmian)
          Center(
            child: Container(
              width: 250,
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red.withOpacity(0.7), width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          // Tekst informacyjny (bez zmian)
           Positioned(
             bottom: 30,
             left: 0,
             right: 0,
             child: Container(
               padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
               color: Colors.black.withOpacity(0.5),
               child: const Text(
                 'Umieść kod kreskowy książki w czerwonej ramce.',
                 style: TextStyle(color: Colors.white),
                 textAlign: TextAlign.center,
               ),
             ),
           ),
        ],
      ),
    );
  }
}
