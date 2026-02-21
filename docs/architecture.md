# Architecture

## Overview

eID Reader is a multi-platform Flutter application that reads e-Passport (ICAO 9303) chip data. On Android it communicates via NFC; on Windows and Linux it uses USB smart card readers via PC/SC. The application performs cryptographic Passive Authentication, decodes JPEG 2000 face images through native OpenJPEG FFI, and displays results in a secure, memory-only environment.

```
User enters MRZ data (manual or camera OCR)
        |
        v
Camera captures VIZ face + quality analysis (optional, Android only)
        |
        v
Authenticate with passport chip (BAC)
        |
        v
Read DG1 (biographical) + DG2 (face image) + SOD (security object)
        |
        v
Decode face image (JPEG passthrough or JPEG2000 via OpenJPEG FFI)
        |
        v
Verify via Passive Authentication REST API (optional)
        |
        v
VIZ verification: face comparison + MRZ cross-check (optional)
        |
        v
Display results (secure, memory-only, biometric buffer zeroed on exit)
```

---

## Project Structure

```
lib/
├── main.dart                   # Entry point: ProviderScope + EidReaderApp
├── app/                        # App-level configuration
│   ├── app.dart                # MaterialApp.router (ConsumerWidget)
│   ├── router.dart             # GoRouter: 4 routes with platform branching
│   ├── theme.dart              # Material 3 light/dark themes
│   └── theme_mode_provider.dart
├── core/                       # Shared modules
│   ├── error/exceptions.dart   # Custom exception types
│   ├── platform/               # Platform abstraction (NFC, PC/SC, FLAG_SECURE)
│   ├── image/                  # JPEG2000 detection + OpenJPEG FFI decoding
│   ├── services/               # Face detection, embedding, image quality
│   └── utils/                  # MRZ utilities, country code mapping
└── features/
    ├── mrz_input/              # MRZ data entry + camera OCR scan
    ├── passport_reader/        # NFC/PC/SC reading + PA verification
    └── passport_display/       # Secure passport data display

native/openjpeg/                # C wrapper + OpenJPEG 2.5.2 submodule
android/                        # Android runner + NDK/CMake config
linux/                          # Linux runner + CMake config
windows/                        # Windows runner + CMake config
test/                           # 261 tests across 26 files
```

---

## Layered Architecture

Each feature follows a three-layer pattern adapted from Clean Architecture:

```
┌─────────────────────────────────────────┐
│          Presentation Layer             │
│  Screens  |  Widgets  |  Providers      │
│  (Flutter UI + Riverpod state)          │
├─────────────────────────────────────────┤
│            Domain Layer                 │
│  Entities  |  Use Cases                 │
│  (Pure Dart, no framework deps)         │
├─────────────────────────────────────────┤
│             Data Layer                  │
│  Datasources  |  Services               │
│  (NFC/PC/SC, HTTP, platform APIs)       │
└─────────────────────────────────────────┘
```

**Dependency rule**: Presentation depends on Domain. Data depends on Domain. Domain has no outward dependencies.

**Feature isolation**: Features do not import each other's `presentation/` layer. Cross-feature sharing is limited to `domain/entities/` (e.g., `MrzData` is shared from `mrz_input` to `passport_reader`).

---

## Navigation Flow

```
/mrz-input ──────────> /scan ──────────> /passport-detail
     │                   │
     │ (optional)        │ (platform branch)
     v                   ├─ Android: NfcScanScreen
/mrz-camera              └─ Desktop: PcscScanScreen
     │
     └── pop(MrzData)
```

Routing is defined in `lib/app/router.dart` using GoRouter. Key design decisions:

- **Platform-adaptive `/scan` route**: Uses `PassportDatasourceFactory.isNfcPlatform` to render `NfcScanScreen` or `PcscScanScreen`
- **Object passing via `state.extra`**: `MrzData` and `PassportData` are passed between screens, with type-safe guards (`is!` checks with fallback pages)
- **Custom page transitions**: Fade+slide for `/scan`, fade for `/passport-detail` (Hero-animation compatible)

---

## State Management

Riverpod provides dependency injection and reactive state. All mutable state lives in `StateNotifier` subclasses.

### Provider Dependency Graph

