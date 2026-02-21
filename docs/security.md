# Security Architecture

## Principles

eID Reader handles personal identity data (PII) including names, document numbers,
dates, nationality, and biometric face images. The following security principles apply:

1. **Memory-only data** - Passport data is never persisted to disk or database
2. **Minimal network transmission** - Only SOD/DG bytes sent to PA Service API for verification; no PII sent
3. **No PII logging** - Never log names, document numbers, dates, or biometric data
4. **Screen capture prevention** - FLAG_SECURE infrastructure available (currently disabled per user preference)
5. **Biometric buffer clearing** - Zero out `Uint8List` buffers on navigation away

## Implemented Measures

### FLAG_SECURE (Android Screen Capture Prevention)

Infrastructure to prevent screenshots and screen recording on the passport detail screen.
**Currently disabled** (v0.7) — `SecureScreenService` is not invoked from `PassportDetailScreen`.
Can be re-enabled by importing and calling the service in `initState()`/`dispose()`.

**Architecture:**

```
PassportDetailScreen (Flutter)
    |
    v
SecureScreenService (abstract interface)
    |
    v
SecureScreenServiceImpl (MethodChannel)
    |
    v
MainActivity.kt (native Android)
    |
    v
WindowManager.LayoutParams.FLAG_SECURE
```

**Files:**
- `lib/core/platform/secure_screen_service.dart` - Abstract interface + MethodChannel impl
- `android/app/src/main/kotlin/com/smartcoreinc/eid_reader/MainActivity.kt` - Native handler

**MethodChannel:** `com.smartcoreinc.eid_reader/secure_screen`
- `enableSecureMode` -> `window.addFlags(FLAG_SECURE)`
- `disableSecureMode` -> `window.clearFlags(FLAG_SECURE)`

### Biometric Buffer Clearing

Face image data (`Uint8List`) is zeroed when leaving the passport detail screen:

```dart
@override
void dispose() {
  final faceBytes = widget.passportData.faceImageBytes;
  if (faceBytes != null) {
    faceBytes.fillRange(0, faceBytes.length, 0);
  }
  super.dispose();
}
```

This prevents residual biometric data from remaining in memory after the user
navigates away from the screen.

### Native Buffer Security (OpenJPEG JPEG2000 Decoding)

When decoding DG2 face images from JPEG2000 format, biometric data passes through
native (C) memory buffers. These are secured at multiple layers:

1. **C wrapper (`opj_flutter.c`)**: `opj_flutter_free()` calls `memset(buf, 0, size)` before `free(buf)`
2. **Dart FFI layer (`openjpeg_ffi.dart`)**: input buffer zeroed via `nativeData.asTypedList(length).fillRange(0, length, 0)` before `calloc.free()`
3. **No disk I/O**: all decoding uses in-memory streams (`opj_stream_create()` with custom read callbacks), never writes temporary files
4. **No PII logging**: decoded image dimensions logged for debug, but never image data content

### NFC Authentication Security

The passport reading flow uses ICAO 9303 compliant authentication:

1. **PACE first** - Password Authenticated Connection Establishment (stronger)
2. **BAC fallback** - Basic Access Control (if PACE not supported)

Both require the MRZ data (document number, date of birth, date of expiry) as
the shared secret, ensuring only someone with physical access to the passport's
data page can read the chip.

### Passive Authentication (PA)

Verifies chip data integrity via SOD digital signature chain:

- SOD + DG1/DG2 raw bytes sent to PA Service REST API (`POST /api/pa/verify`)
- 8-step verification: cert chain, DSC/CSCA validation, CRL check, SOD signature, DG hash
- PA is optional — graceful degradation if server unavailable or SOD bytes empty
- Only cryptographic bytes transmitted; no PII (names, dates) leaves the device

## Not Yet Implemented

| Measure | Description |
|---|---|
| Active Authentication | Verify chip is genuine, not cloned (low priority, many passports don't support AA) |
| Certificate pinning | Consider for PA Service API communication |
| Root/jailbreak detection | Consider for future versions |
| Memory encryption | Dart GC handles deallocation; explicit zeroing is the current mitigation |

## Testing

Security features are tested in:
- `test/core/platform/secure_screen_service_test.dart` - MethodChannel mock verification
- `test/features/passport_reader/presentation/providers/passport_reader_provider_test.dart` - Error state handling, PA verification flow
- `test/features/passport_display/presentation/screens/passport_detail_screen_test.dart` - Buffer zeroing on dispose
- `test/core/image/jpeg2000_detector_test.dart` - JP2/J2K/JPEG format detection (15 tests)
- `test/core/image/image_utils_test.dart` - Face image decode routing (3 tests)
