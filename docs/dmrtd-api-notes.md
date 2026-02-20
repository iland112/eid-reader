# dmrtd Library API Notes

## Source

- **Repository**: https://github.com/ZeroPass/dmrtd.git
- **Branch**: `master`
- **Dependency type**: Git dependency in `pubspec.yaml`

## Key Classes

### DBAKey

Access key derived from MRZ data (document number, date of birth, date of expiry).

```dart
import 'package:dmrtd/dmrtd.dart';

final dbaKey = DBAKey(
  documentNumber,       // String
  dateOfBirth,          // DateTime (not String)
  dateOfExpiry,         // DateTime (not String)
);
```

**Note**: Class name is `DBAKey` (all caps), not `DbaKey`.

### NfcProvider

NFC communication provider for Android.

```dart
final nfc = NfcProvider();
await nfc.connect(iosAlertMessage: 'Hold your phone near the passport');
// ... read passport ...
await nfc.disconnect(iosAlertMessage: 'Reading complete');
```

### Passport

Main class for passport chip communication.

```dart
final passport = Passport(nfcProvider);

// Authentication (try PACE first, then BAC)
final cardAccess = await passport.readEfCardAccess();
await passport.startSessionPACE(dbaKey, cardAccess);  // PACE
await passport.startSession(dbaKey);                    // BAC fallback

// Reading data groups
await passport.readEfCOM();           // EF.COM (data group list)
final dg1 = await passport.readEfDG1();  // DG1 (MRZ data)
final dg2 = await passport.readEfDG2();  // DG2 (face image)
```

### EfDG1 - MRZ Data

```dart
final mrz = dg1.mrz;

mrz.lastName        // String - surname
mrz.firstName       // String - given names
mrz.documentNumber  // String - document number
mrz.nationality     // String - 3-letter country code
mrz.dateOfBirth     // DateTime (not String)
mrz.dateOfExpiry    // DateTime (not String)
mrz.gender          // String - 'M', 'F', or '<'
mrz.country         // String - issuing state
mrz.documentCode    // String - document type (not 'documentType')
```

### EfDG2 - Face Image

```dart
final dg2 = await passport.readEfDG2();
final Uint8List imageBytes = dg2.imageData;  // not 'faceData'
```

**Note**: Image format may be JPEG or JPEG2000 depending on the passport.

### EfSOD - Document Security Object

```dart
// Currently a stub in dmrtd - passive authentication cannot be fully implemented
final sod = await passport.readEfSOD();
```

## Common Pitfalls

| Pitfall | Correct Usage |
|---|---|
| `DbaKey` | Use `DBAKey` (uppercase) |
| `dg2.faceData` | Use `dg2.imageData` |
| `mrz.documentType` | Use `mrz.documentCode` |
| `mrz.dateOfBirth` returns String | It returns `DateTime` - use `_formatYYMMDD()` to convert |
| `DBAKey(docNum, "690806", "940623")` | Dates must be `DateTime` objects, not strings |
| `formatYYMMDD()` from dmrtd | Internal extension, not public API - write your own |

## Date Conversion Helpers

Since dmrtd uses `DateTime` objects but MRZ data is in YYMMDD format:

```dart
// DateTime -> YYMMDD String
String formatYYMMDD(DateTime date) {
  final y = (date.year % 100).toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y$m$d';
}

// YYMMDD String -> DateTime
DateTime parseYYMMDD(String yymmdd) {
  final yy = int.parse(yymmdd.substring(0, 2));
  final mm = int.parse(yymmdd.substring(2, 4));
  final dd = int.parse(yymmdd.substring(4, 6));
  // ICAO 9303 century rule
  final year = yy < 70 ? 2000 + yy : 1900 + yy;
  return DateTime(year, mm, dd);
}
```

## Authentication Flow

```
1. Connect NFC
2. Read EfCardAccess
3. Try PACE authentication (startSessionPACE)
   |-- Success -> Continue with PACE
   |-- Failure -> Fall back to BAC (startSession)
4. Read EF.COM
5. Read DG1 (MRZ biographical data)
6. Read DG2 (face image) - optional, may fail
7. Disconnect NFC
```
