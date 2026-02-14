# eID Reader

Multi-platform eID Reader application built with Flutter.
Reads e-Passport (ICAO 9303) chip data via NFC on Android.

## Features (v1 - Android)

- Manual MRZ data input (document number, date of birth, date of expiry)
- NFC-based e-Passport chip reading
- BAC and PACE authentication protocols
- DG1 (biographical data) and DG2 (face image) reading
- Passport data display with security verification status

## Tech Stack

- **Framework**: Flutter (Android, Linux, Windows)
- **State Management**: Riverpod
- **Navigation**: GoRouter
- **Passport Reading**: dmrtd (ICAO 9303)
- **NFC**: flutter_nfc_kit (via dmrtd)
- **Development**: Docker DevContainer on WSL2

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

- Docker Desktop with WSL2 backend
- VS Code with Dev Containers extension

### Getting Started

1. Clone the repository
2. Open in VS Code
3. "Reopen in Container" when prompted
4. `flutter pub get`
5. Connect Android device via ADB TCP/IP:
   - On Windows: `adb tcpip 5555`
   - In DevContainer: `.devcontainer/connect-device.sh <device-ip>`

### Build

```bash
flutter build apk --debug
```

## Roadmap

- [ ] Android NFC e-Passport reading
- [ ] Camera-based MRZ scanning
- [ ] Passive authentication verification
- [ ] Windows desktop (USB smart card reader)
- [ ] Linux desktop (USB smart card reader)

## License

TBD
