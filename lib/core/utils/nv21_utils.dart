import 'dart:typed_data';

/// Crops an NV21 buffer to the MRZ region (bottom ~50% of the user-visible
/// image), accounting for sensor rotation.
///
/// NV21 layout: `[Y plane: w*h bytes][VU interleaved: w*h/2 bytes]`
///
/// The "bottom of the user-visible image" maps to different raw buffer
/// regions depending on the sensor rotation:
///
/// | rotation | user bottom → raw buffer | crop type    |
/// |----------|--------------------------|--------------|
/// | 0°       | bottom rows              | row crop     |
/// | 90°      | right columns            | column crop  |
/// | 180°     | top rows                 | row crop     |
/// | 270°     | left columns             | column crop  |
///
/// [rotationDegrees] is the InputImageRotation value (0, 90, 180, 270).
/// [cropFraction] is the fraction of the image to keep (default 0.50 = 50%).
/// [srcStride] is the source buffer's bytes-per-row (may differ from [width]
/// if the camera plane has row padding). Defaults to [width] when null.
///
/// Returns a record with the cropped NV21 bytes and the new dimensions.
({Uint8List bytes, int width, int height}) cropNv21ForMrz({
  required Uint8List nv21Bytes,
  required int width,
  required int height,
  required int rotationDegrees,
  int? srcStride,
  double cropFraction = 0.40,
}) {
  if (width <= 0 || height <= 0 || nv21Bytes.isEmpty) {
    return (bytes: nv21Bytes, width: width, height: height);
  }

  final stride = srcStride ?? width;

  // Validate buffer size. For NV21, expected = stride * height * 3 / 2.
  // If the buffer is too small, skip the crop to avoid out-of-bounds reads.
  final expectedSize = stride * height + stride * (height ~/ 2);
  if (nv21Bytes.length < expectedSize) {
    return (bytes: nv21Bytes, width: width, height: height);
  }

  switch (rotationDegrees) {
    case 0:
      // User bottom = raw bottom rows
      return _cropBottomRows(nv21Bytes, width, height, stride, cropFraction);
    case 90:
      // User bottom = raw right columns
      return _cropRightColumns(nv21Bytes, width, height, stride, cropFraction);
    case 180:
      // User bottom = raw top rows
      return _cropTopRows(nv21Bytes, width, height, stride, cropFraction);
    case 270:
      // User bottom = raw left columns
      return _cropLeftColumns(nv21Bytes, width, height, stride, cropFraction);
    default:
      // Unknown rotation — return uncropped
      return (bytes: nv21Bytes, width: width, height: height);
  }
}

/// Crops bottom rows of the raw NV21 buffer.
({Uint8List bytes, int width, int height}) _cropBottomRows(
  Uint8List nv21,
  int w,
  int h,
  int stride,
  double fraction,
) {
  final cropH = _evenFloor((h * fraction).toInt(), h);
  if (cropH <= 0 || cropH >= h) {
    return (bytes: nv21, width: w, height: h);
  }

  final startY = h - cropH;
  return _extractRows(nv21, w, h, stride, startY, cropH);
}

/// Crops top rows of the raw NV21 buffer.
({Uint8List bytes, int width, int height}) _cropTopRows(
  Uint8List nv21,
  int w,
  int h,
  int stride,
  double fraction,
) {
  final cropH = _evenFloor((h * fraction).toInt(), h);
  if (cropH <= 0 || cropH >= h) {
    return (bytes: nv21, width: w, height: h);
  }

  return _extractRows(nv21, w, h, stride, 0, cropH);
}

/// Crops right columns of the raw NV21 buffer.
({Uint8List bytes, int width, int height}) _cropRightColumns(
  Uint8List nv21,
  int w,
  int h,
  int stride,
  double fraction,
) {
  final cropW = _evenFloor((w * fraction).toInt(), w);
  if (cropW <= 0 || cropW >= w) {
    return (bytes: nv21, width: w, height: h);
  }

  final startX = w - cropW;
  return _extractColumns(nv21, w, h, stride, startX, cropW);
}

/// Crops left columns of the raw NV21 buffer.
({Uint8List bytes, int width, int height}) _cropLeftColumns(
  Uint8List nv21,
  int w,
  int h,
  int stride,
  double fraction,
) {
  final cropW = _evenFloor((w * fraction).toInt(), w);
  if (cropW <= 0 || cropW >= w) {
    return (bytes: nv21, width: w, height: h);
  }

  return _extractColumns(nv21, w, h, stride, 0, cropW);
}

