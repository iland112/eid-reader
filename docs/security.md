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

### VIZ Face Comparison Security

On-device face comparison between camera-captured VIZ face and chip DG2 face image.
All processing happens locally; PII never leaves the device.

**Data flow security:**

1. **Full-page image zeroing**: after face extraction, `fullPageImageBytes.fillRange(0, length, 0)` — the
   full camera capture is not retained beyond the face crop step
2. **Embedding vector zeroing**: in `VerifyViz.execute()`, both VIZ and chip embedding vectors are zeroed
   in a `finally` block after cosine similarity calculation
3. **VIZ face buffer zeroing**: `vizFaceImageBytes.fillRange(0, length, 0)` in `PassportDetailScreen.dispose()`
4. **On-device TFLite model**: MobileFaceNet model is bundled as a Flutter asset — no runtime network
   download, no model update mechanism, no external API calls
5. **No PII logging**: similarity scores (numeric) are logged for debug; face bytes and embeddings are never logged

**Multi-frame glare-aware caching:**
Preview frames are cached in a ring buffer (up to 5 frames) with glare scores for best-frame
selection. Security measures:
- Each evicted frame is zero-filled (`nv21.fillRange(0, length, 0)`) before removal
- All non-selected candidates are zero-filled when VIZ capture selects the best frame
- On reset and dispose, all cached frames are zero-filled and cleared
- NV21→RGBA converted frame is zero-filled after VIZ processing completes

**Contrast enhancement retry:**
When initial face detection fails, `CaptureVizFace` creates a contrast-enhanced copy of the image
(1.5x linear stretch) as a temporary JPEG file in `Directory.systemTemp`. This temp file is
deleted in a `finally` block immediately after face detection, regardless of success or failure.
No biometric data persists to disk beyond this brief processing window.

**Files:**
- `lib/features/passport_reader/domain/usecases/verify_viz.dart` — embedding comparison + zeroing
- `lib/features/passport_reader/domain/usecases/capture_viz_face.dart` — RGBA face extraction + zeroing
- `lib/features/mrz_input/presentation/screens/mrz_camera_screen.dart` — glare-aware frame caching + NV21 zeroing
- `lib/core/utils/nv21_utils.dart` — NV21→RGBA conversion, glare scoring
- `lib/core/services/face_embedding_service.dart` — TFLite MobileFaceNet inference
- `assets/models/mobilefacenet.tflite` — pre-trained model (~5MB, bundled)

### Build-Time Secret Injection

PA Service credentials are injected via `--dart-define` at build time, keeping secrets out of
source code and Git history:

- `PA_API_KEY`: `const String.fromEnvironment('PA_API_KEY')` — empty string if not provided (public access)
- `PA_BASE_URL`: `const String.fromEnvironment('PA_BASE_URL', defaultValue: '...')` — server address override

These compile-time constants are embedded in the AOT binary, not extractable as plain text strings.

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
- `test/features/passport_reader/presentation/providers/passport_reader_provider_test.dart` - Error state handling, PA verification flow, VIZ verification step
- `test/features/passport_display/presentation/screens/passport_detail_screen_test.dart` - Buffer zeroing on dispose (face + VIZ buffers)
- `test/core/image/jpeg2000_detector_test.dart` - JP2/J2K/JPEG format detection (15 tests)
- `test/core/image/image_utils_test.dart` - Face image decode routing (3 tests)
- `test/features/passport_reader/domain/usecases/verify_viz_test.dart` - Embedding zeroing, face comparison, MRZ cross-verification (15 tests)
- `test/features/passport_reader/domain/usecases/capture_viz_face_test.dart` - Face extraction, quality analysis, contrast retry (9 tests)
- `test/core/services/face_embedding_service_test.dart` - Cosine similarity math (8 tests)
- `test/core/services/image_quality_analyzer_test.dart` - Blur/glare/saturation/contrast analysis (13 tests)
- `test/core/utils/nv21_to_rgba_test.dart` - NV21→RGBA conversion, rotation, edge cases (13 tests)
- `test/core/utils/nv21_glare_score_test.dart` - Y-plane glare scoring, threshold, boundary tests (12 tests)
