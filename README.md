# QR Gen

A full-featured Flutter QR creator with a neon, dark interface.

## Features

- Create plain black-and-white QR codes for URLs, plain text, vCards, Wi-Fi networks, and SMS.
- Generate the QR only after confirming the content with the create button.
- Preview, save as PNG, and share QR images.
- Scan codes with the device camera, copy scan results, and open scanned links.
- Browse My Codes and History, favorite or delete codes, and filter favorites.
- Choose whether scans are saved to history.
- Store codes and preferences locally on the device.

## Run

```sh
flutter pub get
flutter run
```

Camera scanning is supported on Android, iOS, macOS, and web. Camera scanning
is not available on Windows or Linux.

## Project structure

```text
lib/
  app/                       App entry widget and configuration
  core/
    theme/                   Shared colors and theme
    widgets/                 Reusable QR display and brand mark
  features/
    generator/presentation/  QR creation and customization
    home/presentation/       Main tabs and code management
      widgets/               Navigation, code tiles, details
    qr_codes/
      data/                  QR generation, export, and local storage
      domain/                QR code entry model
    scanner/presentation/    Camera scanner UI
  main.dart                  Flutter entry point
```

## Build

```sh
flutter build apk
flutter build web --no-wasm-dry-run
```
