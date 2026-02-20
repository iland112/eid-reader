# Implementation Status

Last updated: 2026-02-20

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

### Security Hardening (v0.2)

- **FLAG_SECURE**: Android screen capture prevention on passport detail screen
  - `SecureScreenService` abstraction with MethodChannel implementation
  - Native Kotlin handler in `MainActivity.kt`
  - Enabled on screen enter, disabled on leave
- **Biometric buffer clearing**: `Uint8List.fillRange(0, length, 0)` in `dispose()`
- No persistent storage, no PII logging, no network transmission

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

### Test Suite (v0.2 + v0.3)

- 104 tests across 10 test files (71 unit + 33 widget)
- Manual mock pattern (no mockito codegen due to analyzer incompatibility)
- Widget tests for all 3 screens (MrzInput, NfcScan, PassportDetail)
- See [testing.md](testing.md) for details

### Infrastructure (v0.2)

- Android platform generated with `com.smartcoreinc.eid_reader` namespace
- Dockerfile image tag fixed (`3.27` -> `3.27.4`)
- `flutter_nfc_kit` added as direct dependency

## Not Yet Implemented

| Feature | Priority | Notes |
|---|---|---|
| MRZ Camera Scan | Medium | OCR-based MRZ auto-recognition via camera |
| Passive Authentication | Medium | EfSOD signature verification (dmrtd `EfSOD` is currently a stub) |
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