```
paServiceBaseUrlProvider (Provider<String>)
        │
        v
paServiceProvider (Provider<PaService?>)
        │
        v
passportReaderProvider (StateNotifierProvider)
  PassportReaderNotifier
    ├── _datasource: PassportDatasource (injected or auto-detected)
    ├── _paService: PaService? (optional PA verification)
    └── _verifyViz: VerifyViz? (optional VIZ verification)

faceEmbeddingServiceProvider (Provider<FaceEmbeddingService>)
verifyVizProvider (Provider<VerifyViz>)
faceDetectionServiceProvider (Provider<FaceDetectionService>)
imageQualityAnalyzerProvider (Provider<ImageQualityAnalyzer>)
captureVizFaceProvider (Provider<CaptureVizFace>)

mrzInputProvider (StateNotifierProvider)
  MrzInputNotifier → MrzInputState

mrzCameraProvider (StateNotifierProvider)
  MrzCameraNotifier → MrzCameraState

themeModeProvider (StateNotifierProvider)
  ThemeModeNotifier → ThemeMode

routerProvider (Provider<GoRouter>)

secureScreenServiceProvider (Provider<SecureScreenService>)
```

### State Flow: Passport Reading

```dart
enum ReadingStep {
  idle,            // Initial state
  connecting,      // NFC polling / PC/SC card detection
  authenticating,  // BAC authentication
  readingDg1,      // Reading MRZ biographical data
  readingDg2,      // Reading face image
  readingSod,      // Reading security object document
  verifyingPa,     // Passive Authentication API call
  verifyingViz,    // VIZ face comparison + MRZ cross-check
  done,            // Success — PassportData available
  error,           // Error — errorMessage available
}
```

`PassportReaderNotifier.readPassport()` drives the state machine. The UI observes `PassportReaderState.step` and renders the appropriate phase indicator.

---

## Platform Abstraction

### The ComProvider Pattern

The `dmrtd` library defines `ComProvider` as the communication abstraction for passport reading. This is the key integration point that enables multi-platform support:

```
                    dmrtd Passport API
                          │
                    ComProvider (abstract)
                     connect() / transceive() / disconnect()
                          │
              ┌───────────┴───────────┐
              │                       │
       FastNfcProvider           PcscProvider
       (Android NFC)          (Desktop PC/SC)
              │                       │
       flutter_nfc_kit           dart_pcsc
              │                       │
        NFC hardware          USB card reader
```

Both providers implement the same `connect()`, `transceive()`, `disconnect()` interface. The `dmrtd` `Passport` class sends ISO 7816 APDUs identically regardless of the underlying transport.

### FastNfcProvider

Optimized NFC provider that skips NDEF discovery (`androidCheckNDEF: false`) and platform sounds (`androidPlatformSound: false`), saving ~500ms per connection.

### PcscProvider

Wraps `dart_pcsc` for PC/SC smart card communication. Supports reader selection (preferred reader or first available) and T=1 protocol for ISO 7816.

### Platform Factory

```dart
class PassportDatasourceFactory {
  static bool get isNfcPlatform => Platform.isAndroid || Platform.isIOS;
  static bool get isPcscPlatform => Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  static PassportDatasource create({String? preferredReader}) {
    if (isNfcPlatform) return NfcPassportDatasource();
    if (isPcscPlatform) return PcscPassportDatasource(preferredReader: preferredReader);
    throw UnsupportedError('...');
  }
}
```

### Stub Pattern for Platform APIs

Platform-specific APIs use a stub pattern to avoid compile-time errors on unsupported platforms:

| Interface | Desktop Implementation | Mobile Stub |
|---|---|---|
| `PcscService` | `PcscServiceImpl` (dart_pcsc) | `PcscServiceStub` (returns `notSupported`) |
| `NfcService` | `NfcServiceStub` | `NfcServiceAndroid` (flutter_nfc_kit) |

---

## Data Flow: Passport Reading Pipeline

