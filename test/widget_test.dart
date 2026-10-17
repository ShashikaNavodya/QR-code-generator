import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_code_generator/app/quick_qr_app.dart';
import 'package:qr_code_generator/features/qr_codes/data/qr_code_service.dart';
import 'package:qr_code_generator/features/qr_codes/domain/qr_code_entry.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const QuickQrApp());
  await tester.pumpAndSettle();
}

Future<void> generate(WidgetTester tester) async {
  final button = find.text('GENERATE QR');
  await tester.drag(
    find.byType(SingleChildScrollView).first,
    const Offset(0, -280),
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows the QR Gen generator and all app sections', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('QR Gen'), findsOneWidget);
    expect(find.text('GENERATE'), findsOneWidget);
    expect(find.text('URL'), findsOneWidget);
    expect(find.text('TEXT'), findsOneWidget);
    expect(find.text('CONTACT'), findsOneWidget);
    expect(find.text('WI-FI'), findsOneWidget);
    expect(find.text('SMS'), findsOneWidget);
    expect(find.text('My Codes'), findsOneWidget);
    expect(find.text('Scanner'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('generates a URL QR code and saves it to My Codes', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.enterText(
      find.byType(TextField).first,
      'https://example.com/page',
    );
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsNothing);
    await generate(tester);

    expect(find.byType(QrImageView), findsOneWidget);
    final qrWidget = tester.widget<QrImageView>(find.byType(QrImageView));
    expect(qrWidget.backgroundColor, Colors.white);
    expect(qrWidget.eyeStyle.color, Colors.black);
    expect(qrWidget.dataModuleStyle.color, Colors.black);
    expect(qrWidget.errorCorrectionLevel, QrErrorCorrectLevel.M);
    expect(find.text('SHARE'), findsOneWidget);
    expect(find.text('SAVE'), findsOneWidget);

    await tester.tap(find.text('My Codes'));
    await tester.pumpAndSettle();
    expect(find.text('Website URL'), findsOneWidget);
    expect(find.text('example.com'), findsOneWidget);
  });

  testWidgets('pastes a URL into the URL field from the clipboard', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.getData') {
            return {'text': 'https://pasted.example/path'};
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await pumpApp(tester);
    await tester.tap(find.byTooltip('Paste URL'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'https://pasted.example/path',
    );
  });

  testWidgets('validates URLs before creating QR codes', (tester) async {
    await pumpApp(tester);
    await tester.enterText(find.byType(TextField).first, 'example.com');
    await generate(tester);

    expect(
      find.text('Enter a complete link, including https:// or http://.'),
      findsOneWidget,
    );
    expect(find.byType(QrImageView), findsNothing);
  });

  testWidgets('creates a vCard QR code from contact information', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('CONTACT'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Avery Example');
    await tester.enterText(find.byType(TextField).at(1), '+15551234567');
    await generate(tester);

    expect(find.byType(QrImageView), findsOneWidget);
    await tester.tap(find.text('My Codes'));
    await tester.pumpAndSettle();
    expect(find.text('Contact Card'), findsOneWidget);
    expect(find.text('Avery Example'), findsOneWidget);
  });

  testWidgets('creates a Wi-Fi QR code and validates network settings', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('WI-FI'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Studio WiFi');
    await generate(tester);
    expect(
      find.text('Enter the Wi-Fi password or select Open.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField).at(1), 'correct-horse');
    await generate(tester);
    expect(find.byType(QrImageView), findsOneWidget);
  });

  testWidgets('saves favorites and applies the favorites filter', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.enterText(find.byType(TextField).first, 'Hello QR');
    await tester.tap(find.text('TEXT'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Hello QR');
    await generate(tester);
    await tester.tap(find.text('My Codes'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Filter codes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favorites only'));
    await tester.pumpAndSettle();
    expect(find.text('Text Message'), findsOneWidget);
  });

  testWidgets('settings stores the scan history preference', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('qrgen.save_scans'), isFalse);
  });

  test('validates QR URLs and escapes Wi-Fi fields', () {
    final service = QrCodeService();
    expect(service.validate('https://example.com', QrContentType.url), isNull);
    expect(service.validate('example.com', QrContentType.url), isNotNull);
    expect(service.escapeWifiField(r'Lab;Net,1'), r'Lab\;Net\,1');
  });

  test('exports a plain black QR with a white quiet zone', () async {
    final entry = QrCodeEntry.create(
      data: 'https://example.com',
      type: QrContentType.url,
      color: Colors.cyan,
      logoEnabled: true,
    );
    final bytes = await QrCodeService().createPng(entry);
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final pixels = await frame.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    expect(frame.image.width, 1024);
    expect(frame.image.height, 1024);
    expect(pixels!.getUint32(0, Endian.big), 0xFFFFFFFF);

    var hasBlackPixel = false;
    for (var offset = 0; offset < pixels.lengthInBytes; offset += 4) {
      if (pixels.getUint32(offset, Endian.big) == 0x000000FF) {
        hasBlackPixel = true;
        break;
      }
    }
    expect(hasBlackPixel, isTrue);
    frame.image.dispose();
    codec.dispose();
  });

  test('serializes and restores all QR entry metadata', () {
    final entry = QrCodeEntry(
      id: 'entry-1',
      data: 'https://example.com',
      type: QrContentType.url,
      createdAt: DateTime(2026, 10, 15),
      colorValue: const Color(0xFF168451).toARGB32(),
      displayName: 'Example site',
      isFavorite: true,
      logoEnabled: false,
    );

    final restored = QrCodeEntry.fromJson(entry.toJson());
    expect(restored.data, entry.data);
    expect(restored.type, entry.type);
    expect(restored.colorValue, entry.colorValue);
    expect(restored.displayName, entry.displayName);
    expect(restored.isFavorite, isTrue);
    expect(restored.logoEnabled, isFalse);
  });
}
