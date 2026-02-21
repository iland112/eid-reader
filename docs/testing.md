# Testing Guide

## Overview

- **Total tests**: 172
- **Test files**: 16 (12 unit + 4 widget)
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

#### `test/core/utils/mrz_utils_test.dart` (9 tests)

Tests ICAO 9303 MRZ check digit calculation with weights `[7, 3, 1]`.

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

### Feature: MRZ Input

#### `test/features/mrz_input/domain/entities/mrz_data_test.dart` (3 tests)

| Test | Description |
|---|---|
| Equality | Two identical `MrzData` instances are equal |
| Inequality | Different field values are not equal |
| Props | Equatable props list is correct |

#### `test/features/mrz_input/domain/usecases/validate_mrz_test.dart` (17 tests)

| Group | Tests |
|---|---|
| Document number validation | Min/max length, empty, special chars, alphanumeric |
| Date validation | Valid YYMMDD, invalid month/day, wrong length, non-numeric |
| Full MRZ validation | Valid complete input, each field invalid individually |
| Edge cases | Boundary dates (010101, 991231), filler chars in doc number |

#### `test/features/mrz_input/domain/usecases/parse_mrz_from_text_test.dart` (16 tests)

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

#### `test/features/mrz_input/presentation/providers/mrz_input_provider_test.dart` (11 tests)

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

#### `test/features/mrz_input/presentation/providers/mrz_camera_provider_test.dart` (10 tests)

Tests MRZ camera scanning state management with mock `TextRecognitionService`.

| Test | Description |
|---|---|
| Default state | isProcessing=false, detectedMrz=null, errorMessage=null |
| copyWith | Preserves unchanged fields |
| Initial state | Notifier starts with default state |
| processText valid | Detects MRZ and updates detectedMrz |
| processText invalid | Does not update state for non-MRZ text |
| reset | Clears detected MRZ and resets state |
| Provider type | Correct provider type with override |
| processImage detects | ML Kit OCR → MRZ detection pipeline |
| processImage no MRZ | Returns empty state when no MRZ found |
| processImage skip | Skips processing when already detected |

### Feature: Passport Reader

#### `test/features/passport_reader/domain/entities/passport_data_test.dart` (13 tests)

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

#### `test/features/passport_reader/domain/entities/pa_verification_result_test.dart` (10 tests)

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

#### `test/features/passport_reader/presentation/providers/passport_reader_provider_test.dart` (24 tests)

| Group | Tests |
|---|---|
| PassportReaderState | Default values, copyWith, errorMessage reset |
| ReadingStep | 9 enum values (idle, connecting, authenticating, readingDg1, readingDg2, readingSod, verifyingPa, done, error) |
| PassportReaderNotifier | Initial state, reset |
| With mock datasource | Success flow, TagLost error, auth failure, timeout, generic error, reset after read |
| With PA service | PA success → passiveAuthValid=true, PA INVALID → false, PA failure → graceful, skips PA when SOD empty |
| Without PA service | Works without PA service (null) |

### Widget: MRZ Input Screen

#### `test/features/mrz_input/presentation/screens/mrz_input_screen_test.dart` (10 tests)

| Test | Description |
|---|---|
| App bar title | Renders 'eID Reader' |
| Headline text | Renders 'Enter Passport MRZ Data' |
| Three text fields | Document Number, Date of Birth, Date of Expiry |
| Read Passport button | Button with NFC icon |
| Validation errors | Shows required field errors on empty submit |
| Date format error | Shows 'Format: YYMMDD' for partial input |
| Navigation | Navigates to `/nfc-scan` with valid MrzData |
| Scan MRZ button | Renders 'Scan MRZ' button with camera icon |
| Camera navigation | Navigates to `/mrz-camera` on Scan MRZ tap |
| Field hints | Renders hint texts (e.g. 'e.g. M12345678') |

### Widget: MRZ Camera Screen

#### `test/features/mrz_input/presentation/screens/mrz_camera_screen_test.dart` (7 tests)

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

### Widget: NFC Scan Screen

#### `test/features/passport_reader/presentation/screens/nfc_scan_screen_test.dart` (11 tests)

Uses GoRouter for named route navigation and `Completer`-based mock for
blocking "in progress" state tests.

| Test | Description |
|---|---|
| App bar title | Renders 'Reading Passport' |
| NFC icon | Shows NFC icon during reading |
| Progress indicator | Shows `LinearProgressIndicator` during reading |
| TagLost error | Error icon + 'Connection lost...' message |
| Try Again button | Shows retry button on error |
| No progress on error | Hides progress indicator on error |
| Auth error | 'Authentication failed...' message |
| Timeout error | 'Reading timed out...' message |
| Generic error | 'Could not read passport...' message |
| Success navigation | Navigates to `/passport-detail` on success |
| Retry + navigation | Try Again -> success -> navigates |

### Widget: Passport Detail Screen

#### `test/features/passport_display/presentation/screens/passport_detail_screen_test.dart` (18 tests)

Uses `MockSecureScreenService` to verify FLAG_SECURE calls and
`Navigator.pushReplacement` to test dispose behavior.

| Test | Description |
|---|---|
| App bar title | Renders 'Passport Details' |
| Personal info | Name, nationality, DOB, sex |
| Document info | Document number, issuing state, expiry, type |
| Security status | Passive/active auth, protocol |
| Pending badge | Orange 'Verification Pending' when not verified |
| Verified badge | Green 'Document Verified' when verified |
| Verified data | Shows PACE, 'Verified' for both auth types |
| Person icon | Fallback icon when no face image |
| Failed auth | Shows 'Failed' for `activeAuthValid: false` |
| Secure mode on | Calls `enableSecureMode()` on init |
| Dispose cleanup | Calls `disableSecureMode()` + zeroes face buffer |
| Section headers | All 3 section headers render |
| Field labels | All 11 field labels render |
| No PA details | Hides PA section when no PA result |
| PA details section | Shows 'PA Verification Details' header with PA result |
| PA cert chain details | Shows cert chain, SOD sig, DG hash, timing |
| PA error message | Shows error message for failed PA verification |

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
