import 'dart:typed_data';

import 'package:eid_reader/core/image/jpeg2000_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('detectImageFormat', () {
    test('detects JPEG from SOI marker', () {
      // FF D8 FF E0 (JFIF)
      final data = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
      expect(detectImageFormat(data), ImageFormat.jpeg);
    });

    test('detects JPEG with Exif marker', () {
      // FF D8 FF E1 (Exif)
      final data = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE1, 0x00, 0x10]);
      expect(detectImageFormat(data), ImageFormat.jpeg);
    });

    test('detects JP2 container format', () {
      // JP2 signature box: 00 00 00 0C 6A 50 20 20
      final data = Uint8List.fromList([
        0x00, 0x00, 0x00, 0x0C, 0x6A, 0x50, 0x20, 0x20,
        0x0D, 0x0A, 0x87, 0x0A, // followed by more data
      ]);
      expect(detectImageFormat(data), ImageFormat.jp2);
    });

    test('detects J2K codestream format', () {
      // SOC + SIZ markers: FF 4F FF 51
      final data = Uint8List.fromList([
        0xFF, 0x4F, 0xFF, 0x51, 0x00, 0x2F, 0x00, 0x00,
      ]);
      expect(detectImageFormat(data), ImageFormat.j2k);
    });

    test('returns unknown for empty data', () {
      final data = Uint8List(0);
      expect(detectImageFormat(data), ImageFormat.unknown);
    });

    test('returns unknown for data shorter than 4 bytes', () {
      final data = Uint8List.fromList([0xFF, 0xD8]);
      expect(detectImageFormat(data), ImageFormat.unknown);
    });

    test('returns unknown for PNG data', () {
      // PNG magic: 89 50 4E 47
      final data = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      ]);
      expect(detectImageFormat(data), ImageFormat.unknown);
    });

    test('returns unknown for random data', () {
      final data = Uint8List.fromList([0x12, 0x34, 0x56, 0x78, 0x9A]);
      expect(detectImageFormat(data), ImageFormat.unknown);
    });
  });

  group('isJpeg', () {
    test('returns true for JPEG', () {
      final data = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]);
      expect(isJpeg(data), isTrue);
    });

    test('returns false for JP2', () {
      final data = Uint8List.fromList([
        0x00, 0x00, 0x00, 0x0C, 0x6A, 0x50, 0x20, 0x20,
      ]);
      expect(isJpeg(data), isFalse);
    });

    test('returns false for unknown', () {
      final data = Uint8List.fromList([0x00, 0x00, 0x00, 0x00]);
      expect(isJpeg(data), isFalse);
    });
  });

  group('isJpeg2000', () {
    test('returns true for JP2 container', () {
      final data = Uint8List.fromList([
        0x00, 0x00, 0x00, 0x0C, 0x6A, 0x50, 0x20, 0x20,
      ]);
      expect(isJpeg2000(data), isTrue);
    });

    test('returns true for J2K codestream', () {
      final data = Uint8List.fromList([0xFF, 0x4F, 0xFF, 0x51]);
      expect(isJpeg2000(data), isTrue);
    });

    test('returns false for JPEG', () {
      final data = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]);
      expect(isJpeg2000(data), isFalse);
    });

    test('returns false for unknown', () {
      final data = Uint8List.fromList([0x00, 0x00, 0x00, 0x00]);
      expect(isJpeg2000(data), isFalse);
    });
  });
}
