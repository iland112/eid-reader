# eID Reader

Multi-platform eID Reader application built with Flutter.
Reads e-Passport (ICAO 9303) chip data via NFC on Android and iOS.

## Features

- Manual MRZ data entry (document number, date of birth, date of expiry)
- Camera-based MRZ scanning with OCR (multi-frame consensus)
- NFC-based e-Passport chip reading (Android + iOS)
- BAC and PACE authentication protocols
- DG1 (biographical data) and DG2 (face image) reading
- Passive Authentication via REST API (optional)
- VIZ face capture + on-device face comparison (ML Kit + TFLite MobileFaceNet)
- Image quality analysis (blur, glare, exposure) with real-time feedback
- Per-field OCR vs chip MRZ cross-verification
- Capability-aware adaptive UI (NFC / OCR-only modes)
- Dark mode theming
- Localization (English, Korean)

## Tech Stack

- **Framework**: Flutter 3.27.4 (Android, iOS, Windows, Linux)
- **State Management**: Riverpod
- **Navigation**: GoRouter
- **Passport Reading**: dmrtd ([iland112/dmrtd](https://github.com/iland112/dmrtd) fork, ICAO 9303)
- **NFC**: flutter_nfc_kit
- **Development**: Docker DevContainer on WSL2 (Android); GitHub Actions macOS runner (iOS)

## Project Structure

```
lib/
├── app/            # App configuration (router, theme)
├── core/           # Shared utilities and platform abstractions
└── features/
    ├── mrz_input/          # MRZ data input (manual + camera)
    ├── passport_reader/    # NFC passport reading
    └── passport_display/   # Passport data display
```

## Development Setup

### Prerequisites

- **Android**: Docker Desktop with WSL2 backend, VS Code with Dev Containers extension
- **iOS**: macOS with Xcode 15+, or use GitHub Actions CI/CD

### Getting Started

```bash
git clone https://github.com/iland112/eid-reader.git
cd eid-reader
git clone https://github.com/iland112/dmrtd.git dmrtd-fork
flutter pub get
```

### Android (Local - DevContainer)

1. Open in VS Code → "Reopen in Container"
2. Connect device: `.devcontainer/connect-device.sh <device-ip>`
3. `flutter run --dart-define=PA_API_KEY=<key>`

### iOS (GitHub Actions CI/CD)

iOS builds run automatically on push/PR to `main` via `.github/workflows/ios-build.yml`.
Artifacts (Runner.app) available for download from workflow runs.

### Build

```bash
# Android
flutter build apk --debug --dart-define=PA_API_KEY=<key>
flutter build apk --release --dart-define=PA_API_KEY=<key>

# iOS (local, requires macOS + Xcode)
flutter build ios --no-codesign --release --dart-define=PA_API_KEY=<key>
```

## Status

- [x] Android NFC e-Passport reading
- [x] iOS NFC e-Passport reading (GitHub Actions CI)
- [x] Camera-based MRZ scanning with OCR
- [x] Passive Authentication verification
- [x] VIZ face capture and cross-verification
- [x] Image quality analysis and feedback
- [x] Capability-aware adaptive UI
- [ ] Apple TestFlight distribution
- [ ] Windows desktop (USB smart card reader)
- [ ] Linux desktop (USB smart card reader)

## License

TBD