```
MrzData (documentNumber, dateOfBirth, dateOfExpiry)
    │
    v
┌───────────────────────────────────────────────────┐
│ PassportReaderNotifier.readPassport(mrzData)       │
│                                                    │
│  1. Check NFC/PC/SC availability                   │
│  2. Call datasource.readPassport(mrzData)           │
│     ├─ connect (NFC poll or PC/SC card wait)       │
│     ├─ BAC auth via DBAKey(docNum, DOB, expiry)    │
│     ├─ Read EfDG1 → MRZ biographical data          │
│     ├─ Read EfDG2 → face image bytes               │
│     │   └─ decodeFaceImage():                      │
│     │       ├─ JPEG → passthrough                  │
│     │       ├─ JP2/J2K → OpenJPEG FFI → PNG        │
│     │       └─ Unknown → null (fallback icon)      │
│     ├─ Read EfSOD → security object bytes           │
│     └─ disconnect                                  │
│                                                    │
│  Returns: PassportReadResult                       │
│    ├─ PassportData (parsed fields + face PNG)      │
│    ├─ sodBytes, dg1Bytes, dg2Bytes (raw)           │
│    └─ stepTimings (ms per operation)               │
│                                                    │
│  3. Optional: PA verification                      │
│     ├─ POST /api/pa/verify (SOD + DG bytes, base64)│
│     └─ PaVerificationResult (8-step validation)    │
│                                                    │
│  4. Optional: VIZ verification (if VIZ captured)   │
│     ├─ Generate face embeddings (TFLite MobileFaceNet)│
│     ├─ Cosine similarity → FaceComparisonResult    │
│     ├─ OCR MRZ vs chip DG1 field comparison        │
│     ├─ Quality-adjusted thresholds                 │
│     └─ Zero embedding vectors (security)           │
│                                                    │
│  5. Emit PassportReaderState(step: done, data: ...) │
└───────────────────────────────────────────────────┘
    │
    v
PassportDetailScreen (secure display with buffer zeroing)
```

---

## Native Layer: JPEG 2000 Decoding

Some e-Passports store DG2 face images in JPEG 2000 format, which Flutter cannot decode natively. The application includes OpenJPEG 2.5.2 as a git submodule with a thin C wrapper.

### Architecture

```
Dart (image_utils.dart)
  │ detectImageFormat() — magic byte detection
  │
  v
Dart FFI (openjpeg_ffi.dart)
  │ Allocate native memory, copy JP2 data, call decode
  │
  v
C wrapper (opj_flutter.c)
  │ Memory-stream callbacks: mem_read, mem_skip, mem_seek
  │ Decode to RGBA via opj_decode()
  │ Dimension guard (max 10000x10000)
  │ Clamp + scale components to 8-bit RGBA
  │
  v
OpenJPEG 2.5.2 (libopenjp2.so / openjp2.dll)
  │
  v
Dart FFI (openjpeg_ffi.dart)
  │ Convert RGBA → PNG via `image` package
  │ Zero native buffer via opj_flutter_free() → memset(0) + free()
  │ Zero input buffer before calloc.free()
  │
  v
Uint8List (PNG) → Flutter Image.memory()
```

### C Interface

```c
// Decode JP2/J2K from memory to RGBA pixel buffer
int opj_flutter_decode(
    const uint8_t* data, size_t data_length,
    int codec_type,                    // 0=J2K, 2=JP2
    uint8_t** out_rgba,                // Allocated by C, freed by caller
    int32_t* out_width, int32_t* out_height);

// Free with security zeroing (memset before free)
void opj_flutter_free(uint8_t* ptr, size_t length);
```

### Format Detection

Pure Dart magic byte detection (`jpeg2000_detector.dart`):

| Format | Magic Bytes | Offset |
|---|---|---|
| JPEG | `FF D8 FF` | 0 |
| JP2 container | `00 00 00 0C 6A 50 20 20` | 0 |
| J2K codestream | `FF 4F FF 51` (SOC + SIZ) | 0 |

### Build Integration

OpenJPEG is compiled per-platform via CMake:

- **Android**: `android/app/src/main/CMakeLists.txt` → NDK cross-compilation
- **Linux**: `linux/CMakeLists.txt` → system compiler
- **Windows**: `windows/CMakeLists.txt` → MSVC

All three reference `native/openjpeg/CMakeLists.txt` which builds the OpenJPEG submodule as a shared library.

---

## Passive Authentication

PA verifies that passport chip data has not been tampered with by validating the SOD digital signature chain.

### Architecture

```
NfcPassportDatasource                    PA Service REST API
  ├─ Read EfSOD → raw bytes              POST /api/pa/verify
  ├─ Read EfDG1 → raw bytes      ──>     { sod, dataGroups: {1, 2} }
  └─ Read EfDG2 → raw bytes              (all base64 encoded)
                                              │
                                              v
                                    8-step verification:
                                    1. Certificate chain validation
                                    2. DSC validity check
                                    3. CSCA validity check
                                    4. CRL revocation check
                                    5. SOD signature validation
                                    6. Hash algorithm verification
                                    7. Data group hash validation
                                    8. Overall result (VALID/INVALID/ERROR)
                                              │
                                              v
                                    PaVerificationResult
```

