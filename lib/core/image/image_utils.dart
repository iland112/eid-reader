import 'dart:typed_data';

import 'package:logging/logging.dart';

import 'jpeg2000_decoder.dart';
import 'jpeg2000_detector.dart';

final _log = Logger('ImageUtils');

/// Decodes face image data from DG2 into a Flutter-displayable format.
///
/// - JPEG data is returned as-is (Flutter natively supports JPEG).
/// - JPEG 2000 data is decoded via OpenJPEG FFI and re-encoded as PNG.
/// - Unknown formats return null (UI should show fallback icon).
///
/// Security: All intermediate buffers are zeroed after use.
Uint8List? decodeFaceImage(Uint8List imageData) {
  final format = detectImageFormat(imageData);

  switch (format) {
    case ImageFormat.jpeg:
      _log.fine('DG2 face image: JPEG format (passthrough)');
      return imageData;

    case ImageFormat.jp2:
    case ImageFormat.j2k:
      _log.fine('DG2 face image: JPEG 2000 format, decoding via OpenJPEG');
      try {
        return Jpeg2000Decoder.decodeToPng(imageData);
      } catch (e) {
        _log.warning('JPEG 2000 decode failed: $e');
        return null;
      }

    case ImageFormat.unknown:
      _log.warning('DG2 face image: unknown format');
      return null;
  }
}
