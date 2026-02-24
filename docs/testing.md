# Testing Guide

## Overview

- **Total tests**: 476
- **Test files**: 37 (28 unit + 9 widget)
- **Framework**: `flutter_test`
- **Mock strategy**: Manual mocks (no mockito codegen)
- **CI command**: `flutter test`

## Why Manual Mocks?

mockito 5.4.x code generation (`@GenerateMocks`) is incompatible with
analyzer 7.x due to `InterfaceElement` / `InterfaceElementImpl` type errors
in mockito's builder. Instead, we use hand-written mock classes that implement
the abstract interfaces directly.

## Test Files

### Core

#### `test/core/utils/mrz_utils_test.dart` (17 tests)

Tests ICAO 9303 MRZ check digit calculation and date display formatting.

| Test | Description |
|---|---|
| All-zero input | Returns `'0'` |
| ICAO 9303 example | `'L898902C'` -> `'3'` |
| Date string | `'690806'` -> `'1'` |
| Filler characters | `'<'` treated as `0` |
| Letters mapping | A=10, B=11, ..., Z=35 |
| Full MRZ line | Composite check digit |
| Empty string | Returns `'0'` |
| Single digit | Identity check |
| Mixed alphanumeric | Correct weight cycling |

#### `test/core/platform/secure_screen_service_test.dart` (3 tests)

Tests `SecureScreenServiceImpl` via MethodChannel mock.

| Test | Description |
|---|---|
| enableSecureMode | Invokes `enableSecureMode` method on channel |
| disableSecureMode | Invokes `disableSecureMode` method on channel |
| Channel name | Verifies `com.smartcoreinc.eid_reader/secure_screen` |

#### `test/core/image/jpeg2000_detector_test.dart` (15 tests)

Tests JP2/J2K/JPEG magic byte detection.

| Group | Tests |
|---|---|
| detectImageFormat | JPEG SOI, JPEG Exif, JP2 container, J2K codestream, empty, short, PNG, random |
| isJpeg | true for JPEG, false for JP2, false for unknown |
| isJpeg2000 | true for JP2 container, true for J2K codestream, false for JPEG, false for unknown |

#### `test/core/image/image_utils_test.dart` (3 tests)

Tests face image decode routing.

| Test | Description |
|---|---|
| JPEG passthrough | Returns JPEG data unchanged |
| Unknown format | Returns null for unrecognized format |
| Empty data | Returns null for empty input |

#### `test/core/platform/pcsc_service_stub_test.dart` (3 tests)

Tests the Android stub implementation of PcscService.

| Test | Description |
|---|---|
| checkAvailability | Returns `PcscStatus.notSupported` |
| listReaders | Returns empty list |
| Multiple calls | Consistent results across repeated calls |

#### `test/core/services/image_quality_analyzer_test.dart` (13 tests)

Tests `DefaultImageQualityAnalyzer` with synthetic test images.

| Group | Tests |
|---|---|
| Blur detection | Sharp image (varied pixels) vs uniform image (all same color), Laplacian variance thresholds |
| Glare detection | All-white (high glare), all-black (no glare), mixed brightness |
| Saturation analysis | Uniform color (low std dev), rainbow image (high std dev for hologram detection) |
| Contrast | High contrast (black/white), low contrast (uniform gray) |
| Overall | Score computation, quality level classification, issue detection for blur/glare |

#### `test/core/services/face_embedding_service_test.dart` (8 tests)

Tests `cosineSimilarity()` function (pure math, no TFLite model needed).

| Test | Description |
|---|---|
| Identical vectors | Returns 1.0 |
| Opposite vectors | Returns -1.0 |
| Orthogonal vectors | Returns 0.0 |
| Empty vectors | Returns 0.0 |
| Zero vectors | Returns 0.0 (division by zero guard) |
| Scaled vectors | Returns 1.0 (direction-only) |
| Different lengths | Returns 0.0 |
| High-dimensional | Correct computation with 192D vectors |

#### `test/core/utils/country_code_utils_test.dart` (12 tests)

Tests ISO 3166-1 alpha-3 to alpha-2 conversion and flag asset path generation.