### Integration Points

- `PaService` — abstract interface for PA verification
- `HttpPaService` — REST API client (`http` package, 30s timeout)
- `paServiceBaseUrlProvider` — configurable base URL (Riverpod)
- PA is **optional**: graceful degradation if server unavailable or SOD bytes empty

### Data Boundary

Only cryptographic bytes (SOD, DG1, DG2) are transmitted to the PA API. No PII (names, dates, document numbers) leaves the device in the PA request payload — these are embedded within the encrypted DG structures.

---

## VIZ Verification

VIZ (Visual Inspection Zone) verification cross-checks the camera-captured passport data page against chip data to detect document tampering or cloning.

### Architecture

```
Camera Screen (MRZ + VIZ capture)
  ├─ ML Kit text recognition → MRZ data (existing)
  ├─ takePicture() → high-res still capture
  ├─ ML Kit face detection → face bounding box
  ├─ image package → face crop (20% padding)
  ├─ ImageQualityAnalyzer → blur/glare/saturation/contrast
  └─ VizCaptureResult (face bytes + quality metrics)
          │
          v
NFC Scan (after PA verification)
  ├─ TFLite MobileFaceNet → VIZ face embedding (192D)
  ├─ TFLite MobileFaceNet → chip DG2 face embedding (192D)
  ├─ Cosine similarity → FaceComparisonResult
  │   ├─ >= 0.65: high confidence match
  │   ├─ 0.50-0.65: medium confidence
  │   ├─ 0.35-0.50: low confidence
  │   └─ < 0.35: unreliable/mismatch
  ├─ Quality-based threshold adjustment (-0.15 for poor quality)
  ├─ OCR MRZ vs chip DG1 field comparison
  └─ Zero embedding vectors (security)
          │
          v
Passport Detail Screen
  ├─ VizVerificationCard: side-by-side faces, similarity badge
  ├─ MRZ fields match status
  └─ Image quality warnings (hologram interference)
```

### Services

| Service | Purpose | Implementation |
|---|---|---|
| `FaceDetectionService` | Detect faces in camera image | ML Kit `google_mlkit_face_detection` |
| `FaceEmbeddingService` | Generate face embedding vector | TFLite `MobileFaceNet` (112x112 → 192D) |
| `ImageQualityAnalyzer` | Analyze image quality metrics | Pure Dart (`image` package) |

### Use Cases

| Use Case | Purpose |
|---|---|
| `CaptureVizFace` | Extract face from camera image, analyze quality |
| `VerifyViz` | Compare VIZ face vs chip face, cross-check MRZ fields |

### Image Quality Metrics

| Metric | Method | Hologram Detection |
|---|---|---|
| Blur score | Laplacian variance on grayscale | Reflective hologram causes defocus |
| Glare ratio | Luminance > 240 pixel ratio | Hologram creates bright spots |
| Saturation std dev | HSV S-channel variance | Rainbow hologram pattern |
| Contrast ratio | Michelson contrast | Hologram overlay reduces contrast |

### Platform Support

- **Android**: Full VIZ pipeline (camera → ML Kit → TFLite → comparison)
- **Desktop**: VIZ auto-skipped (`vizCaptureResult` always null, no camera)

---

## Security Architecture

### Principles

1. **Memory-only data** — passport data is never persisted to disk
2. **Minimal network** — only SOD/DG bytes sent to PA API for verification
3. **No PII logging** — `logging` package used; no names, document numbers, or dates logged
4. **Biometric buffer clearing** — face image `Uint8List` zeroed on screen dispose
5. **Native buffer clearing** — C memory `memset(0)` before `free()`

### Implementation Details

