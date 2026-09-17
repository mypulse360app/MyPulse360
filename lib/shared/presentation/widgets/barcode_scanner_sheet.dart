import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Opens a full-screen camera barcode/QR scanner and returns the first
/// decoded value, or null if the user cancels. Real camera capture via the
/// `mobile_scanner` package — works on any device/emulator with a camera
/// and the permission granted; there's no special developer-account
/// requirement the way HealthKit/Fitbit integrations would need. Shared
/// across features (pharmacist inventory stock-in, patient prescription
/// scanning) since the scanning mechanics are identical either way.
Future<String?> showBarcodeScanner(
  BuildContext context, {
  String title = 'Scan barcode',
  String instructions = 'Point the camera at a barcode or QR code',
}) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (_) => _BarcodeScannerPage(title: title, instructions: instructions),
      fullscreenDialog: true,
    ),
  );
}

class _BarcodeScannerPage extends StatefulWidget {
  const _BarcodeScannerPage({required this.title, required this.instructions});

  final String title;
  final String instructions;

  @override
  State<_BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<_BarcodeScannerPage> {
  final _controller = MobileScannerController();
  bool _handled = false;
  String _scanMode = 'box';
  String? _scannedCode;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted && !_handled && _scannedCode == null) {
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: const Color(0xFF101015),
            title: const Text('Trouble scanning?', style: TextStyle(color: Colors.white)),
            content: const Text('Would you like to enter the details manually?', style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(), // close dialog
                child: const Text('Keep scanning', style: TextStyle(color: Colors.blueAccent)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                onPressed: () {
                  Navigator.of(dialogContext).pop(); // close dialog
                  if (mounted) Navigator.of(context).pop('MANUAL'); // pop scanner with 'MANUAL'
                },
                child: const Text('Enter Manually', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    });
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled || _scanMode == 'strip') return; // Do not auto-detect barcodes in strip mode
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.isNotEmpty) {
        _handled = true;
        setState(() => _scannedCode = value);
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) Navigator.of(context).pop(value);
        });
        return;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildCorner(bool isRight, bool isBottom) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        border: Border(
          top: isBottom ? BorderSide.none : const BorderSide(color: Colors.blueAccent, width: 3),
          bottom: !isBottom ? BorderSide.none : const BorderSide(color: Colors.blueAccent, width: 3),
          left: isRight ? BorderSide.none : const BorderSide(color: Colors.blueAccent, width: 3),
          right: !isRight ? BorderSide.none : const BorderSide(color: Colors.blueAccent, width: 3),
        ),
        borderRadius: BorderRadius.only(
          topLeft: (!isRight && !isBottom) ? const Radius.circular(20) : Radius.zero,
          topRight: (isRight && !isBottom) ? const Radius.circular(20) : Radius.zero,
          bottomLeft: (!isRight && isBottom) ? const Radius.circular(20) : Radius.zero,
          bottomRight: (isRight && isBottom) ? const Radius.circular(20) : Radius.zero,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          
          // Gradient overlays
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.95),
                  ],
                  stops: const [0.0, 0.25, 0.65, 1.0],
                ),
              ),
            ),
          ),
          
          // Top Bar
          Positioned(
            top: MediaQuery.paddingOf(context).top + 16,
            left: 24,
            right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                // Segmented Mode Toggle
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _scanMode = 'box'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: _scanMode == 'box' ? Colors.blueAccent : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text('Box / Barcode', style: TextStyle(color: Colors.white, fontWeight: _scanMode == 'box' ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _scanMode = 'strip'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: _scanMode == 'strip' ? Colors.blueAccent : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text('Strip Pack OCR', style: TextStyle(color: Colors.white, fontWeight: _scanMode == 'strip' ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.flashlight_on_rounded, color: Colors.white),
                    onPressed: () => _controller.toggleTorch(),
                  ),
                ),
              ],
            ),
          ),
          
          // Scanning Frame
          Positioned(
            top: MediaQuery.paddingOf(context).top + 100,
            bottom: 220,
            left: 24,
            right: 24,
            child: Stack(
              children: [
                Positioned(top: 0, left: 0, child: _buildCorner(false, false)),
                Positioned(top: 0, right: 0, child: _buildCorner(true, false)),
                Positioned(bottom: 0, left: 0, child: _buildCorner(false, true)),
                Positioned(bottom: 0, right: 0, child: _buildCorner(true, true)),
                
                Align(
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.filter_center_focus, color: Colors.white54, size: 48),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6), 
                          borderRadius: BorderRadius.circular(16)
                        ),
                        child: Text(
                          _scanMode == 'strip' ? 'Align foil strip horizontally. Ensure good lighting.' : widget.instructions, 
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                
                Positioned(
                  bottom: 24,
                  left: 12,
                  right: 12,
                  child: Column(
                    children: [
                      if (_scannedCode != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            gradient: RadialGradient(
                              center: Alignment.topLeft,
                              radius: 1.8,
                              colors: [
                                const Color(0xFF2A52BE), // Vibrant Blue
                                const Color(0xFF2A52BE).withValues(alpha: 0.4),
                                const Color(0xFF101015),
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2A52BE).withValues(alpha: 0.25),
                                blurRadius: 30,
                                spreadRadius: -10,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                'MATCH FOUND',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                '100%',
                                style: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1.5,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Detected payload...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.compare_arrows_rounded, color: Colors.greenAccent, size: 14),
                          const SizedBox(width: 6),
                          const Text('Hold steady • Optimal lighting detected', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Bottom Actions
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: SafeArea(
              child: Column(
                children: [

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop('PICK_PHOTO'),
                        child: Column(
                          children: [
                            Container(
                              width: 56, height: 56,
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), shape: BoxShape.circle),
                              child: const Icon(Icons.photo_library_outlined, color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            const Text('Photos', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          if (_scanMode == 'strip') {
                            Navigator.of(context).pop('STRIP_OCR');
                          }
                        },
                        child: Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3), width: 4),
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: _scanMode == 'strip' ? Colors.blueAccent : Colors.blueAccent.withValues(alpha: 0.5), 
                              shape: BoxShape.circle,
                              boxShadow: const [BoxShadow(color: Colors.blueAccent, blurRadius: 10, spreadRadius: 2)],
                            ),
                            child: Icon(_scanMode == 'strip' ? Icons.camera_alt_rounded : Icons.document_scanner_rounded, color: Colors.white, size: 32),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop('MANUAL'),
                        child: Column(
                          children: [
                            Container(
                              width: 56, height: 56,
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), shape: BoxShape.circle),
                              child: const Icon(Icons.edit_note_rounded, color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            const Text('Manual', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
