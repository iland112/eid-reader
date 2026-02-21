import 'dart:typed_data';

/// Detects image format from raw bytes by examining magic bytes.
enum ImageFormat {
  /// Standard JPEG (JFIF/Exif).
  jpeg,

  /// JPEG 2000 JP2 container format.
  jp2,

  /// JPEG 2000 raw codestream (J2K/JPC).
  j2k,

  /// Unknown or unsupported format.
  unknown,
}

/// Detects image format from the first bytes of image data.
///
/// Supports:
/// - JPEG: `FF D8 FF` (SOI + marker)
/// - JP2 container: `00 00 00 0C 6A 50 20 20` (JP2 signature box)
/// - J2K codestream: `FF 4F FF 51` (SOC + SIZ markers)
ImageFormat detectImageFormat(Uint8List data) {
  if (data.length < 4) return ImageFormat.unknown;

  // JPEG: starts with FF D8 FF
  if (data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF) {
    return ImageFormat.jpeg;
  }

  // JP2 container: 00 00 00 0C 6A 50 20 20 (12-byte signature box)
  if (data.length >= 8 &&
      data[0] == 0x00 &&
      data[1] == 0x00 &&
      data[2] == 0x00 &&
      data[3] == 0x0C &&
      data[4] == 0x6A && // 'j'
      data[5] == 0x50 && // 'P'
      data[6] == 0x20 && // ' '
      data[7] == 0x20) {
    // ' '
    return ImageFormat.jp2;
  }

  // J2K codestream: FF 4F FF 51 (SOC + SIZ)
  if (data[0] == 0xFF &&
      data[1] == 0x4F &&
      data[2] == 0xFF &&
      data[3] == 0x51) {
    return ImageFormat.j2k;
  }

  return ImageFormat.unknown;
}

/// Returns true if data is standard JPEG format.
bool isJpeg(Uint8List data) => detectImageFormat(data) == ImageFormat.jpeg;

/// Returns true if data is JPEG 2000 (either JP2 container or J2K codestream).
bool isJpeg2000(Uint8List data) {
  final format = detectImageFormat(data);
  return format == ImageFormat.jp2 || format == ImageFormat.j2k;
}