| Group | Tests |
|---|---|
| alpha3ToAlpha2 | KOR→kr, USA→us, GBR→gb, DEU→de, JPN→jp, case-insensitive, unknown→null, empty→null, D<<→de |
| flagAssetPath | KOR→assets/svg/kr.svg, USA→assets/svg/us.svg, unknown→null |

### App

#### `test/app/device_capability_provider_test.dart` (6 tests)

Tests `ChipReaderCapability` enum and `hasChipReader()` utility function.

| Test | Description |
|---|---|
| hasChipReader nfcEnabled | Returns true |
| hasChipReader pcscAvailable | Returns true |
| hasChipReader nfcDisabled | Returns false |
| hasChipReader none | Returns false |
| Enum count | 4 values |
| Enum values | nfcEnabled, nfcDisabled, pcscAvailable, none |

### Feature: MRZ Input

#### `test/features/mrz_input/domain/entities/mrz_data_test.dart` (7 tests)

| Test | Description |
|---|---|
| Equality | Two identical `MrzData` instances are equal |
| Inequality | Different field values are not equal |
| Props | Equatable props list is correct |
| Optional fields | New fields (surname, givenNames, nationality, etc.) |
| withVizCapture | Preserves all fields including optional ones |
| Raw MRZ lines | mrzLine1/mrzLine2 stored and compared |
| Equality with all fields | Full MrzData equality including optional fields |

#### `test/features/mrz_input/domain/entities/mrz_data_conversion_test.dart` (5 tests)

Tests `MrzData.toPassportData()` conversion for OCR-only mode.

| Test | Description |
|---|---|
| Required fields | Maps documentNumber, dateOfBirth, dateOfExpiry correctly |
| authProtocol OCR | Sets authProtocol to 'OCR', isOcrOnly true |
| Null optional fields | Maps null surname/givenNames/nationality/sex to empty strings |
| vizCaptureResult mapping | Maps vizFaceBytes and vizImageQuality from VizCaptureResult |
| Chip-only defaults | passiveAuthValid false, faceImageBytes null, debugTimings empty |

#### `test/features/mrz_input/domain/entities/viz_capture_result_test.dart` (4 tests)

| Test | Description |
|---|---|
| Face bytes storage | Stores and retrieves vizFaceImageBytes |
| Bounding box | Stores face bounding box coordinates |
| Quality metrics | Stores quality metrics with correct levels |
| Issues propagation | Quality issues accessible from capture result |

#### `test/features/mrz_input/domain/usecases/validate_mrz_test.dart` (23 tests)

| Group | Tests |
|---|---|
| Document number validation | Min/max length, empty, special chars, alphanumeric |
| Date validation | Valid YYMMDD, invalid month/day, wrong length, non-numeric |
| Full MRZ validation | Valid complete input, each field invalid individually |
| Edge cases | Boundary dates (010101, 991231), filler chars in doc number |

#### `test/features/mrz_input/domain/usecases/mrz_ocr_corrector_test.dart` (20 tests)

Tests position-aware OCR character correction for MRZ lines.

| Group | Tests |
|---|---|
| Line 1 correction | Alpha context: 0→O, 1→I, 8→B, 5→S, 2→Z, 6→G, 7→T; preserves fillers and valid input |
| Line 2 correction | Check digit positions (digit-only), DOB/DOE positions, nationality (alpha-only), sex position, alphanumeric passthrough |

#### `test/core/utils/icao_codes_test.dart` (10 tests)

Tests ICAO state code validation and single-char OCR correction.

| Test | Description |
|---|---|
| Valid codes | USA, KOR, GBR, JPN, DEU recognized |
| Invalid codes | XYZ, ZZZ, ABC rejected |
| Case insensitive | usa, Kor accepted |
| UTO test code | Recognized as valid |
| Single-char correction | G8R → GBR, K0R → KOR |
| Uncorrectable | ZZZ returns null |
| Unchanged valid | USA returns USA |
| Ambiguous | Multiple corrections → null |
| Wrong length | Too short/long → null |

