# Implementation Status

Last updated: 2026-02-24

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

### Dark Mode Theming (v0.8)

- All hardcoded `Colors.*` replaced with Material 3 `ColorScheme` tokens
- Affected: `passport_detail_screen.dart`, `expiry_date_badge.dart`, `nfc_pulse_animation.dart`, `reading_step_indicator.dart`, `nfc_scan_screen.dart`, `mrz_camera_screen.dart`
- Key mappings: `Colors.black87` → `surfaceContainerHighest`, `Colors.greenAccent` → `primary`, `Colors.white` → `onSurface`/`onPrimary`, `Colors.yellowAccent` → `tertiary`
- Dark/light mode toggle: `ThemeModeNotifier` (Riverpod `StateNotifier`) + `IconButton` in MRZ Input AppBar

### App Icon & Country Flag Display (v0.8)

- **App icon**: Custom icon from `assets/favicon.ico` via `flutter_launcher_icons` (adaptive icon for Android)
- **App label**: `eid_reader` → `eID Reader` in AndroidManifest.xml
- **Country flag**: `flutter_svg` renders flag SVGs in `PassportHeaderCard` nationality badge
- **Country code mapping**: `CountryCodeUtils` — ISO 3166-1 alpha-3 → alpha-2 (249+ entries, ICAO-specific codes)
- 12 new tests for `CountryCodeUtils`

### NFC Connect Optimization (v0.8)

- `FastNfcProvider`: custom `ComProvider` replacing dmrtd's `NfcProvider`
- Skips NDEF discovery (`androidCheckNDEF: false`) — e-Passports don't use NDEF (~500ms savings)
- Skips platform NFC sound (`androidPlatformSound: false`) — app provides custom haptic feedback
- Supports ISO 14443A + 14443B for ICAO Doc 9303 compatibility

### DG2 JPEG2000 Decoding (v0.9)

- **OpenJPEG 2.5.4** C library as git submodule (`native/openjpeg/openjpeg/`)
- **CMake native build**: compiled for Android (NDK), Linux, and Windows
- **C wrapper** (`opj_flutter.c`): memory stream decoding in C, exposes `opj_flutter_decode()` / `opj_flutter_free()`
- **dart:ffi bindings** (`openjpeg_ffi.dart`): loads `libopenjp2.so` / `openjp2.dll`, calls native decoder
- **RGBA → PNG conversion**: via `image` package (`Image.fromBytes()` → `encodePng()`)
- **Format detection** (`jpeg2000_detector.dart`): pure Dart magic byte detection
  - JP2 container: `00 00 00 0C 6A 50 20 20`
  - J2K codestream: `FF 4F FF 51` (SOC + SIZ)
  - JPEG: `FF D8 FF`
- **`decodeFaceImage()`** (`image_utils.dart`): JPEG passthrough, JP2/J2K → OpenJPEG → PNG, unknown → null
- **Datasource integration**: `nfc_passport_datasource.dart` calls `decodeFaceImage()` after DG2 read
- **Security**: native buffers zeroed (`memset(0)`) before `free()`; Dart buffers `fillRange(0, length, 0)`
- 18 new tests (15 detector + 3 image_utils)

### Desktop PC/SC Smart Card Reader Support (v0.9)

- **`dart_pcsc` package** (v2.0.2): Windows/Linux PC/SC API bindings via dart:ffi
- **`PcscProvider`** (`core/platform/pcsc_provider.dart`): `ComProvider` implementation wrapping `dart_pcsc`
  - `connect()`: `Context.establish()` → `listReaders()` → `waitForCard()` → `connect(reader)`
  - `transceive()`: `card.transmit(data)` — ISO 7816 APDU (same as NFC)
  - `disconnect()`: `card.disconnect()` → `context.release()`
- **`PcscService`** abstraction: `pcsc_service.dart` (interface) + `pcsc_service_impl.dart` (Desktop) + `pcsc_service_stub.dart` (Android)
- **`PcscPassportDatasource`**: mirrors `NfcPassportDatasource` pattern using `PcscProvider`
- **`PassportDatasourceFactory`**: platform factory — NFC on Android/iOS, PC/SC on Desktop
- **Desktop UI**:
  - `PcscScanScreen`: card reader animation, reader dropdown selection, step indicator
  - `CardReaderAnimation`: animated card reader icon with pulse during active reading
  - No wakelock/haptic feedback (Desktop-specific)
- **Platform-adaptive routing**: `/scan` route renders `NfcScanScreen` or `PcscScanScreen`
- **MRZ Input adaptation**: camera scan hidden on Desktop, button text/icon adapted
- **Platform directories**: `windows/` and `linux/` created via `flutter create`
- 3 new tests (PcscService stub)

### VIZ Capture + Face Comparison + Hologram Detection (v0.10)

