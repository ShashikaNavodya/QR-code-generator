import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrCodeDisplay extends StatelessWidget {
  const QrCodeDisplay({required this.data, super.key});

  final String data;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest.shortestSide;
        return SizedBox.square(
          dimension: size,
          child: QrImageView(
            data: data,
            version: QrVersions.auto,
            errorCorrectionLevel: QrErrorCorrectLevel.M,
            backgroundColor: Colors.white,
            padding: EdgeInsets.all(size * .14),
            gapless: true,
          ),
        );
      },
    );
  }
}