| Layer | Measure | Location |
|---|---|---|
| Android display | `FLAG_SECURE` (screen capture prevention) | `SecureScreenService` + `MainActivity.kt` |
| Dart memory | `faceImageBytes.fillRange(0, length, 0)` | `PassportDetailScreen.dispose()` |
| Native C memory | `memset(ptr, 0, length)` before `free()` | `opj_flutter_free()` |
| Dart FFI memory | Input buffer zero-fill before `calloc.free()` | `OpenjpegFfi.decodeJpeg2000ToPng()` |
| Native decoding | In-memory streams only, no temp files | `mem_read/skip/seek` callbacks |
| Network | Base64 SOD/DG bytes only, no PII in request body | `HttpPaService.verify()` |
| C decoder | Dimension guard (max 10000x10000) | `opj_flutter_decode()` |
| C decoder | Precision=0 UB guard in `clamp_component` | `opj_flutter.c` |
| VIZ face | Full-page image zeroed after face extraction | `CaptureVizFace.execute()` |
| VIZ face | Embedding vectors zeroed after comparison | `VerifyViz.execute()` finally block |
| VIZ face | VIZ face buffer zeroed on screen dispose | `PassportDetailScreen.dispose()` |
| TFLite model | Bundled asset, no runtime download | `assets/models/mobilefacenet.tflite` |

### Authentication Protocol

```
1. Connect to passport chip (NFC or PC/SC)
2. BAC (Basic Access Control) authentication
   - DBAKey derived from MRZ: document number + DOB + expiry
   - 3DES session key establishment
3. Read data groups over encrypted session
```

The application uses BAC directly. PACE support is architecturally ready (dmrtd supports `startSessionPACE`) but not currently used.

---

## Error Handling Strategy

### Custom Exceptions

```dart
NfcNotAvailableException   // Device lacks NFC hardware
NfcDisabledException       // NFC hardware disabled
TagLostException           // NFC connection dropped mid-read
AuthenticationException    // BAC/PACE auth failure
ReadTimeoutException       // Reading exceeded timeout
```

### Error Recovery

| Error | Strategy | User Message |
|---|---|---|
| Tag lost | Auto-retry (3x in datasource) | "Keep your phone still..." |
| Auth failure | Return to MRZ input | "Check your passport details" |
| Polling timeout | Show retry button | "Place phone flat on passport..." |
| DG2 read failure | Continue without face image | (silent, shows fallback icon) |
| SOD read failure | Continue without PA | (silent, PA shows "pending") |
| PA API unavailable | Graceful degradation | PA section shows "not verified" |

### Error Classification in Provider

`PassportReaderNotifier._getErrorMessage()` classifies raw exception strings into user-friendly messages using keyword matching (TagLost, SecurityStatusNotSatisfied, timeout, etc.).

---

## MRZ Input Feature

### Manual Input

`MrzInputScreen` provides a form with three fields: document number, date of birth (YYMMDD), and date of expiry (YYMMDD). `ValidateMrz` use case validates each field according to ICAO 9303 rules (alphanumeric doc number up to 9 chars, 6-digit YYMMDD dates with valid month/day ranges). The screen adapts to the current platform: on Desktop the camera scan button is hidden and the submit button reads "Read with Card Reader" with a USB icon; on Android it reads "Scan Passport" with a contactless icon.

### Camera OCR Scan

Camera-based MRZ scanning allows users to auto-fill MRZ fields by pointing the camera at the passport data page. The pipeline spans four layers:

