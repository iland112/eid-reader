import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:image/image.dart' as img;
import 'package:logging/logging.dart';

import 'jpeg2000_decoder.dart';
import 'jpeg2000_detector.dart';

final _log = Logger('OpenjpegFfi');

// --- Native function typedefs ---

typedef _OpjFlutterDecodeNative = Int32 Function(
    Pointer<Uint8> data,
    Size dataLength,
    Int32 codecType,
    Pointer<Pointer<Uint8>> outRgba,
    Pointer<Int32> outWidth,
    Pointer<Int32> outHeight);
typedef _OpjFlutterDecode = int Function(
    Pointer<Uint8> data,
    int dataLength,
    int codecType,
    Pointer<Pointer<Uint8>> outRgba,
    Pointer<Int32> outWidth,
    Pointer<Int32> outHeight);

typedef _OpjFlutterFreeNative = Void Function(Pointer<Uint8> ptr, Size length);
typedef _OpjFlutterFree = void Function(Pointer<Uint8> ptr, int length);

/// Low-level OpenJPEG FFI wrapper for memory-based JPEG 2000 decoding.
///
/// Uses a thin C wrapper (opj_flutter.c) that handles memory streams internally.
/// Dart side only calls two functions: decode and free.
///
/// Security:
/// - Native buffers are zeroed before freeing (in C code).
/// - No image data is written to disk.
class OpenjpegFfi {
  OpenjpegFfi._();

  static _OpjFlutterDecode? _decode;
  static _OpjFlutterFree? _free;

  /// Lazily loads the OpenJPEG shared library.
  static void _ensureLoaded() {
    if (_decode != null) return;

    final DynamicLibrary lib;
    if (Platform.isAndroid || Platform.isLinux) {
      lib = DynamicLibrary.open('libopenjp2.so');
    } else if (Platform.isWindows) {
      lib = DynamicLibrary.open('openjp2.dll');
    } else {
      throw Jpeg2000DecodeException(
          'OpenJPEG not available on ${Platform.operatingSystem}');
    }

    _decode = lib.lookupFunction<_OpjFlutterDecodeNative, _OpjFlutterDecode>(
        'opj_flutter_decode');
    _free = lib.lookupFunction<_OpjFlutterFreeNative, _OpjFlutterFree>(
        'opj_flutter_free');
  }

  /// Decodes JPEG 2000 image data to PNG bytes.
  ///
  /// Supports both JP2 container and J2K codestream formats.
  /// All native memory is zeroed and freed after use.
  static Uint8List decodeJpeg2000ToPng(Uint8List jp2Data) {
    final format = detectImageFormat(jp2Data);
    final codecType = switch (format) {
      ImageFormat.j2k => 0, // OPJ_CODEC_J2K
      ImageFormat.jp2 => 2, // OPJ_CODEC_JP2
      _ => throw const Jpeg2000DecodeException('Not a JPEG 2000 image'),
    };

    _ensureLoaded();

    // Allocate native memory for input data
    final nativeData = calloc<Uint8>(jp2Data.length);
    final outRgba = calloc<Pointer<Uint8>>();
    final outWidth = calloc<Int32>();
    final outHeight = calloc<Int32>();

    try {
      // Copy JP2 data to native memory
      nativeData.asTypedList(jp2Data.length).setAll(0, jp2Data);

      // Decode
      final result = _decode!(
          nativeData, jp2Data.length, codecType, outRgba, outWidth, outHeight);

      if (result != 0) {
        throw Jpeg2000DecodeException('OpenJPEG decode failed (error: $result)');
      }

      final width = outWidth.value;
      final height = outHeight.value;
      final rgbaPtr = outRgba.value;

      if (rgbaPtr == nullptr || width <= 0 || height <= 0) {
        throw const Jpeg2000DecodeException('Invalid decode output');
      }

      // Convert RGBA buffer to PNG
      final rgbaSize = width * height * 4;
      final rgbaBytes = rgbaPtr.asTypedList(rgbaSize);

      final image = img.Image.fromBytes(
        width: width,
        height: height,
        bytes: rgbaBytes.buffer,
        numChannels: 4,
      );
      final png = Uint8List.fromList(img.encodePng(image));

      _log.fine('Decoded JP2: ${width}x$height -> ${png.length} bytes PNG');

      // Free RGBA buffer (C code zeroes it before freeing)
      _free!(rgbaPtr, rgbaSize);

      return png;
    } finally {
      // Security: zero input native buffer before freeing
      for (var i = 0; i < jp2Data.length; i++) {
        nativeData[i] = 0;
      }
      calloc.free(nativeData);
      calloc.free(outRgba);
      calloc.free(outWidth);
      calloc.free(outHeight);
    }
  }
}