#### `test/features/mrz_input/domain/usecases/parse_mrz_from_text_test.dart` (32 tests)

Tests ICAO 9303 TD3 MRZ parsing from raw OCR text.

| Test | Description |
|---|---|
| Valid TD3 MRZ | Parses 2-line MRZ and extracts correct fields |
| OCR noise | Finds MRZ lines among random surrounding text |
| Empty text | Returns null |
| Single line | Returns null (needs 2 consecutive lines) |
| Non-MRZ text | Returns null |
| Bad doc check digit | Returns null on incorrect check digit |
| Bad DOB check digit | Returns null on incorrect check digit |
| Bad DOE check digit | Returns null on incorrect check digit |
| Trailing fillers | Trims `<` from document number |
| No fillers | Preserves full document number |
| Guillemet `«` | Handles `«` as `<` (OCR variant) |
| Blank lines | Collapses blank lines between MRZ (OCR artifact) |
| Non-first position | Finds MRZ lines not at start of text |
| Non-digit check | Returns null for letter in check digit position |
| Line 1 bad prefix | Returns null when line 1 doesn't start with P |
| Short lines | Returns null for lines < 44 characters |

#### `test/features/mrz_input/presentation/providers/mrz_input_provider_test.dart` (15 tests)

| Test | Description |
|---|---|
| Initial state | All fields empty, not valid |
| setDocumentNumber | Updates field, re-validates |
| setDateOfBirth | Updates field, re-validates |
| setDateOfExpiry | Updates field, re-validates |
| Validation | Valid when all three fields are valid |
| copyWith | Preserves unchanged fields |
| toMrzData | Converts to `MrzData` entity |
| Reset | Returns to initial state |
| Partial input | Invalid until all fields present |
| Provider type | Correct provider type check |
| Multiple updates | Sequential updates work correctly |

#### `test/features/mrz_input/presentation/providers/mrz_camera_provider_test.dart` (12 tests)

Tests MRZ camera scanning state management with mock `TextRecognitionService` and multi-frame consensus.

| Test | Description |
|---|---|
| Default state | isProcessing=false, detectedMrz=null, errorMessage=null |
| copyWith | Preserves unchanged fields |
| Initial state | Notifier starts with default state |
| processText valid | Detects MRZ and updates detectedMrz |
| processText invalid | Does not update state for non-MRZ text |
| reset | Clears detected MRZ and resets state |
| Provider type | Correct provider type with override |
| processImage detects | ML Kit OCR → MRZ detection (consensusCount=1) |
| processImage no MRZ | Returns empty state when no MRZ found |
| processImage skip | Skips processing when already detected |
| Consensus N frames | Requires N matching frames before confirming |
| Reset clears consensus | Reset clears accumulated candidates |

### Feature: Passport Reader

#### `test/features/passport_reader/domain/entities/passport_data_test.dart` (14 tests)

| Test | Description |
|---|---|
| Default values | `faceImageBytes` null, `authProtocol` is `'BAC'` |
| fullName | `'$givenNames $surname'` format |
| Equality | Ignores `faceImageBytes` (excluded from Equatable props) |
| Inequality | Different field values are not equal |
| paVerificationResult default | Defaults to null |
| paVerificationResult equality | Different PA results are not equal |
| copyWith preserves fields | Unchanged fields preserved on copy |
| copyWith PA result | Updates passiveAuthValid and paVerificationResult |
| copyWith all fields | All fields updatable |
| authProtocol equality | BAC != PACE |
| const constructor | Compiles with const |
| faceImageBytes default | Defaults to null |
| Equality same values | Two identical instances are equal |

#### `test/features/passport_reader/domain/entities/pa_verification_result_test.dart` (11 tests)

| Test | Description |
|---|---|
| isValid VALID | Returns true for 'VALID' status |
| isValid INVALID | Returns false for 'INVALID' status |
| isValid ERROR | Returns false for 'ERROR' status |
| fromJson VALID | Parses full VALID response with all nested objects |
| fromJson INVALID | Parses INVALID response with cert chain failure |
| fromJson error response | Handles `success: false` with error message |
| fromJson missing nested | Handles missing nested objects gracefully |
| error factory | Creates ERROR result with error message |
| Equality same | Two identical instances are equal |
| Equality different | Different values are not equal |