```
┌──────────────────────────────────────────────────────────────────┐
│ MrzCameraScreen (UI layer)                                       │
│                                                                  │
│  CameraController                                                │
│  ├─ Back camera, ResolutionPreset.high                          │
│  ├─ imageFormatGroup: NV21 (preferred)                          │
│  └─ startImageStream → _processFrame() every 500ms             │
│                                                                  │
│  Frame throttling:                                               │
│  ├─ _isProcessingFrame flag prevents concurrent processing      │
│  └─ 500ms minimum interval between frames                       │
│                                                                  │
│  YUV420 → NV21 conversion (when camera returns YUV_420_888):    │
│  ├─ Copy Y plane (handle bytesPerRow padding)                   │
│  └─ Interleave V+U planes (NV21 = VUVUVU... layout)            │
│                                                                  │
│  InputImage construction:                                        │
│  ├─ sensorOrientation → InputImageRotation                      │
│  ├─ NV21 bytes + metadata (size, rotation, format, bytesPerRow) │
│  └─ Passed to MrzCameraNotifier.processImage()                  │
├──────────────────────────────────────────────────────────────────┤
│ MrzCameraNotifier (state management layer)                       │
│                                                                  │
│  State: MrzCameraState                                           │
│  ├─ isProcessing: bool (frame being analyzed)                   │
│  ├─ detectedMrz: MrzData? (null until valid MRZ found)         │
│  ├─ debugOcrText: String? (raw OCR debug output)                │
│  └─ debugFrameCount: int (frames processed so far)              │
│                                                                  │
│  processImage(InputImage):                                       │
│  ├─ Skip if already processing or MRZ already detected          │
│  ├─ Call TextRecognitionService.recognizeText(image)             │
│  ├─ Call ParseMrzFromText.parse(text)                            │
│  ├─ Build debug info (char count, line count, long lines)       │
│  └─ Update state: detectedMrz if found, debugOcrText always    │
│                                                                  │
│  Dependency injection:                                           │
│  ├─ TextRecognitionService (abstract, default: ML Kit)          │
│  └─ ParseMrzFromText (injectable for testing)                   │
├──────────────────────────────────────────────────────────────────┤
│ TextRecognitionService (OCR abstraction layer)                   │
│                                                                  │
│  Abstract interface:                                             │
│  ├─ recognizeText(InputImage) → Future<String>                  │
│  └─ close()                                                     │
│                                                                  │
│  MlKitTextRecognitionService (default implementation):           │
│  ├─ google_mlkit_text_recognition TextRecognizer                │
│  └─ processImage() → RecognizedText → .text                    │
│                                                                  │
│  Testability: mock service can return predetermined OCR text    │
├──────────────────────────────────────────────────────────────────┤
│ ParseMrzFromText (parsing + validation layer)                    │
│                                                                  │
│  ICAO 9303 TD3 format: 2 lines x 44 characters                 │
│  ├─ Line 1: P<COUNTRY<SURNAME<<GIVEN<NAMES<<<...               │
│  └─ Line 2: DOC_NUM[CD]NAT[DOB][CD]SEX[DOE][CD]OPT_DATA[CD]   │
│                                                                  │
│  Step 1: Normalize OCR text                                      │
│  ├─ toUpperCase()                                                │
│  ├─ Replace « → < (OCR variant of filler)                       │
│  └─ Remove whitespace                                           │
│                                                                  │
│  Step 2: Find candidate lines                                    │
│  ├─ Split by newlines                                           │
│  ├─ Filter: length 42-46 (allow OCR variance)                  │
│  └─ Normalize to exactly 44 chars (trim or pad with <)          │
│                                                                  │
│  Step 3: OCR error correction (_correctOcrErrors)                │
│  ├─ Position-aware: uses TD3 field layout                       │
│  ├─ Digit positions → alpha-to-digit substitution               │
│  └─ Alpha positions → digit-to-alpha substitution               │
│                                                                  │
│  Step 4: Pattern matching                                        │
│  ├─ Line 1: must match ^P[A-Z<]{43}$                           │
│  └─ Line 2: must match ^[A-Z0-9<]{44}$ (after correction)      │
│                                                                  │
│  Step 5: Field extraction from Line 2                            │
│  ├─ [0-8] Document number, [9] check digit                     │
│  ├─ [13-18] Date of birth, [19] check digit                    │
│  └─ [21-26] Date of expiry, [27] check digit                   │
│                                                                  │
│  Step 6: Check digit validation (3 independent checks)           │
│  ├─ MrzUtils.calculateCheckDigit(docNumber) == line2[9]         │
│  ├─ MrzUtils.calculateCheckDigit(dateOfBirth) == line2[19]      │
│  └─ MrzUtils.calculateCheckDigit(dateOfExpiry) == line2[27]     │
│  Any mismatch → return null (reject this candidate pair)        │
│                                                                  │
│  Step 7: Final cleanup and return MrzData                        │
│  ├─ Document number: strip trailing < fillers                   │
│  ├─ Validate dates are 6 digits                                 │
│  └─ Return MrzData(documentNumber, dateOfBirth, dateOfExpiry)   │
└──────────────────────────────────────────────────────────────────┘
```

### OCR Error Correction Detail

MRZ uses OCR-B font, but ML Kit is trained on general text. Certain characters are systematically misread. The correction exploits the fact that TD3 Line 2 has a **fixed field layout** — we know exactly which positions should be digits vs. letters.

**Digit context positions** (expected to be `0-9`):

| Position | Field |
|---|---|
| 9 | Document number check digit |
| 13-18 | Date of birth (YYMMDD) |
| 19 | DOB check digit |
| 21-26 | Date of expiry (YYMMDD) |
| 27 | DOE check digit |
| 43 | Composite check digit |

