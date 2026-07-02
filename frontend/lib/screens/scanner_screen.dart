import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api_service.dart';
import '../main.dart' show AppColors;

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with TickerProviderStateMixin {
  final MobileScannerController _scannerCtrl = MobileScannerController();
  bool _isProcessing = false;
  Map<String, dynamic>? _result;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scannerCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    setState(() => _isProcessing = true);
    await _scannerCtrl.stop();

    final qrToken = barcode!.rawValue!;

    try {
      final response = await ApiService.validateQR(qrToken);
      if (mounted) {
        setState(() => _result = response);
        _showResultDialog(response);
      }
    } catch (e) {
      if (mounted) {
        _showResultDialog({
          'valid': false,
          'message': 'Error de conexión. Verifica el servidor.',
        });
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showResultDialog(Map<String, dynamic> result) {
    final isValid = result['valid'] == true;
    final ticket  = result['ticket'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isValid ? AppColors.success : AppColors.error,
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ícono resultado
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isValid ? AppColors.success : AppColors.error)
                      .withOpacity(0.15),
                ),
                child: Icon(
                  isValid
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  size: 48,
                  color: isValid ? AppColors.success : AppColors.error,
                ),
              ),
              const SizedBox(height: 16),

              Text(
                isValid ? '✅ TICKET VÁLIDO' : '❌ TICKET INVÁLIDO',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isValid ? AppColors.success : AppColors.error,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                result['message'] ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),

              // Detalles del ticket
              if (ticket != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _detailRow(Icons.event_rounded,
                          ticket['event']?['title'] ?? 'Evento'),
                      _detailRow(Icons.person_rounded,
                          ticket['user']?['name'] ?? 'Usuario'),
                      _detailRow(Icons.local_activity_rounded,
                          ticket['ticket_type']?['name'] ?? 'Tipo'),
                      _detailRow(Icons.confirmation_number_rounded,
                          ticket['ticket_code'] ?? ''),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() => _result = null);
                    _scannerCtrl.start();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isValid ? AppColors.success : AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_scanner_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Escanear otro QR',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Escanear QR',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_rounded, color: Colors.white),
            onPressed: () => _scannerCtrl.toggleTorch(),
            tooltip: 'Linterna',
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_android_rounded, color: Colors.white),
            onPressed: () => _scannerCtrl.switchCamera(),
            tooltip: 'Cambiar cámara',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Cámara
          MobileScanner(
            controller: _scannerCtrl,
            onDetect: _onDetect,
          ),

          // Overlay con recuadro de escaneo
          CustomPaint(
            size: Size.infinite,
            painter: _ScannerOverlayPainter(),
          ),

          // Indicador de procesando
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 16),
                    Text('Validando QR...',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),

          // Texto guía
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                ScaleTransition(
                  scale: _pulseAnim,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code_scanner_rounded,
                            color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('Apunta al código QR del ticket',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Pintor del recuadro de escaneo
class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black54;
    final scanSize = size.width * 0.65;
    final left   = (size.width - scanSize) / 2;
    final top    = (size.height - scanSize) / 2 - 40;
    final right  = left + scanSize;
    final bottom = top + scanSize;
    final rect   = Rect.fromLTRB(left, top, right, bottom);
    final rrect  = RRect.fromRectAndRadius(rect, const Radius.circular(16));

    // Oscurecer fuera del recuadro
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(rrect),
      ),
      paint,
    );

    // Borde del recuadro
    final borderPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(rrect, borderPaint);

    // Esquinas decorativas
    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const cLen = 24.0;

    // Esquina TL
    canvas.drawLine(Offset(left, top + cLen), Offset(left, top), cornerPaint);
    canvas.drawLine(Offset(left, top), Offset(left + cLen, top), cornerPaint);
    // Esquina TR
    canvas.drawLine(Offset(right - cLen, top), Offset(right, top), cornerPaint);
    canvas.drawLine(Offset(right, top), Offset(right, top + cLen), cornerPaint);
    // Esquina BL
    canvas.drawLine(Offset(left, bottom - cLen), Offset(left, bottom), cornerPaint);
    canvas.drawLine(Offset(left, bottom), Offset(left + cLen, bottom), cornerPaint);
    // Esquina BR
    canvas.drawLine(Offset(right - cLen, bottom), Offset(right, bottom), cornerPaint);
    canvas.drawLine(Offset(right, bottom), Offset(right, bottom - cLen), cornerPaint);
  }

  @override
  bool shouldRepaint(_) => false;
}