/// Extracts a horizontal band (rows) from the NV21 buffer.
///
/// Y plane: copy rows from startY to startY + cropH.
/// VU plane: each VU row covers 2 Y rows, so copy from startY/2 for cropH/2 rows.
/// [stride] is the source buffer's bytes-per-row (may include padding).
/// The output is tightly packed (bytesPerRow == w).
({Uint8List bytes, int width, int height}) _extractRows(
  Uint8List nv21,
  int w,
  int h,
  int stride,
  int startY,
  int cropH,
) {
  final yPlaneSize = stride * h;
  final newSize = w * cropH * 3 ~/ 2;
  final result = Uint8List(newSize);

  // Copy Y rows (reading with source stride, writing tightly packed)
  var destOffset = 0;
  for (var y = 0; y < cropH; y++) {
    final srcOffset = (startY + y) * stride;
    result.setRange(destOffset, destOffset + w, nv21, srcOffset);
    destOffset += w;
  }

  // Copy VU rows
  // VU plane starts at yPlaneSize in the original buffer.
  // Each VU row has `stride` bytes and covers 2 Y rows.
  final vuStartRow = startY ~/ 2;
  final vuRowCount = cropH ~/ 2;
  for (var i = 0; i < vuRowCount; i++) {
    final srcOffset = yPlaneSize + (vuStartRow + i) * stride;
    result.setRange(destOffset, destOffset + w, nv21, srcOffset);
    destOffset += w;
  }

  return (bytes: result, width: w, height: cropH);
}

/// Extracts a vertical band (columns) from the NV21 buffer.
///
/// Must iterate each row and copy a subrange of columns.
/// For the VU plane, startX must be even (chroma subsampling).
/// [stride] is the source buffer's bytes-per-row (may include padding).
/// The output is tightly packed (bytesPerRow == cropW).
({Uint8List bytes, int width, int height}) _extractColumns(
  Uint8List nv21,
  int w,
  int h,
  int stride,
  int startX,
  int cropW,
) {
  final yPlaneSize = stride * h;
  final newSize = cropW * h * 3 ~/ 2;
  final result = Uint8List(newSize);

  // Copy Y plane: for each row, copy cropW bytes starting at startX
  var destOffset = 0;
  for (var y = 0; y < h; y++) {
    final srcOffset = y * stride + startX;
    result.setRange(destOffset, destOffset + cropW, nv21, srcOffset);
    destOffset += cropW;
  }

  // Copy VU plane: each VU row has `stride` bytes covering 2 Y rows.
  // VU is interleaved as V0 U0 V1 U1 ... so chroma pairs are at even offsets.
  // startX must be even (ensured by _evenFloor).
  final vuHeight = h ~/ 2;
  for (var vuRow = 0; vuRow < vuHeight; vuRow++) {
    final srcOffset = yPlaneSize + vuRow * stride + startX;
    result.setRange(destOffset, destOffset + cropW, nv21, srcOffset);
    destOffset += cropW;
  }

  return (bytes: result, width: cropW, height: h);
}

/// Rounds down to the nearest even number, clamped to [2, max].
int _evenFloor(int value, int max) {
  if (value < 2) return 2;
  if (value > max) return max;
  return value & ~1; // Clear lowest bit → even
}

/// Computes a lightweight glare score from an NV21 buffer's Y plane.
///
/// Counts the ratio of pixels with luminance above [threshold] (default 240).
/// NV21's Y plane occupies bytes `[0..W*H-1]`, which IS the luminance — no
/// colour-space conversion needed, making this O(W*H) with zero allocation.
///
/// Returns 0.0 (no glare) to 1.0 (all pixels over-exposed).
/// Returns 0.0 for empty or invalid buffers.
///
/// The default threshold (240) is consistent with
/// `ImageQualityAnalyzer._calcGlareRatioFromGray()`.
double computeNv21GlareScore(
  Uint8List nv21Bytes,
  int width,
  int height, {
  int threshold = 240,
}) {
  final totalPixels = width * height;
  if (totalPixels <= 0 || nv21Bytes.length < totalPixels) {
    return 0.0;
  }

  int overExposed = 0;
  for (int i = 0; i < totalPixels; i++) {
    if (nv21Bytes[i] > threshold) overExposed++;
  }

  return overExposed / totalPixels;
}