**Alpha context positions** (expected to be `A-Z`):

| Position | Field |
|---|---|
| 10-12 | Nationality code |

**Substitution rules in digit context:**

| OCR reads | Corrected to | Reason |
|---|---|---|
| O, Q, D | 0 | Round shape confusion |
| I, l, L | 1 | Vertical stroke confusion |
| Z | 2 | Angular similarity |
| S | 5 | Curved shape similarity |
| G | 6 | Round shape confusion |
| B | 8 | Double-loop confusion |

**Substitution rules in alpha context:**

| OCR reads | Corrected to | Reason |
|---|---|---|
| 0 | O | Reverse of digit correction |
| 1 | I | Reverse of digit correction |
| 8 | B | Reverse of digit correction |

### ICAO 9303 Check Digit Algorithm

Each protected field uses a weighted checksum with weights `[7, 3, 1]` cycling:

```
Input: "L898902C"

Character values: L=21, 8=8, 9=9, 8=8, 9=9, 0=0, 2=2, C=12
  (A=10, B=11, ..., Z=35, 0-9=0-9, <=0)

Weighted sum:
  21×7 + 8×3 + 9×1 + 8×7 + 9×3 + 0×1 + 2×7 + 12×3
  = 147 + 24 + 9 + 56 + 27 + 0 + 14 + 36 = 313

Check digit: 313 mod 10 = 3
```

All three field check digits must pass for the MRZ to be accepted. This provides strong validation that OCR read the correct characters — a single misread character will almost certainly produce a different check digit.

### Camera Image Format Handling

Android cameras can return frames in different YUV formats depending on device. ML Kit's `InputImage.fromBytes()` requires NV21 format:

```
Camera returns NV21 (imageFormatGroup: nv21):
  → Use plane[0].bytes directly

Camera returns YUV_420_888 (3 separate planes):
  → Convert to NV21:
    1. Copy Y plane row by row (handle bytesPerRow padding)
    2. Interleave V and U planes: NV21 = [Y plane][V U V U V U ...]
       - V plane: planes[2], with bytesPerRow and pixelStride
       - U plane: planes[1], with bytesPerRow and pixelStride

Other formats:
  → Skip frame (return null)
```

The `imageFormatGroup: ImageFormatGroup.nv21` setting requests NV21 directly, but some devices ignore this and return YUV_420_888 anyway. The `_yuv420ToNv21()` conversion handles this fallback.

### Camera Screen UI

The screen has two main areas:

**Camera preview area:**
- Full camera preview with semi-transparent dark overlay
- Clear rectangular window (320x80) centered on screen showing where to position the MRZ
- `_MrzOverlayPainter` (CustomPainter) draws the cutout using `Path.combine(PathOperation.difference)`
- Flashlight toggle button in AppBar for low-light conditions

**Bottom panel** (context-dependent):

```
MRZ not yet detected:
  ├─ LinearProgressIndicator (when processing a frame)
  ├─ "Position the MRZ area of your passport within the frame"
  └─ Debug OCR text (monospace, frame count, line lengths, raw text)

MRZ detected:
  ├─ ✓ "MRZ Detected" (green check icon)
  ├─ Extracted fields: Document No., Date of Birth, Date of Expiry
  └─ [Rescan] [Use This Data] buttons
```

### Navigation Integration

```
MrzInputScreen
  └─ "Scan MRZ" button → context.pushNamed('mrz-camera')
                                    │
                          MrzCameraScreen
                            └─ "Use This Data" → Navigator.pop(MrzData)
                                    │
MrzInputScreen (receives MrzData, auto-fills form fields)
```

The camera screen returns `MrzData` via `Navigator.pop(data)`. The input screen receives it through the `GoRouter` pop result and populates the form fields automatically.

### Testability

The OCR pipeline is designed for testing without camera hardware:

- `TextRecognitionService` abstract interface enables mock OCR responses
- `ParseMrzFromText` is a pure Dart class testable with raw strings
- `MrzCameraNotifier.processText(String)` bypasses `InputImage` for unit tests
- Bottom panel widget testing uses `MrzCameraState` directly, no camera needed
- 16 tests for `ParseMrzFromText` cover: valid TD3, OCR noise, empty/short/non-MRZ text, bad check digits, trailing fillers, guillemet handling, blank line collapsing
- 10 tests for `MrzCameraNotifier` cover: state transitions, detection, reset, skip-when-detected
- 7 widget tests for `MrzCameraScreen` cover: scanning panel, detected panel, action buttons

