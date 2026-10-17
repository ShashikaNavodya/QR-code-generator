import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/qr_code_entry.dart';

class QrCodeService {
  static const maxContentBytes = 2200;

  String? validate(String value, QrContentType type) {
    if (value.trim().isEmpty) return 'Add some content to create your QR code.';
    if (type == QrContentType.url) {
      final uri = Uri.tryParse(value.trim());
      if (uri == null ||
          !uri.hasAuthority ||
          uri.host.isEmpty ||
          !{'http', 'https'}.contains(uri.scheme.toLowerCase())) {
        return 'Enter a complete link, including https:// or http://.';
      }
    }
    if (utf8.encode(value).length > maxContentBytes) {
      return 'That content is too long for a QR code. Try shortening it.';
    }
    return null;
  }

  String escapeWifiField(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll(';', r'\;')
      .replaceAll(',', r'\,');

  Future<Uint8List> createPng(QrCodeEntry entry) async {
    final painter = QrPainter(
      data: entry.data,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      gapless: true,
    );
    final qrData = await painter.toImageData(736);
    if (qrData == null) {
      throw StateError('The QR image could not be created.');
    }

    final codec = await ui.instantiateImageCodec(qrData.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = 1024.0;
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, size, size),
      Paint()..color = Colors.white,
    );
    canvas.drawImageRect(
      frame.image,
      Rect.fromLTWH(
        0,
        0,
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      ),
      const Rect.fromLTWH(144, 144, 736, 736),
      Paint()..filterQuality = FilterQuality.none,
    );
    final image = await recorder.endRecording().toImage(1024, 1024);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    codec.dispose();
    frame.image.dispose();
    image.dispose();
    if (png == null) throw StateError('The QR image could not be exported.');
    return png.buffer.asUint8List();
  }

  Future<String> save(QrCodeEntry entry) async {
    final bytes = await createPng(entry);
    return FileSaver.instance.saveFile(
      name: 'qrgen-${entry.id}',
      bytes: bytes,
      fileExtension: 'png',
      mimeType: MimeType.png,
    );
  }

  Future<void> share(QrCodeEntry entry) async {
    final bytes = await createPng(entry);
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            bytes,
            mimeType: 'image/png',
            name: 'qrgen-${entry.id}.png',
          ),
        ],
        fileNameOverrides: ['qrgen-${entry.id}.png'],
        subject: entry.title,
        text: entry.data,
      ),
    );
  }
}