/// Computes a lightweight blur score from an NV21 buffer's Y plane.
///
/// Uses simplified Laplacian variance on a subsampled grid for speed.
/// Samples every [step]-th pixel (default 2) to reduce computation by ~4x
/// while maintaining accurate blur detection.
///
/// Returns Laplacian variance: higher = sharper.
/// > 100: good, 50-100: acceptable, < 50: blurry.
/// Returns 0.0 for empty or invalid buffers.
double computeNv21BlurScore(
  Uint8List nv21Bytes,
  int width,
  int height, {
  int step = 2,
}) {
  final totalPixels = width * height;
  if (width < 3 || height < 3 || nv21Bytes.length < totalPixels) {
    return 0.0;
  }

  double sum = 0;
  double sumSq = 0;
  int count = 0;

  // Subsample: step through pixels to trade precision for speed (~20ms)
  for (int y = 1; y < height - 1; y += step) {
    final rowOffset = y * width;
    for (int x = 1; x < width - 1; x += step) {
      final center = nv21Bytes[rowOffset + x].toDouble();
      final top = nv21Bytes[(y - 1) * width + x].toDouble();
      final bottom = nv21Bytes[(y + 1) * width + x].toDouble();
      final left = nv21Bytes[rowOffset + (x - 1)].toDouble();
      final right = nv21Bytes[rowOffset + (x + 1)].toDouble();

      final laplacian = top + bottom + left + right - 4 * center;
      sum += laplacian;
      sumSq += laplacian * laplacian;
      count++;
    }
  }

  if (count == 0) return 0.0;

  final mean = sum / count;
  final variance = (sumSq / count) - (mean * mean);
  return variance.abs();
}

/// Computes lightweight exposure metrics from an NV21 buffer's Y plane.
///
/// Returns a record with:
/// - [meanBrightness]: average luminance (0-255). < 60 = too dark, > 220 = too bright.
/// - [darkRatio]: fraction of pixels below [darkThreshold] (default 40).
///
/// O(W*H) single pass, zero allocation beyond the return value.
({double meanBrightness, double darkRatio}) computeNv21ExposureMetrics(
  Uint8List nv21Bytes,
  int width,
  int height, {
  int darkThreshold = 40,
}) {
  final totalPixels = width * height;
  if (totalPixels <= 0 || nv21Bytes.length < totalPixels) {
    return (meanBrightness: 0.0, darkRatio: 0.0);
  }

  int sumBrightness = 0;
  int darkPixels = 0;

  for (int i = 0; i < totalPixels; i++) {
    final lum = nv21Bytes[i];
    sumBrightness += lum;
    if (lum < darkThreshold) darkPixels++;
  }

  return (
    meanBrightness: sumBrightness / totalPixels,
    darkRatio: darkPixels / totalPixels,
  );
}

/// Computes a composite frame quality score combining glare, blur, and exposure.
///
/// Lower score = better quality (suitable for sorting candidates).
/// Components:
/// - glareScore: over-exposed pixel ratio (0.0 - 1.0)
/// - blurPenalty: inverse blur quality (0.0 - 1.0, 1.0 = very blurry)
/// - darkPenalty: low-light penalty (0.0 - 1.0)
///
/// Weights: glare 40%, blur 40%, darkness 20%.
double computeNv21CompositeScore(
  Uint8List nv21Bytes,
  int width,
  int height,
) {
  final glare = computeNv21GlareScore(nv21Bytes, width, height);
  final blur = computeNv21BlurScore(nv21Bytes, width, height);
  final exposure = computeNv21ExposureMetrics(nv21Bytes, width, height);

  // Normalize blur: 0 = very blurry (penalty 1.0), >= 200 = sharp (penalty 0.0)
  final blurPenalty = (1.0 - (blur / 200.0)).clamp(0.0, 1.0);

  // Normalize darkness: mean < 60 = too dark (penalty 1.0), >= 120 = fine (penalty 0.0)
  final darkPenalty =
      (1.0 - (exposure.meanBrightness - 60) / 60).clamp(0.0, 1.0);

  return glare * 0.4 + blurPenalty * 0.4 + darkPenalty * 0.2;
}

