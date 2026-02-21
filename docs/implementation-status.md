# Implementation Status

Last updated: 2026-02-22

## Overview

eID Reader is a Flutter-based e-Passport reader application.
This document tracks what has been implemented and what remains.

## Completed

### Core Architecture (v0.1 - Initial Setup)

- Feature-first clean architecture (`app/`, `core/`, `features/`)
- Three features: `mrz_input`, `passport_reader`, `passport_display`
- Navigation flow: MRZ Input -> NFC Scan -> Passport Detail
- GoRouter declarative routing (`/mrz-input`, `/nfc-scan`, `/passport-detail`)
- Material 3 theme configuration
- Riverpod state management with `StateNotifier`
- DevContainer setup (`gmeligio/flutter-android:3.27.4`)

### Security Hardening (v0.2 → v0.7)

- **FLAG_SECURE**: `SecureScreenService` + `MainActivity.kt` MethodChannel (available but disabled in v0.7 per user preference)
- **Biometric buffer clearing**: `Uint8List.fillRange(0, length, 0)` in `dispose()`
- No persistent storage, no PII logging
- Network transmission only to PA Service API (SOD + DG bytes for verification)

### Dependency Injection Refactoring (v0.2)

- `PassportDatasource` abstract interface extracted
- `NfcPassportDatasource` implements the interface
- `PassportReaderNotifier` accepts injected datasource (defaults to NFC impl)
- Enables mock injection for unit testing

### dmrtd API Integration Fixes (v0.2)

- `DBAKey` constructor uses `DateTime` (not `String`)
- `EfDG2.imageData` (not `faceData`)
- `MRP.documentCode` (not `documentType`)
- `MRP.dateOfBirth` / `MRP.dateOfExpiry` return `DateTime`
- Added `_formatYYMMDD()` and `_parseYYMMDD()` helper functions
- PACE-first authentication with BAC fallback

### MRZ Camera Scan (v0.4)

- Camera-based MRZ OCR scanning using `google_mlkit_text_recognition` + `camera`
- `ParseMrzFromText` use case: ICAO 9303 TD3 MRZ detection and parsing from OCR text
  - Consecutive line detection, check digit validation, filler character handling
  - Reuses existing `MrzUtils.calculateCheckDigit()` for validation
- `MrzCameraNotifier` state management with `TextRecognitionService` abstraction for DI
- `MrzCameraScreen`: camera preview with MRZ overlay guide, detection panel, Rescan/Use This Data buttons
- Navigation: MrzInputScreen → "Scan MRZ" button → `/mrz-camera` → pop(MrzData) → auto-fill fields
- Android camera permission added to AndroidManifest.xml

### Passive Authentication (v0.5)

- PA Service REST API client integration (`POST /api/pa/verify`)
- `PaVerificationResult` entity: structured 8-step verification results (Equatable)
- `PassportReadResult` data class: wraps `PassportData` + raw SOD/DG1/DG2 bytes
- `PaService` abstract interface + `HttpPaService` implementation (`http` package)
- `NfcPassportDatasource`: reads EfSOD + preserves raw DG1/DG2 bytes via `toBytes()`
- `PassportReaderNotifier`: orchestrates NFC read → PA API call → combined results
- `ReadingStep` extended: `readingSod`, `verifyingPa` steps with UI feedback
- `PassportDetailScreen`: PA Verification Details section (cert chain, SOD sig, DG hash, timing)
- `PassportData.copyWith()` method for combining NFC read + PA results
- PA verification is optional (graceful degradation if server unavailable or SOD empty)
- Base URL configurable via `paServiceBaseUrlProvider` (Riverpod)

### NFC & UX Improvements (v0.7)