#### `test/features/passport_reader/domain/entities/face_comparison_result_test.dart` (8 tests)

| Test | Description |
|---|---|
| isMatch above threshold | Returns true when similarity >= threshold |
| isMatch below threshold | Returns false when similarity < threshold |
| High confidence | >= 0.65 similarity |
| Medium confidence | 0.50-0.65 similarity |
| Low confidence | 0.35-0.50 similarity |
| Unreliable | < 0.35 similarity |
| Equality same | Equatable comparison |
| Equality different | Different values are not equal |

#### `test/features/passport_reader/domain/entities/image_quality_metrics_test.dart` (9 tests)

| Test | Description |
|---|---|
| Good quality | Overall score >= 0.7 |
| Acceptable quality | Overall score 0.5-0.7 |
| Poor quality | Overall score 0.3-0.5 |
| Unusable quality | Overall score < 0.3 |
| Boundary good | Exact 0.7 → good |
| Boundary acceptable | Exact 0.5 → acceptable |
| Boundary poor | Exact 0.3 → poor |
| Equality | Equatable comparison |
| Default issues | Empty issues list by default |

> Note: Some test tables may not list every individual test case (e.g. when tests
> were added across sessions). The counts in parentheses are the authoritative numbers.

#### `test/features/passport_reader/domain/entities/mrz_field_comparison_test.dart` (8 tests)

Tests `MrzFieldMatch` and `MrzFieldComparisonResult` entities.

| Test | Description |
|---|---|
| Match construction | Creates matching field with correct values |
| Mismatch construction | Creates mismatched field |
| allMatch true | All fields matching → true |
| allMatch false | Any field mismatched → false |
| matchCount | Counts matching fields correctly |
| totalFields | Counts total fields |
| Equality | Equatable comparison |
| Empty result | Empty field list → allMatch true, count 0 |

#### `test/features/passport_reader/domain/usecases/capture_viz_face_test.dart` (9 tests)

Tests `CaptureVizFace` use case with mocked face detection service and contrast enhancement retry.

| Test | Description |
|---|---|
| No faces detected | Returns null |
| Face detected | Returns VizCaptureResult with cropped face |
| Largest face selection | Picks largest face from multiple detections |
| Quality metrics | Result includes quality analysis |
| Face at boundary | Handles faces at image edge (clamp to bounds) |
| 20% padding | Crop includes padding around face |
| Quality issues | Issues propagated to result |
| Retry with contrast | Retries with 1.5x contrast enhancement on first failure |
| No retry on success | Skips retry when first attempt succeeds (1 call) |
| Both attempts fail | Returns null after 2 failed attempts |

#### `test/features/passport_reader/domain/usecases/verify_viz_test.dart` (15 tests)

Tests `VerifyViz` use case for VIZ-chip cross-verification and field-by-field comparison.

| Test | Description |
|---|---|
| MRZ fields match | All fields match → vizMrzFieldsMatch=true |
| MRZ fields mismatch | Different doc number → vizMrzFieldsMatch=false |
| Date format conversion | YYYYMMDD chip dates compared against YYMMDD OCR dates |
| Face match high | Similarity >= 0.65 → high confidence |
| Face match medium | Similarity 0.50-0.65 → medium confidence |
| Face mismatch | Similarity < 0.35 → unreliable |
| Quality threshold adjustment | Poor quality reduces match threshold by 0.15 |
| Null chip face | Skips face comparison when DG2 face is null |
| Null VIZ face | Skips face comparison when VIZ face is null |
| Embedding zeroing | Embeddings zeroed in finally block |
| Field comparison all match | Per-field comparison with all fields matching |
| Field comparison mismatch | Per-field mismatch detection |
| Field comparison optional | Only compares fields that OCR extracted |
| Field comparison names | Case-insensitive name comparison with truncation support |
| Field comparison dates | YYMMDD↔YYYYMMDD date comparison |
| Field comparison sex | Sex field comparison |

