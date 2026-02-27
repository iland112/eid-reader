# CLAUDE.md - eID Reader Project Guide

## Project Purpose

Multi-platform eID (electronic Identity Document) Reader built with Flutter.
Primary goal: Read e-Passport (ICAO 9303) chip data via NFC on Android.
Future expansion: Windows and Linux desktop support via USB smart card readers.

This is a security-sensitive application handling personal identity data (PII).
All passport data stays in-memory only - never persisted to disk. Network transmission only for PA verification.

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
│   ├── services/   # Face detection, embedding, image quality
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
                ┌──→ NFC/PC·SC Scan ──→ Passport Detail (e-Passport)
MRZ Input ──────┤
    ↕            └──→ Passport Detail (OCR-only, no chip reader)
MRZ Camera Scan
```

Routes: `/mrz-input` → `/mrz-camera` (optional) → `/scan` → `/passport-detail`
OCR-only: `/mrz-input` → `/passport-detail` (direct, via `MrzData.toPassportData()`)

### Multi-Platform Abstraction

The `dmrtd` library's `ComProvider` interface enables platform-agnostic passport reading:
- Android: `FastNfcProvider` (optimized `ComProvider` using `flutter_nfc_kit` directly, skips NDEF check)
- Desktop (future): `PcscProvider` (PC/SC API via `dart:ffi`)

The `Passport` class from dmrtd works identically regardless of communication provider.

## Tech Stack

| Purpose | Package | Notes |
|---|---|---|
| State Management | `flutter_riverpod` + `riverpod_annotation` | With code generation (`riverpod_generator`) |
| Navigation | `go_router` | Declarative, URL-based routing |
| Passport Reading | `dmrtd` (git dep: ZeroPass/dmrtd) | ICAO 9303, BAC+PACE, DG1/DG2/SOD |
| NFC | `flutter_nfc_kit` | Direct dependency (also transitive via dmrtd) |
| HTTP Client | `http` | PA Service REST API communication |
| Camera | `camera` | Camera preview and image stream |
| OCR | `google_mlkit_text_recognition` | ML Kit text recognition for MRZ scanning |
| Permissions | `permission_handler` | Camera, NFC permissions |
| Equality | `equatable` | Value equality for entities |
| SVG Rendering | `flutter_svg` | Country flag SVG display |
| Logging | `logging` | Structured logging |
| Wakelock | `wakelock_plus` | Keeps screen on during NFC reading |
| Face Detection | `google_mlkit_face_detection` | ML Kit face detection for VIZ capture |
| Face Embedding | `tflite_flutter` | TFLite MobileFaceNet for on-device face comparison |

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
- **Network transmission**: Only to PA Service API for Passive Authentication verification (SOD + DG bytes). No external servers.
- **NO secrets in Docker images** (keystores, signing keys).
- **FLAG_SECURE** (AVAILABLE, DISABLED): `SecureScreenService` + `MainActivity.kt` MethodChannel infrastructure exists but is not invoked from `PassportDetailScreen` (disabled in v0.7 per user preference). Re-enable by importing service in screen.
- **Biometric buffer clearing** (IMPLEMENTED): `Uint8List.fillRange(0, length, 0)` in `PassportDetailScreen.dispose()`.
- See `docs/security.md` for full security architecture details.

### NFC / Passport Reading
- `FastNfcProvider` replaces dmrtd's default `NfcProvider` for optimized NFC polling (skips NDEF check, platform sound).
- Always try PACE authentication first, fall back to BAC.
- Handle `TagLostException` with auto-retry guidance.
- Handle authentication failures by returning user to MRZ input.
- DG2 face images may be JPEG2000; try standard JPEG decode first, then platform channel fallback.
- The `dmrtd` API uses: `NfcProvider`, `Passport`, `DBAKey`, `EfDG1`, `EfDG2`, `EfCOM`, `EfSOD`.
- `DBAKey` constructor takes `(String docNum, DateTime dateOfBirth, DateTime dateOfExpiry)`.
- `EfDG2.imageData` for face image bytes; `MRP.documentCode` for document type.
- `MRP.dateOfBirth` / `MRP.dateOfExpiry` return `DateTime`, not `String`.
- All EF classes (`EfDG1`, `EfDG2`, `EfSOD`) support `toBytes()` for raw byte access.
- `EfSOD.parse()` is a stub (empty impl) but raw bytes are preserved via `ElementaryFile._encoded`.
- See `docs/dmrtd-api-notes.md` for full API reference and common pitfalls.

### Passive Authentication (PA)
- PA verification via REST API: `POST /api/pa/verify` (see `docs/PA_API_GUIDE.md`)
- `PaService` abstract interface + `HttpPaService` implementation (`http` package)
- PA is optional: graceful degradation if server unavailable or SOD bytes empty
- Base URL configurable via `paServiceBaseUrlProvider` (default: `http://192.168.1.70:8080` — Luckfox WiFi); override with `--dart-define=PA_BASE_URL=...`
- API Key via `paServiceApiKeyProvider` + `X-API-Key` header; inject with `--dart-define=PA_API_KEY=...`
- Rate limit (429) and permission denied (403) error handling
- `PaVerificationResult` entity: 8-step verification + v2.1.4+ fields (expirationStatus, validAtSigningTime, dscNonConformant, dscFingerprint)
- `PassportReadResult` carries raw SOD/DG1/DG2 bytes from NFC read to PA service
- `PassportData.copyWith()` combines NFC read data with PA results

