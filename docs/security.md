# Security Architecture

## Principles

eID Reader handles personal identity data (PII) including names, document numbers,
dates, nationality, and biometric face images. The following security principles apply:

1. **Memory-only data** - Passport data is never persisted to disk or database
2. **No network transmission** - v1 is fully offline; no data leaves the device
3. **No PII logging** - Never log names, document numbers, dates, or biometric data
4. **Screen capture prevention** - FLAG_SECURE on sensitive screens
5. **Biometric buffer clearing** - Zero out `Uint8List` buffers on navigation away

## Implemented Measures

### FLAG_SECURE (Android Screen Capture Prevention)

Prevents screenshots and screen recording on the passport detail screen.

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

**Lifecycle:**
- `initState()` -> `enableSecureMode()` (adds FLAG_SECURE)
- `dispose()` -> `disableSecureMode()` (clears FLAG_SECURE)

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
  _secureScreenService.disableSecureMode();
  super.dispose();
}
```

This prevents residual biometric data from remaining in memory after the user
navigates away from the screen.

### NFC Authentication Security

The passport reading flow uses ICAO 9303 compliant authentication:

1. **PACE first** - Password Authenticated Connection Establishment (stronger)
2. **BAC fallback** - Basic Access Control (if PACE not supported)

Both require the MRZ data (document number, date of birth, date of expiry) as
the shared secret, ensuring only someone with physical access to the passport's
data page can read the chip.

## Not Yet Implemented

| Measure | Description |
|---|---|
| Passive Authentication | Verify chip data integrity via EfSOD digital signature (blocked: dmrtd `EfSOD` is a stub) |
| Active Authentication | Verify chip is genuine, not cloned (low priority, many passports don't support AA) |
| Certificate pinning | Not needed in v1 (no network calls) |
| Root/jailbreak detection | Consider for future versions |
| Memory encryption | Dart GC handles deallocation; explicit zeroing is the current mitigation |

## Testing

Security features are tested in:
- `test/core/platform/secure_screen_service_test.dart` - MethodChannel mock verification
- `test/features/passport_reader/presentation/providers/passport_reader_provider_test.dart` - Error state handling
