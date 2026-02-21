import 'dart:typed_data';

import 'openjpeg_ffi.dart';

/// High-level JPEG 2000 decoder using OpenJPEG via FFI.
///
/// Converts JPEG 2000 image data (JP2 or J2K) to PNG format
/// suitable for Flutter's `Image.memory()`.
///
/// Security: All native buffers are zeroed and freed after decoding.
class Jpeg2000Decoder {
  Jpeg2000Decoder._();

  /// Decodes JPEG 2000 data to PNG bytes.
  ///
  /// Throws [Jpeg2000DecodeException] if decoding fails.
  static Uint8List decodeToPng(Uint8List jp2Data) {
    return OpenjpegFfi.decodeJpeg2000ToPng(jp2Data);
  }
}

/// Exception thrown when JPEG 2000 decoding fails.
class Jpeg2000DecodeException implements Exception {
  final String message;
  const Jpeg2000DecodeException(this.message);

  @override
  String toString() => 'Jpeg2000DecodeException: $message';
}