/// Downsamples an NV21 buffer by a factor of 2 (half width, half height).
///
/// Uses simple 2x2 averaging for Y plane and direct subsampling for VU plane.
/// This reduces the pixel count by 4x, significantly speeding up ML Kit OCR
/// while maintaining sufficient text resolution for MRZ recognition.
///
/// Returns null if the buffer is too small or dimensions are odd.
({Uint8List bytes, int width, int height})? downsampleNv21x2(
  Uint8List nv21Bytes,
  int width,
  int height,
) {
  if (width < 4 || height < 4 || width.isOdd || height.isOdd) return null;

  final expectedSize = width * height + width * (height ~/ 2);
  if (nv21Bytes.length < expectedSize) return null;

  final outW = width ~/ 2;
  final outH = height ~/ 2;
  final outSize = outW * outH + outW * (outH ~/ 2);
  final result = Uint8List(outSize);

  // Downsample Y plane: average 2x2 blocks
  var destIdx = 0;
  for (int y = 0; y < height; y += 2) {
    final row0 = y * width;
    final row1 = (y + 1) * width;
    for (int x = 0; x < width; x += 2) {
      result[destIdx++] = ((nv21Bytes[row0 + x] +
                  nv21Bytes[row0 + x + 1] +
                  nv21Bytes[row1 + x] +
                  nv21Bytes[row1 + x + 1]) >>
              2);
    }
  }

  // Downsample VU plane: take every other VU pair
  final uvOffset = width * height;
  final uvWidth = width; // VU pairs per row (interleaved V,U)
  final uvHeight = height ~/ 2;
  for (int vuRow = 0; vuRow < uvHeight; vuRow += 2) {
    final srcRowOffset = uvOffset + vuRow * uvWidth;
    for (int x = 0; x < uvWidth; x += 4) {
      // Each VU pair is 2 bytes (V, U), take every other pair
      result[destIdx++] = nv21Bytes[srcRowOffset + x]; // V
      result[destIdx++] = nv21Bytes[srcRowOffset + x + 1]; // U
    }
  }

  return (bytes: result, width: outW, height: outH);
}

/// Converts a subregion of an NV21 buffer to RGBA8888 bytes with rotation.
///
/// Only processes pixels within [roi] (in raw NV21 coordinates), producing
/// a smaller output buffer. This is significantly faster than converting the
/// entire image when only a portion is needed (e.g., VIZ face region).
///
/// [roi] is specified in pre-rotation coordinates (raw buffer space).
/// The output dimensions account for rotation.
({Uint8List rgba, int width, int height}) nv21ToRgbaRoi({
  required Uint8List nv21Bytes,
  required int width,
  required int height,
  required int roiX,
  required int roiY,
  required int roiW,
  required int roiH,
  int rotationDegrees = 0,
}) {
  if (width <= 0 || height <= 0 || nv21Bytes.isEmpty) {
    return (rgba: Uint8List(0), width: 0, height: 0);
  }
  if (roiW <= 0 || roiH <= 0) {
    return (rgba: Uint8List(0), width: 0, height: 0);
  }

  // Clamp ROI to buffer bounds
  final x0 = roiX.clamp(0, width - 1);
  final y0 = roiY.clamp(0, height - 1);
  final x1 = (roiX + roiW).clamp(0, width);
  final y1 = (roiY + roiH).clamp(0, height);
  final clampedW = x1 - x0;
  final clampedH = y1 - y0;
  if (clampedW <= 0 || clampedH <= 0) {
    return (rgba: Uint8List(0), width: 0, height: 0);
  }

  final expectedSize = width * height + width * (height ~/ 2);
  if (nv21Bytes.length < expectedSize) {
    return (rgba: Uint8List(0), width: 0, height: 0);
  }

  final bool swapDims = rotationDegrees == 90 || rotationDegrees == 270;
  final outW = swapDims ? clampedH : clampedW;
  final outH = swapDims ? clampedW : clampedH;
  final rgba = Uint8List(outW * outH * 4);
  final uvOffset = width * height;

  for (var y = y0; y < y1; y++) {
    final uvRow = (y >> 1) * width;
    for (var x = x0; x < x1; x++) {
      final yVal = nv21Bytes[y * width + x];
      final uvIdx = uvOffset + uvRow + (x & ~1);
      final v = nv21Bytes[uvIdx] - 128;
      final u = nv21Bytes[uvIdx + 1] - 128;

      final r = (yVal + ((351 * v) >> 8)).clamp(0, 255);
      final g = (yVal - ((86 * u + 179 * v) >> 8)).clamp(0, 255);
      final b = (yVal + ((443 * u) >> 8)).clamp(0, 255);

      // Map ROI-local coordinates to output position
      final localX = x - x0;
      final localY = y - y0;
      int outIdx;
      switch (rotationDegrees) {
        case 90:
          outIdx = (localX * outW + (clampedH - 1 - localY)) * 4;
        case 180:
          outIdx =
              ((clampedH - 1 - localY) * outW + (clampedW - 1 - localX)) * 4;
        case 270:
          outIdx = ((clampedW - 1 - localX) * outW + localY) * 4;
        default:
          outIdx = (localY * outW + localX) * 4;
      }

      rgba[outIdx] = r;
      rgba[outIdx + 1] = g;
      rgba[outIdx + 2] = b;
      rgba[outIdx + 3] = 255;
    }
  }

  return (rgba: rgba, width: outW, height: outH);
}

