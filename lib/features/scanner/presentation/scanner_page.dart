import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({required this.onScanned, super.key});

  final Future<void> Function(String value) onScanned;

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handledScan = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handledScan) return;
    final value = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (value == null || value.isEmpty) return;
    _handledScan = true;
    await _controller.stop();
    if (mounted) setState(() {});
    await widget.onScanned(value);
  }

  Future<void> _scanAgain() async {
    setState(() => _handledScan = false);
    await _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    final cameraUnavailable =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux);
    return Column(
      children: [
        const _ScannerHeader(),
        Expanded(
          child: cameraUnavailable
              ? const _UnsupportedCamera()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Column(
                        children: [
                          const SizedBox(height: 18),
                          const Text(
                            'SCAN A QR CODE',
                            style: TextStyle(
                              color: AppColors.ink,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .8,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Point your camera at a QR code to read it.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 22),
                          AspectRatio(
                            aspectRatio: 1,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  MobileScanner(
                                    controller: _controller,
                                    onDetect: _onDetect,
                                    errorBuilder: (context, error) =>
                                        _CameraError(
                                          error: error,
                                          onRetry: _scanAgain,
                                        ),
                                  ),
                                  if (!_handledScan)
                                    const IgnorePointer(
                                      child: CustomPaint(
                                        painter: _ScanFramePainter(),
                                      ),
                                    ),
                                  if (_handledScan)
                                    Container(
                                      color: AppColors.navy.withValues(
                                        alpha: .72,
                                      ),
                                      child: const Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.check_circle_rounded,
                                              color: AppColors.cyan,
                                              size: 48,
                                            ),
                                            SizedBox(height: 10),
                                            Text(
                                              'Code scanned',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _ScannerControl(
                                icon: Icons.flash_on_rounded,
                                label: 'Flash',
                                onPressed: _controller.toggleTorch,
                              ),
                              const SizedBox(width: 16),
                              _ScannerControl(
                                icon: Icons.cameraswitch_rounded,
                                label: 'Flip camera',
                                onPressed: _controller.switchCamera,
                              ),
                            ],
                          ),
                          if (_handledScan) ...[
                            const SizedBox(height: 18),
                            FilledButton.icon(
                              onPressed: _scanAgain,
                              icon: const Icon(Icons.qr_code_scanner_rounded),
                              label: const Text('Scan another code'),
                            ),
                          ],
                          const SizedBox(height: 14),
                          const Text(
                            'Scanned codes are added to your history on this device.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _ScannerHeader extends StatelessWidget {
  const _ScannerHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(21, 18, 20, 16),
      child: Row(
        children: [
          Icon(Icons.center_focus_strong_rounded, color: AppColors.cyan),
          SizedBox(width: 9),
          Text(
            'QR Scanner',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnsupportedCamera extends StatelessWidget {
  const _UnsupportedCamera();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.no_photography_outlined,
              color: AppColors.orange,
              size: 43,
            ),
            SizedBox(height: 12),
            Text(
              'Camera scanning is unavailable on this desktop platform.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 7),
            Text(
              'Use QR Gen on Android, iOS, macOS, or in a browser with camera access.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerControl extends StatelessWidget {
  const _ScannerControl({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.border),
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.error, required this.onRetry});

  final MobileScannerException error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              color: AppColors.orange,
              size: 40,
            ),
            const SizedBox(height: 10),
            const Text(
              'Camera unavailable',
              style: TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              error.errorDetails?.message ??
                  'Allow camera access and try again.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  const _ScanFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide * .66;
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: side,
      height: side,
    );
    final paint = Paint()
      ..color = AppColors.cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const corner = 25.0;
    for (final (start, xDirection, yDirection) in [
      (rect.topLeft, 1.0, 1.0),
      (rect.topRight, -1.0, 1.0),
      (rect.bottomLeft, 1.0, -1.0),
      (rect.bottomRight, -1.0, -1.0),
    ]) {
      final path = Path()
        ..moveTo(start.dx + corner * xDirection, start.dy)
        ..lineTo(start.dx, start.dy)
        ..lineTo(start.dx, start.dy + corner * yDirection);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