### Error Handling
- Custom exceptions in `core/error/exceptions.dart`.
- User-facing error messages must be helpful and actionable.
- NFC errors should suggest repositioning the phone or retrying.
- Never expose raw exception messages to users.

### Testing
- Unit + widget tests: `test/` directory, mirroring `lib/` structure. **484 tests across 37 files.**
- **Manual mock pattern** (no mockito codegen due to analyzer 7.x incompatibility).
- Use Riverpod `ProviderContainer` overrides for dependency injection in tests.
- For `MethodChannel` testing, use `TestDefaultBinaryMessengerBinding`.
- Widget tests for all 4 screens (MrzInput, MrzCamera, NfcScan, PassportDetail) with GoRouter + mock providers.
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
- `lib/core/platform/fast_nfc_provider.dart` - Optimized NFC ComProvider (skips NDEF, custom haptic)
- `lib/core/platform/secure_screen_service.dart` - FLAG_SECURE abstraction + MethodChannel impl (available, not active)
- `lib/core/utils/country_code_utils.dart` - ISO 3166-1 alpha-3 → alpha-2 mapping (249+ countries)
- `lib/app/device_capability_provider.dart` - Runtime NFC/PC·SC capability detection (Riverpod FutureProvider)
- `lib/app/theme_mode_provider.dart` - Dark/light mode toggle (Riverpod StateNotifier)
- `lib/features/passport_reader/presentation/widgets/nfc_pulse_animation.dart` - Animated NFC pulse rings via CustomPainter
- `lib/features/passport_reader/presentation/widgets/reading_step_indicator.dart` - 5-phase step indicator (Connect → Auth → Read → Verify → VIZ)
- `lib/features/passport_display/presentation/widgets/passport_header_card.dart` - Passport-style header with Hero photo
- `lib/features/passport_display/presentation/widgets/info_section_card.dart` - Reusable card with icon, title, rows
- `lib/features/passport_display/presentation/widgets/expiry_date_badge.dart` - Color-coded expiry status badge
- `lib/features/passport_reader/data/datasources/passport_datasource.dart` - Abstract datasource interface (returns PassportReadResult)
- `lib/features/passport_reader/data/datasources/nfc_passport_datasource.dart` - Core dmrtd integration (reads DG1/DG2/SOD)
- `lib/features/passport_reader/data/datasources/pa_service.dart` - PA verification service interface
- `lib/features/passport_reader/data/datasources/http_pa_service.dart` - HTTP PA Service REST API client
- `lib/features/passport_reader/domain/entities/pa_verification_result.dart` - PA 8-step verification result entity
- `lib/features/passport_reader/presentation/providers/passport_reader_provider.dart` - Notifier with NFC + PA + VIZ orchestration
- `lib/features/passport_display/presentation/screens/passport_detail_screen.dart` - Secure display with buffer clearing
- `lib/features/mrz_input/domain/usecases/validate_mrz.dart` - ICAO 9303 MRZ validation
- `lib/features/mrz_input/domain/usecases/parse_mrz_from_text.dart` - MRZ OCR text parser (TD3 format)
- `lib/features/mrz_input/presentation/screens/mrz_camera_screen.dart` - Camera-based MRZ + VIZ scanning screen
- `lib/features/mrz_input/presentation/providers/mrz_camera_provider.dart` - Camera scan + VIZ capture state management
- `lib/features/mrz_input/domain/entities/viz_capture_result.dart` - VIZ capture result (face bytes + quality metrics)
- `lib/features/passport_reader/domain/entities/face_comparison_result.dart` - Face comparison result entity
- `lib/features/passport_reader/domain/entities/image_quality_metrics.dart` - Image quality metrics entity
- `lib/features/passport_reader/domain/usecases/capture_viz_face.dart` - Face extraction from camera image
- `lib/features/passport_reader/domain/usecases/verify_viz.dart` - VIZ-chip cross-verification use case
- `lib/core/services/face_detection_service.dart` - ML Kit face detection abstraction
- `lib/core/services/face_embedding_service.dart` - TFLite MobileFaceNet face embedding
- `lib/core/services/image_quality_analyzer.dart` - Image quality analysis (blur, glare, saturation, contrast)
- `lib/features/passport_display/presentation/widgets/viz_verification_card.dart` - VIZ verification display card (per-field MRZ comparison)
- `lib/features/passport_display/presentation/widgets/face_comparison_badge.dart` - Face match status badge
- `lib/features/mrz_input/domain/usecases/mrz_ocr_corrector.dart` - Position-aware MRZ OCR character correction
- `lib/core/utils/icao_codes.dart` - ICAO state code validation + single-char OCR correction
- `lib/core/utils/nv21_utils.dart` - NV21 ROI cropping, NV21→RGBA conversion, glare scoring
- `lib/core/services/debug_log_service.dart` - Debug log file output + in-memory ring buffer for on-device overlay
- `lib/features/passport_reader/domain/entities/mrz_field_comparison.dart` - Per-field OCR vs chip comparison entity
- `android/app/src/main/kotlin/com/smartcoreinc/eid_reader/MainActivity.kt` - Native FLAG_SECURE handler
- `.devcontainer/Dockerfile` - Development environment
- `pubspec.yaml` - Dependencies (note: dmrtd is a git dependency)