- **Haptic feedback**: `HapticFeedback.heavyImpact()` on NFC tag detection
- **Wakelock**: `wakelock_plus` keeps screen on during NFC reading
- **FLAG_SECURE disabled**: Screen capture enabled (removed `SecureScreenService` from passport detail)
- **NFC Scan Screen redesign**:
  - `NfcPulseAnimation` widget: radar-like ripple animation via `CustomPainter` + `AnimationController`
  - `ReadingStepIndicator` widget: 4-phase horizontal stepper (Connect → Auth → Read → Verify)
  - Positioning guide card with phone→passport illustration
  - Retry counter (max 3 attempts, then "Return to MRZ Input")
- **Passport Detail Screen redesign**:
  - `PassportHeaderCard` widget: passport-style card with Hero-wrapped photo, name, nationality badge, doc number, expiry badge
  - `InfoSectionCard` widget: reusable card with icon, title, label-value rows
  - `ExpiryDateBadge` widget: color-coded expiry status (green/orange/red) with 70-year pivot YYMMDD parsing
  - Security verification badge (green verified / orange pending)
- **Page transitions**: `CustomTransitionPage` — fade+slide for NFC scan, fade for passport detail (Hero-compatible)
- **MRZ Camera Screen**: flashlight toggle button in AppBar
- **MRZ Input Screen**: instruction card, grouped form card, button renamed "Scan Passport" with `Icons.contactless`

### Test Suite (v0.2 + v0.3 + v0.4 + v0.5 + v0.7)

- 171 tests across 16 test files (121 unit + 50 widget)
- Manual mock pattern (no mockito codegen due to analyzer incompatibility)
- Widget tests for all 4 screens (MrzInput, MrzCamera, NfcScan, PassportDetail)
- See [testing.md](testing.md) for details

### Android Deployment Config (v0.6 + v0.7)

- `minSdk` raised from 21 → 24 (`flutter_nfc_kit` requires API 24+)
- NFC permission added to `AndroidManifest.xml` (`android.permission.NFC`)
- INTERNET permission added to main manifest (required for PA API communication)
- `<uses-feature android:name="android.hardware.nfc" android:required="true" />`
- `<uses-feature android:name="android.hardware.camera" android:required="false" />`
- Kotlin Gradle plugin updated to 2.2.0 (required by `wakelock_plus` / `package_info_plus`)
- R8 minify + shrink resources enabled for release builds
- ProGuard rules for ML Kit optional script recognizers (`proguard-rules.pro`)
- Release APK build verified: `flutter build apk --release` → 89MB
- Target device: Galaxy A36 5G (Android 16, API 36)

### Infrastructure (v0.2)

- Android platform generated with `com.smartcoreinc.eid_reader` namespace
- Dockerfile image tag fixed (`3.27` -> `3.27.4`)
- `flutter_nfc_kit` added as direct dependency

## Not Yet Implemented

| Feature | Priority | Notes |
|---|---|---|
| ~~MRZ Camera Scan~~ | ~~Medium~~ | DONE (v0.4) — google_mlkit_text_recognition + camera, TD3 parsing |
| ~~Passive Authentication~~ | ~~Medium~~ | DONE (v0.5) — PA Service REST API client, raw SOD/DG bytes, 8-step verification |
| Active Authentication | Low | AA protocol (many passports don't support it) |
| ~~Widget Tests~~ | ~~Medium~~ | DONE (v0.3) — 33 widget tests across 3 screens |
| `@riverpod` Code Generation | Low | Migrate manual `StateNotifier` to `@riverpod` annotations |
| DG2 JPEG2000 Decoding | Low | Some passports use JP2 format; needs platform channel fallback |
| Desktop Support (Windows/Linux) | Low | `PcscProvider`-based USB smart card reader integration |

## Commit History

| Hash | Type | Description |
|---|---|---|
| `bd2439b` | chore | Initial project setup with Flutter architecture |
| `b733afc` | docs | Add CLAUDE.md with project guide |
| `e8b1be9` | feat | Security hardening, DI refactoring, 71 unit tests |
| `0f8f216` | docs | Project documentation and CLAUDE.md update |