- **VIZ (Visual Inspection Zone) capture**: camera captures passport data page, extracts face via ML Kit face detection
- **On-device face comparison**: TFLite MobileFaceNet (112x112 → 192D embedding) compares VIZ face vs chip DG2 face
- **Image quality analysis**: Laplacian blur, glare ratio, saturation std dev (hologram rainbow detection), Michelson contrast
- **MRZ OCR cross-verification**: OCR MRZ fields compared against chip DG1 data
- **Quality-adjusted thresholds**: poor image quality reduces face match threshold by 0.15
- **New entities**: `FaceComparisonResult`, `ImageQualityMetrics`, `VizCaptureResult`
- **New services**: `FaceDetectionService` (ML Kit), `FaceEmbeddingService` (TFLite), `ImageQualityAnalyzer` (pure Dart)
- **New use cases**: `CaptureVizFace`, `VerifyViz`
- **New widgets**: `VizVerificationCard`, `FaceComparisonBadge`
- **Camera screen enhancement**: enlarged overlay (320x200), `takePicture()` still capture, face detection feedback, quality warnings
- **NFC scan flow**: 5th step "VIZ" added to `ReadingStep` + `ReadingStepIndicator` (conditional on VIZ capture)
- **Passport detail**: VIZ verification card with side-by-side faces, similarity score, MRZ match status, quality warnings
- **Security**: embedding vectors zeroed after comparison, full-page image zeroed after face extraction, VIZ face buffer zeroed on dispose
- **New packages**: `google_mlkit_face_detection: ^0.12.0`, `tflite_flutter: ^0.11.0`
- **Model**: MobileFaceNet TFLite (~5MB) bundled in `assets/models/`
- **Platform**: VIZ features Android-only (camera-dependent); Desktop auto-skips (vizCaptureResult always null)
- 58 new tests (7 new test files)

### MRZ OCR Enhancement + Field Comparison + Date Formatting (v0.11)

- **Full MRZ field parsing**: `MrzData` expanded with optional fields (`surname`, `givenNames`, `nationality`, `sex`, `documentType`, `issuingState`, `mrzLine1`, `mrzLine2`)
- **ParseMrzFromText**: extracts all fields from both TD3 MRZ lines (Line 1: doc type, issuing state, name; Line 2: nationality, sex)
- **MRZ preview on camera**: monospace card showing raw MRZ lines + expanded field display (Name, Nationality, Sex)
- **Field-by-field OCR vs DG1 comparison**: `MrzFieldMatch`/`MrzFieldComparisonResult` entities, per-field check/X icons in `VizVerificationCard`, up to 7 fields compared (doc number, DOB, DOE + surname, givenNames, nationality, sex)
- **Enhanced OCR correction**: `MrzOcrCorrector` class with position-aware confusion matrix (digit↔alpha), `IcaoCodes` dictionary (~250 ICAO state codes with single-char OCR correction)
- **Multi-frame consensus**: camera provider requires N matching frames (default 3) before confirming MRZ detection
- **Face detection improvement**: `minFaceSize` reduced 0.15 → 0.08, constructor parameter injection; `CaptureVizFace` retries with 1.5x contrast-enhanced image on initial failure
- **Date display formatting**: `MrzUtils.formatDisplayDate()` converts YYMMDD → "DD MMM YYYY"; `isDob` parameter shifts future dates back 100 years; applied to camera screen, passport detail, expiry badge
- **`cameraMrzData` preservation**: `MrzInputProvider` stores full `MrzData` from camera scan through the pipeline
- 90 new tests (7 new test files + updates to 8 existing test files)

### Performance Optimization Phase 2 (v0.12)

- **OCR ROI cropping**: `cropNv21ForMrz()` utility crops NV21 buffer to MRZ region (~40% of user-visible bottom) before ML Kit, reducing OCR pixel count by 60%
  - Rotation-aware cropping (0°/90°/180°/270°): row crop for 0°/180°, column crop for 90°/270°
  - `srcStride` support for camera buffers with row padding
  - Buffer size validation (skip crop if buffer too small)
  - Even-alignment enforcement for NV21 chroma subsampling
- **Preview face reuse**: caches last preview NV21 frame, runs ML Kit face detection during 300ms stabilization delay via `Future.wait()`, scales coordinates to high-res still image → skips ~500ms high-res ML Kit detection
  - `rawSize` vs `previewSize` separation: raw buffer dims for ML Kit metadata, rotated dims for coordinate scaling
- **Ghost image defense**: position-aware face selection (`_selectMainFace`) prefers faces in the left 40% of image (ICAO 9303 main photo position) with 1.5x area scoring bonus
- **NFC maxRead increase**: dmrtd fork `_defaultReadLength` 112 → 224 bytes per APDU, halving DG2 read round-trips
- **Debug log service**: `DebugLogService` singleton with file output + in-memory ring buffer for on-device log overlay
- **Measured results** (Galaxy A36 5G):
  - MRZ consensus: ~28 frames / ~19s → ~9 frames / ~6s (**-68%**)
  - VIZ face capture: ~867ms → ~250ms (**-71%**)
  - NFC DG2 read: 4.3s → 3.0s (**-30%**)