#### `test/features/passport_reader/data/datasources/http_pa_service_test.dart` (8 tests)

| Test | Description |
|---|---|
| Request body | Sends correct Base64 encoded SOD/DG1/DG2 + metadata |
| Optional fields | Omits issuingCountry/documentNumber when null |
| VALID response | Parses successful PA verification response |
| API error | Handles `success: false` error response |
| HTTP error | Handles non-200 status codes |
| Network error | Handles ClientException with error result |
| URL construction | Sends request to correct `/api/pa/verify` URL |
| Content-Type | Sets `application/json` header |

#### `test/features/passport_reader/presentation/providers/passport_reader_provider_test.dart` (18 tests)

| Group | Tests |
|---|---|
| PassportReaderState | Default values, copyWith, errorMessage reset |
| ReadingStep | 10 enum values (idle, connecting, authenticating, readingDg1, readingDg2, readingSod, verifyingPa, verifyingViz, done, error) |
| PassportReaderNotifier | Initial state, reset |
| With mock datasource | Success flow, TagLost error, auth failure, timeout, generic error, reset after read |
| With PA service | PA success → passiveAuthValid=true, PA INVALID → false, PA failure → graceful, skips PA when SOD empty |
| Without PA service | Works without PA service (null) |

### Widget: MRZ Input Screen

#### `test/features/mrz_input/presentation/screens/mrz_input_screen_test.dart` (14 tests)

| Test | Description |
|---|---|
| App bar title | Renders 'eID Reader' |
| Headline text | Renders 'Enter Passport MRZ Data' |
| Three text fields | Document Number, Date of Birth, Date of Expiry |
| Platform scan button | Desktop: 'Read with Card Reader' + USB icon; Mobile: 'Scan Passport' + NFC icon |
| Validation errors | Shows required field errors on empty submit |
| Date format error | Shows 'Format: YYMMDD' for partial input |
| Navigation | Navigates to `/scan` with valid MrzData |
| Platform-appropriate button | Desktop: no camera scan; Mobile: NFC + camera scan buttons |
| Credit card icon | Renders instruction card icon |
| Field hints | Renders hint texts (e.g. 'e.g. M12345678') |
| OCR-only banner | Shows OCR-only info banner when no chip reader |
| NFC disabled banner | Shows NFC disabled warning when NFC hardware present but off |
| View Passport Info button | Shows OCR-only button when no chip reader |
| Hides Scan Passport | Hides chip reader button when no reader available |

### Widget: MRZ Camera Screen

#### `test/features/mrz_input/presentation/screens/mrz_camera_screen_test.dart` (9 tests)

Tests the MRZ camera scanning UI states using `MrzCameraNotifier` with mock
`TextRecognitionService`. Uses extracted bottom panel widget for hardware-free testing.

| Test | Description |
|---|---|
| Scanning instruction | Shows positioning instruction text |
| No progress idle | No progress indicator in idle state |
| MRZ Detected panel | Shows 'MRZ Detected' with check icon |
| Detected data | Shows document number, DOB, DOE values |
| Action buttons | Shows 'Use This Data' and 'Rescan' buttons |
| Rescan button | Clears detected MRZ, returns to scanning view |
| No buttons idle | Hides action buttons when no MRZ detected |
| MRZ line preview | Shows raw MRZ line 1 and line 2 in monospace card |
| Extended fields | Shows name, nationality, sex in detected panel |

### Widget: NFC Scan Screen

#### `test/features/passport_reader/presentation/screens/nfc_scan_screen_test.dart` (11 tests)

Uses GoRouter for named route navigation and `Completer`-based mock for
blocking "in progress" state tests. Updated for v0.7 redesign with pulse
animation, step indicator, and positioning guide.

| Test | Description |
|---|---|
| App bar title | Renders 'Scanning Passport' |
| Contactless icon | Shows contactless icon during reading |
| Step indicator | Shows Connect, Auth, Read, Verify step labels |
| Positioning guide | Shows 'Place phone flat on the passport data page' |
| TagLost error | Error icon + 'Connection lost...' message |
| Retry button | Shows retry button with count on error |
| Auth error | 'Authentication failed...' message |
| Timeout error | 'Reading timed out...' message |
| Generic error | 'Could not read passport...' message |
| Success navigation | Navigates to `/passport-detail` on success |
| Retry + navigation | Retry -> success -> navigates |

