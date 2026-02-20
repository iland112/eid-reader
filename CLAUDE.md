# CLAUDE.md - eID Reader Project Guide

## Project Purpose

Multi-platform eID (electronic Identity Document) Reader built with Flutter.
Primary goal: Read e-Passport (ICAO 9303) chip data via NFC on Android.
Future expansion: Windows and Linux desktop support via USB smart card readers.

This is a security-sensitive application handling personal identity data (PII).
All passport data stays in-memory only - never persisted to disk or transmitted over network.

## Development Environment

- **Project path**: `~/projects/flutter/eid_reader` (WSL2 Linux filesystem)
- **Build environment**: Docker DevContainer (`.devcontainer/`)
- **Base image**: `gmeligio/flutter-android:3.27.4`
- **IDE**: VS Code with Dev Containers + Remote WSL extensions
- **ADB**: TCP/IP mode (USB passthrough not available in WSL2/Docker)
  - Windows: `adb tcpip 5555`
  - DevContainer: `.devcontainer/connect-device.sh <device-ip>`

## Architecture

### Pattern: Feature-First Clean Architecture

```
lib/
├── app/            # App-level config (MaterialApp, GoRouter, Theme)
├── core/           # Shared across features
│   ├── error/      # Custom exception types
│   ├── platform/   # NFC service abstraction (multi-platform)
│   ├── utils/      # MRZ utilities, image helpers
│   └── widgets/    # Shared UI widgets
└── features/
    ├── mrz_input/          # MRZ data entry (manual + camera scan)
    ├── passport_reader/    # NFC passport reading (dmrtd integration)
    └── passport_display/   # Read data display + verification
```

Each feature follows:
```
feature/
├── presentation/   # Screens, Widgets, Riverpod Providers
├── domain/         # Entities, Use Cases (business logic)
└── data/           # Data sources, Repository implementations
```

### Navigation Flow

```
MRZ Input ──→ NFC Scan ──→ Passport Detail
    ↕
MRZ Camera Scan
```

Routes: `/mrz-input` → `/nfc-scan` → `/passport-detail`

### Multi-Platform Abstraction

The `dmrtd` library's `ComProvider` interface enables platform-agnostic passport reading:
- Android: `NfcProvider` (via `flutter_nfc_kit`, included in dmrtd)
- Desktop (future): `PcscProvider` (PC/SC API via `dart:ffi`)

The `Passport` class from dmrtd works identically regardless of communication provider.

## Tech Stack

| Purpose | Package | Notes |
|---|---|---|
| State Management | `flutter_riverpod` + `riverpod_annotation` | With code generation (`riverpod_generator`) |
| Navigation | `go_router` | Declarative, URL-based routing |
| Passport Reading | `dmrtd` (git dep: ZeroPass/dmrtd) | ICAO 9303, BAC+PACE, DG1/DG2 |
| NFC | `flutter_nfc_kit` | Direct dependency (also transitive via dmrtd) |
| Permissions | `permission_handler` | Camera, NFC permissions |
| Equality | `equatable` | Value equality for entities |
| Logging | `logging` | Structured logging |

## Code Rules

### General
- **Language**: Dart (Flutter). All source in `lib/`.
- **Formatting**: `dart format` with default settings (80 char line width).
- **Analysis**: `flutter analyze` must pass. Rules in `analysis_options.yaml`.
- **Single quotes** for strings: `'hello'` not `"hello"`.
- **Const constructors** wherever possible.
- **No `print()`**: Use `logging` package instead.

### Architecture Rules
- Features are independent. No cross-feature imports between `presentation/` layers.
- Features may share `domain/entities/` via explicit imports.
- All platform-specific code goes in `core/platform/` with abstract interfaces.
- Business logic lives in `domain/usecases/`, not in widgets or providers.
- Providers are thin wrappers that call use cases / repositories.

### State Management (Riverpod)
- Use `StateNotifier` + `StateNotifierProvider` for mutable state.
- Use `Provider` for immutable dependencies (router, services).
- Prefer code generation (`@riverpod` annotation) for new providers.
- Run `dart run build_runner build --delete-conflicting-outputs` after adding `@riverpod` annotated providers.