## Documentation

- `docs/implementation-status.md` - What is implemented and what remains
- `docs/security.md` - Security architecture and measures
- `docs/testing.md` - Test inventory and guide
- `docs/dmrtd-api-notes.md` - dmrtd library API reference and pitfalls
- `docs/PA_API_GUIDE.md` - PA Service REST API guide (8-step verification)

## Android Build Config

- **applicationId**: `com.smartcoreinc.eid_reader`
- **minSdk**: 24 (required by `flutter_nfc_kit`)
- **targetSdk**: Flutter default (`flutter.targetSdkVersion`)
- **Permissions**: `CAMERA`, `NFC`, `INTERNET`
- **Required hardware**: `android.hardware.nfc` (required=true), `android.hardware.camera` (required=false)
- **Kotlin Gradle plugin**: 2.2.0
- **R8 minify/shrink**: enabled for release builds with `proguard-rules.pro`
- **Debug signing**: uses debug keys (no Play Store deployment planned)
- **Release APK**: `flutter build apk --release` → ~89MB

## Commands

```bash
# Development
flutter pub get                    # Install dependencies
flutter run --dart-define=PA_API_KEY=<key>   # Run with PA API key
flutter build apk --debug --dart-define=PA_API_KEY=<key>   # Debug APK
flutter build apk --release --dart-define=PA_API_KEY=<key>  # Release APK

# Optional: override PA server address (default: http://192.168.1.70:8080)
flutter run --dart-define=PA_API_KEY=<key> --dart-define=PA_BASE_URL=http://host:port

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
