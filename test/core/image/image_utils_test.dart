import 'dart:typed_data';

import 'package:eid_reader/core/image/image_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('decodeFaceImage', () {
    test('passes through JPEG data unchanged', () {
      final jpegData = Uint8List.fromList([
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46,
        0x49, 0x46, 0x00, 0x01, // JFIF header
      ]);

      final result = decodeFaceImage(jpegData);
      expect(result, equals(jpegData));
    });

    test('returns null for unknown format', () {
      final unknownData = Uint8List.fromList([
        0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC,
      ]);

      final result = decodeFaceImage(unknownData);
      expect(result, isNull);
    });

    test('returns null for empty data', () {
      final emptyData = Uint8List(0);
      final result = decodeFaceImage(emptyData);
      expect(result, isNull);
    });
  });
}