### Security (Critical)
- **NO persistent storage** of passport data. Memory only.
- **NO logging of PII** (names, document numbers, dates, biometric data).
- **NO network transmission** of passport data (v1 is fully offline).
- **NO secrets in Docker images** (keystores, signing keys).
- **FLAG_SECURE** (IMPLEMENTED): `SecureScreenService` + `MainActivity.kt` MethodChannel on passport detail screen.
- **Biometric buffer clearing** (IMPLEMENTED): `Uint8List.fillRange(0, length, 0)` in `PassportDetailScreen.dispose()`.
- See `docs/security.md` for full security architecture details.

### NFC / Passport Reading
- Always try PACE authentication first, fall back to BAC.
- Handle `TagLostException` with auto-retry guidance.
- Handle authentication failures by returning user to MRZ input.
- DG2 face images may be JPEG2000; try standard JPEG decode first, then platform channel fallback.
- The `dmrtd` API uses: `NfcProvider`, `Passport`, `DBAKey`, `EfDG1`, `EfDG2`, `EfCOM`, `EfSOD`.
- `DBAKey` constructor takes `(String docNum, DateTime dateOfBirth, DateTime dateOfExpiry)`.
- `EfDG2.imageData` for face image bytes; `MRP.documentCode` for document type.
- `MRP.dateOfBirth` / `MRP.dateOfExpiry` return `DateTime`, not `String`.
- See `docs/dmrtd-api-notes.md` for full API reference and common pitfalls.

### Error Handling
- Custom exceptions in `core/error/exceptions.dart`.
- User-facing error messages must be helpful and actionable.
- NFC errors should suggest repositioning the phone or retrying.
- Never expose raw exception messages to users.

### Testing
- Unit tests: `test/` directory, mirroring `lib/` structure. **71 tests across 7 files.**
- **Manual mock pattern** (no mockito codegen due to analyzer 7.x incompatibility).
- Use Riverpod `ProviderContainer` overrides for dependency injection in tests.
- For `MethodChannel` testing, use `TestDefaultBinaryMessengerBinding`.
- Widget tests for all screens using `flutter_test` (not yet implemented).
- Real device + passport needed for integration testing.
- See `docs/testing.md` for full test inventory and guide.

### Git
- **Branch**: `main`
- **Commit format**: Conventional Commits (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`)
- Commit after each meaningful unit of work.
- Never commit secrets, keystores, or `.env` files.

### File Naming
- Dart files: `snake_case.dart`
- Classes: `PascalCase`
- Variables/functions: `camelCase`
- Constants: `camelCase` (Dart convention, not SCREAMING_CASE)
- Feature directories: `snake_case`

## Key Files

- `lib/main.dart` - App entry point with ProviderScope
- `lib/app/router.dart` - GoRouter route definitions
- `lib/app/theme.dart` - Material 3 theme configuration
- `lib/core/platform/nfc_service.dart` - NFC abstraction interface
- `lib/core/platform/secure_screen_service.dart` - FLAG_SECURE abstraction + MethodChannel impl
- `lib/features/passport_reader/data/datasources/passport_datasource.dart` - Abstract datasource interface
- `lib/features/passport_reader/data/datasources/nfc_passport_datasource.dart` - Core dmrtd integration
- `lib/features/passport_reader/presentation/providers/passport_reader_provider.dart` - Notifier with DI support
- `lib/features/passport_display/presentation/screens/passport_detail_screen.dart` - Secure display with buffer clearing
- `lib/features/mrz_input/domain/usecases/validate_mrz.dart` - ICAO 9303 MRZ validation
- `android/app/src/main/kotlin/com/smartcoreinc/eid_reader/MainActivity.kt` - Native FLAG_SECURE handler
- `.devcontainer/Dockerfile` - Development environment
- `pubspec.yaml` - Dependencies (note: dmrtd is a git dependency)

## Documentation

- `docs/implementation-status.md` - What is implemented and what remains
- `docs/security.md` - Security architecture and measures
- `docs/testing.md` - Test inventory and guide
- `docs/dmrtd-api-notes.md` - dmrtd library API reference and pitfalls

## Commands

```bash
# Development
flutter pub get                    # Install dependencies
flutter run                        # Run on connected device
flutter build apk --debug         # Build debug APK

# Code generation (after adding @riverpod annotations)
dart run build_runner build --delete-conflicting-outputs

# Quality
flutter analyze                    # Static analysis
flutter test                       # Run tests
dart format lib/ test/             # Format code

# ADB (from DevContainer)
.devcontainer/connect-device.sh <device-ip>   # Connect Android device
flutter devices                                # List connected devices
```