### Widget: Passport Detail Screen

#### `test/features/passport_display/presentation/screens/passport_detail_screen_test.dart` (22 tests)

Uses `Navigator.pushReplacement` to test dispose behavior. Updated for v0.7
card-based layout with `PassportHeaderCard` + `InfoSectionCard` widgets.

| Test | Description |
|---|---|
| App bar title | Renders 'Passport Details' |
| Personal info | Name, nationality, DOB, sex (header card + info section) |
| Document details | Document number, issuing state, expiry, type |
| Security status | Passive/active auth, protocol |
| Pending badge | Orange 'Verification Pending' when not verified |
| Verified badge | Green 'Document Verified' when verified |
| Verified data | Shows PACE, 'Verified' for both auth types |
| Person icon | Fallback icon when no face image |
| Failed auth | Shows 'Failed' for `activeAuthValid: false` |
| Buffer zeroing | Zeroes face bytes on dispose |
| Section headers | All 3 section headers render |
| Field labels | All 11 field labels render |
| No PA details | Hides PA section when no PA result |
| PA details section | Shows 'PA Verification Details' header with PA result |
| PA cert chain details | Shows cert chain, SOD sig, DG hash, timing |
| PA error message | Shows error message for failed PA verification |
| OCR title | Renders 'Passport Info (OCR)' for OCR-only data |
| OCR badge | Shows OCR badge with document_scanner icon |
| OCR personal/document | Renders Personal Information and Document Details sections |
| OCR hides security | Hides Security Status section in OCR mode |
| OCR hides PA | Hides PA Verification Details in OCR mode |
| OCR badge description | Shows 'MRZ only' description text |

### Widget: VIZ Verification Card

#### `test/features/passport_display/presentation/widgets/viz_verification_card_test.dart` (8 tests)

Tests `VizVerificationCard` widget with per-field MRZ comparison display and boolean fallback.

| Test | Description |
|---|---|
| Per-field results | Shows field names and summary (e.g. '1/2 match') |
| All match summary | Shows all-match count and check circle icon |
| Mismatch values | Shows OCR value != chip value for mismatched fields |
| Boolean fallback true | 'MRZ fields match chip data' when no fieldComparison |
| Boolean fallback false | 'MRZ fields mismatch' when no fieldComparison |
| Card title | Shows 'VIZ Verification' with compare icon |
| Check icons | Shows check icon for matching fields |
| Close icons | Shows close icon for mismatching fields |

## Running Tests

```bash
# All tests
flutter test

# Single file
flutter test test/core/utils/mrz_utils_test.dart

# With coverage
flutter test --coverage

# Verbose output
flutter test --reporter expanded
```

## Adding New Tests

1. Create test file mirroring the `lib/` structure under `test/`
2. Use manual mocks (implement the abstract interface directly)
3. For providers, use `ProviderContainer` for DI
4. For MethodChannel, use `TestDefaultBinaryMessengerBinding`
5. For widget tests with Riverpod, wrap in `ProviderScope` with overrides
6. For GoRouter navigation tests, use `MaterialApp.router` with `GoRouter`
7. For dispose testing, use `Navigator.pushReplacement` within same `ProviderScope`
8. Run `flutter test` to verify all pass
9. Run `flutter analyze` to check for lint issues

## Known Issues

- **Riverpod `ref` in `dispose()`**: Cannot use `ref.read()` in `dispose()` of
  `ConsumerStatefulWidget` (throws `Bad state: Cannot use "ref" after disposed`).
  Fix: cache the notifier in `initState` and use `Future.microtask` with
  `mounted` check in `dispose()`.
- **Riverpod provider modification during tree building**: Cannot call
  `notifier.setState()` during `dispose()`/`unmount` (throws
  `Tried to modify a provider while the widget tree was building`).
  Fix: schedule via `Future.microtask`.