- New files: `lib/core/utils/nv21_utils.dart`, `lib/core/services/debug_log_service.dart`
- 48 new tests (17 nv21_utils + 2 ghost image + 5 preview face + 24 others)

### Capability-Aware Adaptive UI (v0.13)

- **Runtime device capability detection**: `ChipReaderCapability` enum + `chipReaderCapabilityProvider` (Riverpod `FutureProvider`)
  - Reuses existing `NfcServiceAndroid`, `PcscServiceImpl` (no new service classes)
  - `hasChipReader()` utility function for simple boolean checks
- **OCR-only mode**: `MrzData.toPassportData()` converts MRZ OCR data to `PassportData` with `authProtocol: 'OCR'`
  - `PassportData.isOcrOnly` getter for conditional UI rendering
  - Bypasses NFC/PC·SC scan, navigates directly from MRZ input to passport detail
- **Landing screen adaptation**: feature chips dynamic based on capability
  - Chip reader available: NFC Read + PA Verify + OCR Scan chips
  - No chip reader: OCR Scan chip only
- **MRZ Input screen adaptation**:
  - NFC disabled banner: warns user to enable NFC (with NFC icon)
  - OCR-only banner: informs camera scan shows MRZ data only (with info icon)
  - Camera scan button promoted to `ElevatedButton` when no chip reader
  - "View Passport Info" button for OCR-only direct navigation
  - Chip reader scan button hidden when no reader available
- **PassportDetail screen OCR mode**:
  - Title: "Passport Info (OCR)" instead of "e-Passport Details"
  - OCR badge (blue info) instead of security verification badge
  - Security Status, PA Verification Details, Scan Timing, VIZ Verification sections hidden
  - Personal Information and Document Details sections shown
- **Accessible info color**: `AccessibleColors.info()` blue pair (WCAG AA compliant)
- **Localization**: 8 new keys × 2 languages (en/ko) for OCR-related UI strings
- New files: `lib/app/device_capability_provider.dart`
- 22 new tests (2 new test files + updates to 4 existing test files)

### PA Service API Key + Rate Limit + Base URL (v0.14)

- **Base URL 변경**: `192.168.1.70:8080` (WiFi) → `192.168.100.10:8080` (유선 LAN)
- **API Key 지원**: 선택적 `X-API-Key` 헤더 (`paServiceApiKeyProvider`, v2.1.10+)
- **Rate Limit 처리**: 429 응답 처리 (Retry-After 파싱)
- **403 Forbidden 처리**: 권한 부족 에러 메시지 반환
- **PaVerificationResult 확장**: 7개 새 필드 — `validAtSigningTime`, `expirationStatus`, `expirationMessage`, `dscNonConformant`, `pkdConformanceCode`, `pkdConformanceText`, `dscFingerprint`
- **PassportDetailScreen PA 섹션 확장**: 만료 상태, 서명 시점 유효성, DSC 비준수 경고 표시
- **로컬라이제이션**: 5개 새 키 × 2 언어 (en/ko)
- 8 new tests (updates to 4 existing test files)

### Test Suite (v0.2 – v0.14)

- 484 tests across 37 test files (~378 unit + ~106 widget)
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
| ~~DG2 JPEG2000 Decoding~~ | ~~Low~~ | DONE (v0.9) — OpenJPEG FFI, JP2/J2K detection, RGBA→PNG |
| ~~Desktop Support (Windows/Linux)~~ | ~~Low~~ | DONE (v0.9) — `PcscProvider` + `dart_pcsc`, platform-adaptive UI |
| ~~VIZ Capture + Face Comparison~~ | ~~Medium~~ | DONE (v0.10) — ML Kit face detection, TFLite MobileFaceNet, image quality analysis |
| ~~MRZ Full Field Parsing + Comparison~~ | ~~Medium~~ | DONE (v0.11) — All MRZ fields parsed, field-by-field OCR↔DG1 comparison |
| ~~Enhanced OCR Correction~~ | ~~Medium~~ | DONE (v0.11) — MrzOcrCorrector, ICAO codes, multi-frame consensus |
| ~~Face Detection Improvement~~ | ~~Low~~ | DONE (v0.11) — minFaceSize 0.08, contrast enhancement retry |
| ~~Performance Optimization~~ | ~~Medium~~ | DONE (v0.12) — OCR ROI crop, preview face reuse, ghost image defense, NFC maxRead 224 |
| ~~Capability-aware UI~~ | ~~Medium~~ | DONE (v0.13) — Runtime NFC/PC·SC detection, OCR-only mode, adaptive Landing/MRZ/Detail screens |
| VIZ threshold tuning | Low | Tune similarity/quality thresholds with real passport data |

## Commit History

| Hash | Type | Description |
|---|---|---|
| `bd2439b` | chore | Initial project setup with Flutter architecture |
| `b733afc` | docs | Add CLAUDE.md with project guide |
| `e8b1be9` | feat | Security hardening, DI refactoring, 71 unit tests |
| `0f8f216` | docs | Project documentation and CLAUDE.md update |
