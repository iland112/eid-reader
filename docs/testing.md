# Testing Guide

## Overview

- **Total tests**: 71
- **Test files**: 7
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

### Feature: Passport Reader

#### `test/features/passport_reader/domain/entities/passport_data_test.dart` (8 tests)

| Test | Description |
|---|---|
| Default values | `faceImageBytes` null, `authProtocol` is `'unknown'` |
| fullName | `'$givenNames $surname'` format |
| Equality | Ignores `faceImageBytes` (excluded from Equatable props) |
| Inequality | Different field values are not equal |
| Props count | Correct number of props |
| copyWith | Works for all fields |
| const constructor | Compiles with const |
| All fields | Non-default values round-trip correctly |

#### `test/features/passport_reader/presentation/providers/passport_reader_provider_test.dart` (20 tests)

| Group | Tests |
|---|---|
| PassportReaderState | Default values, copyWith, errorMessage reset |
| ReadingStep | 7 enum values (idle, connecting, authenticating, readingDg1, readingDg2, done, error) |
| PassportReaderNotifier | Initial state, reset |
| With mock datasource | Success flow, TagLost error, auth failure, timeout, generic error, reset after read |

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
5. Run `flutter test` to verify all pass
6. Run `flutter analyze` to check for lint issues