---

## Dependencies

### Runtime

| Package | Purpose |
|---|---|
| `flutter_riverpod` | State management + dependency injection |
| `go_router` | Declarative URL-based routing |
| `dmrtd` (git) | ICAO 9303 passport reading (BAC, DG1/DG2/SOD) |
| `flutter_nfc_kit` | Android NFC communication |
| `dart_pcsc` | Desktop PC/SC smart card API |
| `camera` | Camera preview for MRZ scanning |
| `google_mlkit_text_recognition` | ML Kit OCR for MRZ detection |
| `http` | PA Service REST API client |
| `image` | RGBA-to-PNG conversion (JPEG2000 pipeline) |
| `ffi` | dart:ffi support for OpenJPEG native bindings |
| `flutter_svg` | Country flag SVG rendering |
| `equatable` | Value equality for domain entities |
| `logging` | Structured logging (no PII) |
| `wakelock_plus` | Keep screen on during NFC reading |
| `permission_handler` | Runtime camera/NFC permissions |
| `google_mlkit_face_detection` | ML Kit face detection for VIZ capture |
| `tflite_flutter` | TFLite inference for MobileFaceNet face embedding |

### Dev

| Package | Purpose |
|---|---|
| `flutter_test` | Widget + unit testing |
| `flutter_lints` | Lint rules |
| `riverpod_generator` | Provider code generation (available, not actively used) |
| `build_runner` | Code generation runner |
| `mockito` | Test mocking (manual mock pattern, no codegen) |
| `ffigen` | FFI binding generator (available, manual bindings used) |
| `flutter_launcher_icons` | App icon generation |

---

## Testing

**261 tests** across **26 test files** (193 unit + 68 widget).

### Strategy

- **Manual mock pattern**: No mockito code generation (analyzer 7.x incompatibility). Mock classes implement abstract interfaces directly.
- **Riverpod test overrides**: `ProviderContainer` with `overrides` for DI in tests.
- **MethodChannel mocking**: `TestDefaultBinaryMessengerBinding` for platform channel tests.
- **Widget testing**: All 4 screens tested with GoRouter + mock providers.

### Coverage by Layer

| Layer | Test Files | Tests |
|---|---|---|
| Domain entities | 6 | 55 |
| Domain use cases | 5 | 61 |
| Core utils | 2 | 21 |
| Core platform | 2 | 6 |
| Core image | 2 | 18 |
| Core services | 2 | 21 |
| Data sources | 1 | 8 |
| Providers | 3 | 45 |
| Widget (screens) | 4 | 44 |
| **Total** | **26** | **261** |

---

## Build Configurations

### Android

```
applicationId: com.smartcoreinc.eid_reader
minSdk: 24 (flutter_nfc_kit requirement)
NDK: CMake 3.22.1 (OpenJPEG cross-compilation)
Permissions: CAMERA, NFC, INTERNET
Required hardware: android.hardware.nfc (required=true)
```

### Linux

```
CMakeLists.txt: C + CXX languages
OpenJPEG: built as shared library (libopenjp2.so)
Dependencies: libpcsclite-dev (for dart_pcsc)
```

### Windows

```
CMakeLists.txt: C + CXX languages
OpenJPEG: built as shared library (openjp2.dll)
WinSCard: system library (for dart_pcsc)
```

---

## Key Design Decisions

| Decision | Rationale |
|---|---|
| Feature-first architecture | Independent features with clear boundaries; easy to add new features |
| `ComProvider` abstraction | dmrtd's abstraction enables identical passport reading logic across NFC and PC/SC |
| OpenJPEG via C FFI | No pure-Dart JPEG2000 library exists; in-memory streams avoid disk I/O |
| Manual mocks over mockito codegen | Analyzer 7.x incompatibility with mockito's code generator |
| Optional PA verification | Not all deployments have PA Service; graceful degradation is essential |
| BAC-only authentication | Simpler, faster; PACE support is architecturally ready but not needed |
| Platform factory pattern | Compile-time platform detection avoids runtime overhead |
| Memory-only data handling | Security requirement: no PII persistence to disk or database |
| `StateNotifier` over `@riverpod` | Simpler, no code generation dependency; migration path available |