/// Converts an NV21 buffer to RGBA8888 bytes with optional rotation.
///
/// NV21 layout: `[Y plane: W*H bytes][VU interleaved: W*H/2 bytes]`
/// RGBA layout: `[R,G,B,A, R,G,B,A, ...]` — 4 bytes per pixel.
///
/// Uses ITU-R BT.601 YUV→RGB conversion with fixed-point arithmetic
/// for performance (~60ms for 1920×1080 on mid-range devices).
///
/// [rotationDegrees] applies clockwise rotation to the output image:
///   - 0°: no rotation (output W×H)
///   - 90°: rotate CW (output H×W)
///   - 180°: rotate 180° (output W×H)
///   - 270°: rotate CCW (output H×W)
///
/// Returns a record with the RGBA bytes and rotated dimensions.
({Uint8List rgba, int width, int height}) nv21ToRgba({
  required Uint8List nv21Bytes,
  required int width,
  required int height,
  int rotationDegrees = 0,
}) {
  if (width <= 0 || height <= 0 || nv21Bytes.isEmpty) {
    return (rgba: Uint8List(0), width: 0, height: 0);
  }

  final expectedSize = width * height + width * (height ~/ 2);
  if (nv21Bytes.length < expectedSize) {
    return (rgba: Uint8List(0), width: 0, height: 0);
  }

  final bool swapDims = rotationDegrees == 90 || rotationDegrees == 270;
  final outW = swapDims ? height : width;
  final outH = swapDims ? width : height;
  final rgba = Uint8List(outW * outH * 4);
  final uvOffset = width * height;

  for (var y = 0; y < height; y++) {
    final uvRow = (y >> 1) * width;
    for (var x = 0; x < width; x++) {
      // Read YUV values
      final yVal = nv21Bytes[y * width + x];
      final uvIdx = uvOffset + uvRow + (x & ~1);
      final v = nv21Bytes[uvIdx] - 128;
      final u = nv21Bytes[uvIdx + 1] - 128;

      // ITU-R BT.601 fixed-point: multiply by 256 to avoid float
      // R = Y + 1.370705*V ≈ Y + (351*V)>>8
      // G = Y - 0.337633*U - 0.698001*V ≈ Y - (86*U + 179*V)>>8
      // B = Y + 1.732446*U ≈ Y + (443*U)>>8
      final r = (yVal + ((351 * v) >> 8)).clamp(0, 255);
      final g = (yVal - ((86 * u + 179 * v) >> 8)).clamp(0, 255);
      final b = (yVal + ((443 * u) >> 8)).clamp(0, 255);

      // Compute output position based on rotation
      int outIdx;
      switch (rotationDegrees) {
        case 90:
          // (x,y) → output (height-1-y, x) in H×W image
          outIdx = (x * outW + (height - 1 - y)) * 4;
        case 180:
          // (x,y) → output (width-1-x, height-1-y) in W×H image
          outIdx = ((height - 1 - y) * outW + (width - 1 - x)) * 4;
        case 270:
          // (x,y) → output (y, width-1-x) in H×W image
          outIdx = ((width - 1 - x) * outW + y) * 4;
        default:
          // 0° — no rotation
          outIdx = (y * outW + x) * 4;
      }

      rgba[outIdx] = r;
      rgba[outIdx + 1] = g;
      rgba[outIdx + 2] = b;
      rgba[outIdx + 3] = 255; // Alpha
    }
  }

  return (rgba: rgba, width: outW, height: outH);
}
