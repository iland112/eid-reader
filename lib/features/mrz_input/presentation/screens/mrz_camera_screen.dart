import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:logging/logging.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:share_plus/share_plus.dart';

import '../../../../core/services/debug_log_service.dart';
import '../../../../core/utils/l10n_extension.dart';
import '../../../../core/utils/mrz_utils.dart';
import '../../../../core/utils/nv21_utils.dart';
import '../../domain/entities/mrz_data.dart';
import '../providers/mrz_camera_provider.dart';

final _log = Logger('MrzCameraScreen');

class MrzCameraScreen extends ConsumerStatefulWidget {
  const MrzCameraScreen({super.key});

  @override
  ConsumerState<MrzCameraScreen> createState() => _MrzCameraScreenState();
}

class _MrzCameraScreenState extends ConsumerState<MrzCameraScreen> {
  CameraController? _cameraController;
  bool _isInitialized = false;
  String? _initError;
  bool _isStreamActive = false;
  bool _isProcessingFrame = false;
  DateTime _lastProcessed = DateTime(2000);
  bool _isTorchOn = false;
  bool _isCapturingViz = false;

  // Ring buffer of recent preview frames scored by glare for VIZ capture.
  // Retains up to N candidates; the lowest-glare frame is selected at capture time.
  static const _maxFrameCandidates = 5;
  final List<_FrameCandidate> _frameCandidates = [];
  bool _showDebugLog = false;
  bool _cropDiagLogged = false;
  final ScrollController _logScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Lock to portrait only — landscape causes rotation/layout issues
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      // Request camera permission at runtime
      final status = await Permission.camera.request();
      if (!mounted) return;
      if (status.isDenied) {
        setState(
            () => _initError = context.l10n.mrzCameraErrorPermissionDenied);
        return;
      }
      if (status.isPermanentlyDenied) {
        setState(() =>
            _initError = context.l10n.mrzCameraErrorPermissionPermanent);
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _initError = context.l10n.mrzCameraErrorNoCamera);
        return;
      }

      // Use the back camera
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _cameraController!.initialize();

      // Enable continuous autofocus (also activates OIS on supported hardware)
      try {
        await _cameraController!.setFocusMode(FocusMode.auto);
      } catch (_) {
        // Not all devices support setFocusMode
      }

      if (!mounted) return;

      setState(() => _isInitialized = true);
      _startImageStream();
    } catch (e) {
      if (!mounted) return;
      setState(() => _initError = context.l10n.mrzCameraErrorInitFailed);
    }
  }

  void _startImageStream() {
    if (_cameraController == null || _isStreamActive) return;

    _isStreamActive = true;
    _cameraController!.startImageStream((image) {
      _processFrame(image);
    });
  }

  Future<void> _processFrame(CameraImage image) async {
    // Throttle: process at most one frame every 500ms
    if (_isProcessingFrame) return;
    final now = DateTime.now();
    if (now.difference(_lastProcessed).inMilliseconds < 500) return;

    _isProcessingFrame = true;
    _lastProcessed = now;

    try {
      final notifier = ref.read(mrzCameraProvider.notifier);

      // Get raw NV21 bytes for quality analysis
      final Uint8List rawNv21;
      if (image.format.group == ImageFormatGroup.nv21) {
        rawNv21 = image.planes.first.bytes;
      } else if (image.format.group == ImageFormatGroup.yuv420) {
        rawNv21 = _yuv420ToNv21(image);
      } else {
        rawNv21 = Uint8List(0);
      }

      // --- Pre-OCR quality analysis (on raw Y plane) ---
      // Compute lightweight quality metrics for real-time UI feedback
      // and to skip OCR on frames that are too blurry or dark.
      double frameGlare = 0;
      double frameBlur = 0;
      double frameBrightness = 128;
      if (rawNv21.isNotEmpty) {
        frameGlare =
            computeNv21GlareScore(rawNv21, image.width, image.height);
        frameBlur =
            computeNv21BlurScore(rawNv21, image.width, image.height);
        final exposure =
            computeNv21ExposureMetrics(rawNv21, image.width, image.height);
        frameBrightness = exposure.meanBrightness;

        final feedback = FrameQualityFeedback(
          isBlurry: frameBlur < 50,
          isTooDark: frameBrightness < 60,
          hasGlare: frameGlare > 0.10,
          blurScore: frameBlur,
          meanBrightness: frameBrightness,
          glareRatio: frameGlare,
        );
        notifier.updateQualityFeedback(feedback);

        // Skip OCR if frame is too blurry — saves ~150-300ms of wasted ML Kit
        if (frameBlur < 30) {
          _log.fine('Frame skipped: too blurry (score=$frameBlur)');
          return;
        }

        // Skip OCR if too dark — ML Kit will fail anyway
        if (frameBrightness < 40) {
          _log.fine(
              'Frame skipped: too dark (brightness=${frameBrightness.toStringAsFixed(0)})');
          return;
        }
      }

      // Build InputImage from camera frame (includes MRZ ROI crop + downsample)
      final inputImage = _buildInputImage(image);
      if (inputImage == null) {
        _log.fine('Frame skipped: _buildInputImage returned null');
        return;
      }

      // Cache un-cropped NV21 with composite score for VIZ best-frame selection.
      // Reuse pre-computed metrics to avoid redundant Y-plane scans.
      // Only start caching after first MRZ candidate to avoid unnecessary copies.
      final frameCount = ref.read(mrzCameraProvider).debugFrameCount;
      if (frameCount > 0 && rawNv21.isNotEmpty) {
        final copy = Uint8List.fromList(rawNv21);
        // Compute composite from pre-computed metrics
        final blurPenalty = (1.0 - (frameBlur / 200.0)).clamp(0.0, 1.0);
        final darkPenalty =
            (1.0 - (frameBrightness - 60) / 60).clamp(0.0, 1.0);
        final compositeScore =
            frameGlare * 0.4 + blurPenalty * 0.4 + darkPenalty * 0.2;
        _frameCandidates.add(_FrameCandidate(
          nv21: copy,
          width: image.width,
          height: image.height,
          glareScore: frameGlare,
          blurScore: frameBlur,
          compositeScore: compositeScore,
        ));
        // Evict oldest when buffer is full, zero-fill for security
        if (_frameCandidates.length > _maxFrameCandidates) {
          _frameCandidates.removeAt(0).clear();
        }
      }

      await notifier.processImage(inputImage);

      // If MRZ was just detected, capture VIZ
      final state = ref.read(mrzCameraProvider);
      if (state.detectedMrz != null &&
          state.vizCaptureStatus == VizCaptureStatus.idle &&
          !_isCapturingViz) {
        _log.info('MRZ detected, triggering VIZ capture');
        _captureVizFromStill();
      }
    } finally {
      _isProcessingFrame = false;
    }
  }

  /// Captures VIZ face directly from the cached NV21 preview frame.
  ///
  /// Converts NV21→RGBA in-process (~60ms) instead of takePicture() (469ms)
  /// + JPEG decode (115ms), reducing total VIZ capture time by ~580ms.
  Future<void> _captureVizFromStill() async {
    if (_cameraController == null || _isCapturingViz) return;
    _isCapturingViz = true;
    final sw = Stopwatch()..start();

    try {
      // Capture device orientation BEFORE stopping the stream, so we
      // know which way the device was held at capture time.
      final sensorOrientation =
          _cameraController!.description.sensorOrientation;
      final deviceOrientation = _cameraController!.value.deviceOrientation;
      final deviceDegrees = _deviceOrientationDegrees(deviceOrientation);
      final rotationCompensation =
          (sensorOrientation - deviceDegrees + 360) % 360;
      _log.info(
        'VIZ capture: sensor=$sensorOrientation, device=$deviceDegrees, '
        'rotation=$rotationCompensation',
      );

      // Select the frame with the lowest composite score from cached candidates
      if (_frameCandidates.isEmpty) {
        _log.warning('VIZ capture: no preview frames available');
        ref.read(mrzCameraProvider.notifier).markVizError();
        return;
      }
      _frameCandidates
          .sort((a, b) => a.compositeScore.compareTo(b.compositeScore));
      final best = _frameCandidates.first;
      _log.info(
        'VIZ capture: selected frame with '
        'composite=${best.compositeScore.toStringAsFixed(3)}, '
        'glare=${best.glareScore.toStringAsFixed(3)}, '
        'blur=${best.blurScore.toStringAsFixed(1)} '
        'from ${_frameCandidates.length} candidates',
      );
      final savedNv21 = best.nv21;
      final savedWidth = best.width;
      final savedHeight = best.height;
      // Clear all other candidates (security), then clear the list
      for (final c in _frameCandidates) {
        if (!identical(c, best)) c.clear();
      }
      _frameCandidates.clear();

      // Stop the image stream (no takePicture needed).
      await _cameraController!.stopImageStream();
      _isStreamActive = false;

      // Build ML Kit InputImage from the NV21 buffer (used for both
      // preview face pre-detection and as CaptureVizFace fallback).
      Rect? previewFaceRect;
      Size? previewSize;
      InputImage? nv21InputImage;
      final rotationValue =
          InputImageRotationValue.fromRawValue(rotationCompensation);

      if (rotationValue != null) {
        // InputImageMetadata.size describes the RAW buffer layout.
        final rawSize = Size(
          savedWidth.toDouble(),
          savedHeight.toDouble(),
        );
        // previewSize describes the ROTATED coordinate system that ML Kit
        // returns face coordinates in. For 90°/270°, width and height swap.
        final bool swapDims =
            rotationCompensation == 90 || rotationCompensation == 270;
        previewSize = Size(
          swapDims ? savedHeight.toDouble() : savedWidth.toDouble(),
          swapDims ? savedWidth.toDouble() : savedHeight.toDouble(),
        );
        nv21InputImage = InputImage.fromBytes(
          bytes: savedNv21,
          metadata: InputImageMetadata(
            size: rawSize,
            rotation: rotationValue,
            format: InputImageFormat.nv21,
            bytesPerRow: savedWidth,
          ),
        );

        // Preview-frame face pre-detection (no 300ms delay needed —
        // preview frame is already captured, no hardware stabilization).
        final faceService = ref.read(faceDetectionServiceProvider);
        if (faceService != null) {
          final faceRects = await faceService.detectFaces(nv21InputImage);
          if (faceRects.isNotEmpty) {
            previewFaceRect =
                _selectMainFace(faceRects, imageWidth: previewSize.width);
            _log.info(
              'VIZ capture: preview face pre-detected at '
              '${previewFaceRect.left.toInt()},${previewFaceRect.top.toInt()} '
              '${previewFaceRect.width.toInt()}x${previewFaceRect.height.toInt()} '
              '(${sw.elapsedMilliseconds}ms)',
            );
          }
        }
      }
      _log.fine('VIZ capture: stream stopped (${sw.elapsedMilliseconds}ms)');

      // Convert full NV21 → RGBA with rotation.
      // Full-image conversion ensures face detection coordinates remain valid.
      final converted = nv21ToRgba(
        nv21Bytes: savedNv21,
        width: savedWidth,
        height: savedHeight,
        rotationDegrees: rotationCompensation,
      );
      _log.info(
        'VIZ capture: NV21→RGBA converted, '
        '${converted.width}x${converted.height} '
        '(${sw.elapsedMilliseconds}ms)',
      );

      final notifier = ref.read(mrzCameraProvider.notifier);
      await notifier.captureViz(
        rgbaBytes: converted.rgba,
        imageWidth: converted.width,
        imageHeight: converted.height,
        inputImage: nv21InputImage,
        rotationCompensation: rotationCompensation,
        previewFaceRect: previewFaceRect,
        previewSize: previewSize,
      );

      _log.info('VIZ capture: completed (${sw.elapsedMilliseconds}ms)');

      // Security: zero the NV21 bytes after processing
      savedNv21.fillRange(0, savedNv21.length, 0);
    } catch (e, st) {
      _log.warning(
        'VIZ capture: FAILED after ${sw.elapsedMilliseconds}ms',
        e,
        st,
      );
      // VIZ capture failure is non-fatal; ensure status reflects failure
      // so the UI doesn't get stuck with a disabled button.
      try {
        ref.read(mrzCameraProvider.notifier).markVizError();
      } catch (_) {}
    } finally {
      _isCapturingViz = false;
    }
  }

  InputImage? _buildInputImage(CameraImage image) {
    if (_cameraController == null) return null;

    final sensorOrientation =
        _cameraController!.description.sensorOrientation;

    // Compensate for current device orientation so ML Kit receives
    // correctly-oriented image metadata regardless of portrait/landscape.
    final deviceOrientation = _cameraController!.value.deviceOrientation;
    final deviceDegrees = _deviceOrientationDegrees(deviceOrientation);
    final rotationDegrees =
        (sensorOrientation - deviceDegrees + 360) % 360;
    final rotation = InputImageRotationValue.fromRawValue(rotationDegrees);
    if (rotation == null) return null;

    // ML Kit fromBytes only works reliably with NV21 on Android.
    // If camera returns YUV420, convert to NV21 first.
    final Uint8List nv21Bytes;
    final int srcStride;
    if (image.format.group == ImageFormatGroup.nv21) {
      nv21Bytes = image.planes.first.bytes;
      srcStride = image.planes.first.bytesPerRow;
    } else if (image.format.group == ImageFormatGroup.yuv420) {
      nv21Bytes = _yuv420ToNv21(image);
      srcStride = image.width; // tightly packed by conversion
    } else {
      return null;
    }

    // Crop to MRZ region (bottom ~50% of user-visible image) to reduce
    // OCR processing time and improve recognition accuracy.
    final cropped = cropNv21ForMrz(
      nv21Bytes: nv21Bytes,
      width: image.width,
      height: image.height,
      rotationDegrees: rotationDegrees,
      srcStride: srcStride,
    );

    // Downsample cropped region by 2x for faster ML Kit OCR (~40% speedup).
    // MRZ text remains large enough for reliable recognition at half resolution.
    final downsampled =
        downsampleNv21x2(cropped.bytes, cropped.width, cropped.height);
    final ocrBytes = downsampled?.bytes ?? cropped.bytes;
    final ocrWidth = downsampled?.width ?? cropped.width;
    final ocrHeight = downsampled?.height ?? cropped.height;

    // One-time diagnostic log for crop debugging
    if (!_cropDiagLogged) {
      _cropDiagLogged = true;
      _log.info(
        'MRZ crop diag: '
        'fmt=${image.format.group}, '
        'planes=${image.planes.length}, '
        'bytesPerRow=${image.planes.first.bytesPerRow}, '
        'raw=${image.width}x${image.height}, '
        'sensor=$sensorOrientation, device=$deviceDegrees, '
        'rotation=$rotationDegrees, '
        'buf=${nv21Bytes.length}, '
        'expected=${srcStride * image.height * 3 ~/ 2}, '
        'crop=${cropped.width}x${cropped.height}, '
        'ocr=${ocrWidth}x$ocrHeight '
        '(ds=${downsampled != null})',
      );
    }

    return InputImage.fromBytes(
      bytes: ocrBytes,
      metadata: InputImageMetadata(
        size: Size(ocrWidth.toDouble(), ocrHeight.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: ocrWidth,
      ),
    );
  }

  /// Converts YUV_420_888 (3-plane) to NV21 (single buffer).
  /// NV21 layout: [Y plane] [V U interleaved]
  Uint8List _yuv420ToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final nv21 = Uint8List(width * height * 3 ~/ 2);

    // Copy Y plane (handles bytesPerRow padding)
    var destIndex = 0;
    for (var row = 0; row < height; row++) {
      final srcOffset = row * yPlane.bytesPerRow;
      for (var col = 0; col < width; col++) {
        nv21[destIndex++] = yPlane.bytes[srcOffset + col];
      }
    }

    // Interleave V and U planes (NV21 = VUVUVU...)
    final uvHeight = height ~/ 2;
    final uvWidth = width ~/ 2;
    final vPixelStride = vPlane.bytesPerPixel ?? 1;
    final uPixelStride = uPlane.bytesPerPixel ?? 1;

    for (var row = 0; row < uvHeight; row++) {
      for (var col = 0; col < uvWidth; col++) {
        final vIdx = row * vPlane.bytesPerRow + col * vPixelStride;
        final uIdx = row * uPlane.bytesPerRow + col * uPixelStride;
        nv21[destIndex++] = vPlane.bytes[vIdx];
        nv21[destIndex++] = uPlane.bytes[uIdx];
      }
    }

    return nv21;
  }

  /// Selects the main passport photo face, preferring faces in the left
  /// portion of the image (ICAO 9303: main photo is always on the left).
  static Rect _selectMainFace(List<Rect> faces, {required double imageWidth}) {
    if (faces.length == 1) return faces.first;

    Rect best = faces.first;
    double bestScore = -1;

    for (final face in faces) {
      final area = face.width * face.height;
      final centerX = face.left + face.width / 2;
      final multiplier = (centerX / imageWidth) < 0.4 ? 1.5 : 1.0;
      final score = area * multiplier;

      if (score > bestScore) {
        bestScore = score;
        best = face;
      }
    }

    return best;
  }

  static int _deviceOrientationDegrees(DeviceOrientation orientation) {
    switch (orientation) {
      case DeviceOrientation.portraitUp:
        return 0;
      case DeviceOrientation.landscapeLeft:
        return 90;
      case DeviceOrientation.portraitDown:
        return 180;
      case DeviceOrientation.landscapeRight:
        return 270;
    }
  }

  bool _isVizCapturing(MrzCameraState cameraState) {
    return cameraState.vizCaptureStatus == VizCaptureStatus.detectingFace;
  }

  void _onUseData(MrzData data) {
    Navigator.of(context).pop(data);
  }

  Future<void> _toggleTorch() async {
    if (_cameraController == null) return;
    try {
      final newMode = _isTorchOn ? FlashMode.off : FlashMode.torch;
      await _cameraController!.setFlashMode(newMode);
      setState(() => _isTorchOn = !_isTorchOn);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.mrzCameraFlashlightUnavailable)),
        );
      }
    }
  }

  Future<void> _shareLogFile() async {
    final path = DebugLogService.instance.logFilePath;
    if (path == null) return;

    // Flush pending writes before sharing
    await DebugLogService.instance.flush();

    await Share.shareXFiles(
      [XFile(path)],
      text: 'eID Reader debug log',
    );
  }

  @override
  void dispose() {
    _logScrollController.dispose();
    // Security: zero-fill all cached preview frames
    for (final c in _frameCandidates) {
      c.clear();
    }
    _frameCandidates.clear();
    _cameraController?.stopImageStream().catchError((_) {});
    _cameraController?.dispose();
    // Restore all orientations when leaving this screen
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(mrzCameraProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.mrzCameraTitle),
        actions: [
          if (kDebugMode)
            IconButton(
              icon: Icon(
                _showDebugLog ? Icons.bug_report : Icons.bug_report_outlined,
              ),
              tooltip: _showDebugLog ? context.l10n.mrzCameraTooltipHideDebug : context.l10n.mrzCameraTooltipShowDebug,
              onPressed: () => setState(() => _showDebugLog = !_showDebugLog),
            ),
          if (_isInitialized)
            IconButton(
              icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off),
              tooltip: _isTorchOn ? context.l10n.mrzCameraTooltipTorchOn : context.l10n.mrzCameraTooltipTorchOff,
              onPressed: _toggleTorch,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                _buildCameraPreview(),
                if (_showDebugLog) _buildDebugLogOverlay(),
              ],
            ),
          ),
          _buildBottomPanel(cameraState),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_initError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.no_photography,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                _initError!,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              if (_initError == context.l10n.mrzCameraErrorPermissionPermanent) ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => openAppSettings(),
                  child: Text(context.l10n.mrzCameraOpenSettings),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (!_isInitialized || _cameraController == null) {
      return Center(
        child: Semantics(
          label: context.l10n.semanticLoadingCamera,
          child: const CircularProgressIndicator(),
        ),
      );
    }

    // Show camera preview at native aspect ratio (no stretching).
    // Use FittedBox with BoxFit.cover to fill the available space
    // while preserving aspect ratio, then clip the overflow.
    final previewAspect = _cameraController!.value.aspectRatio;
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: 1,
                height: previewAspect,
                child: CameraPreview(_cameraController!),
              ),
            ),
            _buildOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugLogOverlay() {
    return Positioned.fill(
      child: ValueListenableBuilder<List<String>>(
        valueListenable: DebugLogService.instance.logs,
        builder: (context, logLines, _) {
          // Auto-scroll to bottom after frame renders
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_logScrollController.hasClients) {
              _logScrollController.jumpTo(
                _logScrollController.position.maxScrollExtent,
              );
            }
          });

          return Container(
            color: Colors.black.withValues(alpha: 0.75),
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with log file path + share button
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Log: ${DebugLogService.instance.logFilePath ?? "N/A"}',
                        style: const TextStyle(
                          color: Colors.yellow,
                          fontSize: 8,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: _shareLogFile,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          Icons.share,
                          color: Colors.yellow,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(color: Colors.white24, height: 8),
                // Scrollable log lines
                Expanded(
                  child: ListView.builder(
                    controller: _logScrollController,
                    itemCount: logLines.length,
                    itemBuilder: (context, index) {
                      return Text(
                        logLines[index],
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 8,
                          fontFamily: 'monospace',
                          height: 1.3,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // ID-3 passport data page is always landscape: 125mm × 88mm.
        // The VIZ guide box is always a landscape rectangle regardless
        // of device orientation. In portrait mode it appears as a smaller
        // horizontal rectangle; in landscape mode it fills more of the screen.
        const passportAspect = 88.0 / 125.0; // height/width ≈ 0.70
        final maxHeight = constraints.maxHeight - 32;
        final maxWidth = constraints.maxWidth - 32;

        // Start from max width (passport is landscape = wider than tall),
        // then constrain by available height if needed.
        var boxWidth = maxWidth;
        var boxHeight = boxWidth * passportAspect;
        if (boxHeight > maxHeight) {
          boxHeight = maxHeight;
          boxWidth = boxHeight / passportAspect;
        }

        return ExcludeSemantics(
          child: CustomPaint(
            painter: _PassportOverlayPainter(
              boxWidth: boxWidth,
              boxHeight: boxHeight,
            ),
            child: Center(
              child: SizedBox(
                width: boxWidth,
                height: boxHeight,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    border: Border.fromBorderSide(
                      BorderSide(
                        color: Colors.white70,
                        width: 2,
                      ),
                    ),
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: const BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(6),
                          bottomRight: Radius.circular(6),
                        ),
                      ),
                      child: Text(
                        context.l10n.mrzCameraVizLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomPanel(MrzCameraState cameraState) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Theme.of(context).colorScheme.surface,
      child: cameraState.detectedMrz != null
          ? _buildDetectedPanel(cameraState)
          : _buildScanningPanel(cameraState),
    );
  }

  Widget _buildScanningPanel(MrzCameraState cameraState) {
    final feedback = cameraState.qualityFeedback;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (cameraState.isProcessing)
          const LinearProgressIndicator()
        else
          const SizedBox(height: 4),
        const SizedBox(height: 12),
        // Real-time quality feedback
        if (feedback.hasIssue) ...[
          _buildQualityFeedbackRow(feedback),
          const SizedBox(height: 8),
        ],
        Text(
          context.l10n.mrzCameraPositionInstruction,
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildQualityFeedbackRow(FrameQualityFeedback feedback) {
    final colorScheme = Theme.of(context).colorScheme;
    final warnings = <({IconData icon, String text, Color color})>[];

    if (feedback.isBlurry) {
      warnings.add((
        icon: Icons.blur_on,
        text: context.l10n.mrzCameraQualityBlurry,
        color: colorScheme.error,
      ));
    }
    if (feedback.isTooDark) {
      warnings.add((
        icon: Icons.brightness_low,
        text: context.l10n.mrzCameraQualityTooDark,
        color: colorScheme.error,
      ));
    }
    if (feedback.hasGlare) {
      warnings.add((
        icon: Icons.wb_sunny_outlined,
        text: context.l10n.mrzCameraQualityGlare,
        color: Colors.orange,
      ));
    }

    return Wrap(
      spacing: 12,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: warnings
          .map((w) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(w.icon, size: 16, color: w.color),
                  const SizedBox(width: 4),
                  Text(
                    w.text,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: w.color),
                  ),
                ],
              ))
          .toList(),
    );
  }

  Widget _buildDetectedPanel(MrzCameraState cameraState) {
    final data = cameraState.detectedMrz!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              context.l10n.mrzCameraMrzDetected,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // MRZ line preview card
        if (data.mrzLine1 != null && data.mrzLine2 != null)
          _buildMrzPreviewCard(data.mrzLine1!, data.mrzLine2!),
        const SizedBox(height: 8),
        // VIZ face preview + MRZ fields
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Face preview thumbnail
            _buildFacePreview(cameraState),
            const SizedBox(width: 12),
            // MRZ fields (expanded)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (data.surname != null)
                    _buildField(
                      context.l10n.labelName,
                      data.givenNames != null && data.givenNames!.isNotEmpty
                          ? '${data.givenNames} ${data.surname}'
                          : data.surname!,
                    ),
                  _buildField(context.l10n.labelDocumentNo, data.documentNumber),
                  if (data.nationality != null)
                    _buildField(context.l10n.labelNationality, data.nationality!),
                  _buildField(context.l10n.labelDateOfBirth,
                      MrzUtils.formatDisplayDate(data.dateOfBirth, isDob: true)),
                  if (data.sex != null && data.sex!.isNotEmpty)
                    _buildField(context.l10n.labelSex, data.sex!),
                  _buildField(context.l10n.labelDateOfExpiry,
                      MrzUtils.formatDisplayDate(data.dateOfExpiry)),
                ],
              ),
            ),
          ],
        ),
        // VIZ capture status
        _buildVizStatusRow(cameraState),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  ref.read(mrzCameraProvider.notifier).reset();
                  for (final c in _frameCandidates) {
                    c.clear();
                  }
                  _frameCandidates.clear();
                  if (_cameraController != null && !_isStreamActive) {
                    _startImageStream();
                  }
                },
                child: Text(context.l10n.mrzCameraButtonRescan),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isVizCapturing(cameraState)
                    ? null
                    : () => _onUseData(data),
                child: _isVizCapturing(cameraState)
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.l10n.mrzCameraButtonUseData),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMrzPreviewCard(String line1, String line2) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$line1\n$line2',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 9,
          letterSpacing: 0.5,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildFacePreview(MrzCameraState cameraState) {
    final colorScheme = Theme.of(context).colorScheme;
    final faceBytes = cameraState.vizCapture?.vizFaceImageBytes;
    final isDetecting =
        cameraState.vizCaptureStatus == VizCaptureStatus.idle ||
            cameraState.vizCaptureStatus == VizCaptureStatus.detectingFace;

    return Container(
      width: 64,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: faceBytes != null
              ? colorScheme.primary
              : colorScheme.outlineVariant,
          width: 2,
        ),
        color: colorScheme.surfaceContainerHighest,
      ),
      clipBehavior: Clip.antiAlias,
      child: faceBytes != null && faceBytes.isNotEmpty
          ? Image.memory(
              faceBytes,
              fit: BoxFit.cover,
              semanticLabel: context.l10n.semanticFacePreview,
              errorBuilder: (_, __, ___) => Icon(
                Icons.person,
                size: 32,
                color: colorScheme.outlineVariant,
              ),
            )
          : isDetecting
              ? Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.outline,
                    ),
                  ),
                )
              : Icon(
                  Icons.person_off,
                  size: 32,
                  color: colorScheme.outlineVariant,
                ),
    );
  }

  Widget _buildVizStatusRow(MrzCameraState cameraState) {
    final IconData icon;
    final Color color;
    final String text;

    switch (cameraState.vizCaptureStatus) {
      case VizCaptureStatus.idle:
      case VizCaptureStatus.detectingFace:
        icon = Icons.face;
        color = Theme.of(context).colorScheme.outline;
        text = context.l10n.mrzCameraDetectingFace;
      case VizCaptureStatus.ready:
        final quality = cameraState.vizCapture?.qualityMetrics;
        icon = Icons.face;
        color = Theme.of(context).colorScheme.primary;
        if (quality != null && quality.issues.isNotEmpty) {
          text = context.l10n.mrzCameraFaceCapturedWithIssue(quality.issues.first.name);
        } else {
          text = context.l10n.mrzCameraFaceCaptured;
        }
      case VizCaptureStatus.noFace:
        icon = Icons.face_retouching_off;
        color = Theme.of(context).colorScheme.error;
        text = context.l10n.mrzCameraNoFaceDetected;
      case VizCaptureStatus.error:
        icon = Icons.warning_amber;
        color = Theme.of(context).colorScheme.error;
        text = context.l10n.mrzCameraFaceDetectionFailed;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                ),
          ),
          if (cameraState.vizCaptureStatus == VizCaptureStatus.detectingFace)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}

/// Paints a semi-transparent overlay with a clear window for passport page scanning.
class _PassportOverlayPainter extends CustomPainter {
  final double boxWidth;
  final double boxHeight;

  _PassportOverlayPainter({required this.boxWidth, required this.boxHeight});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black54;

    // Draw semi-transparent overlay
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Cut out the passport page window
    final windowRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: boxWidth,
      height: boxHeight,
    );
    final windowPath = Path()
      ..addRRect(
          RRect.fromRectAndRadius(windowRect, const Radius.circular(8)));

    final combinedPath =
        Path.combine(PathOperation.difference, overlayPath, windowPath);

    canvas.drawPath(combinedPath, paint);
  }

  @override
  bool shouldRepaint(covariant _PassportOverlayPainter oldDelegate) =>
      oldDelegate.boxWidth != boxWidth || oldDelegate.boxHeight != boxHeight;
}

/// A cached NV21 preview frame with pre-computed quality metrics.
class _FrameCandidate {
  final Uint8List nv21;
  final int width;
  final int height;
  final double glareScore;
  final double blurScore;
  final double compositeScore;

  _FrameCandidate({
    required this.nv21,
    required this.width,
    required this.height,
    required this.glareScore,
    required this.blurScore,
    required this.compositeScore,
  });

  /// Zero-fills the NV21 buffer for secure disposal.
  void clear() => nv21.fillRange(0, nv21.length, 0);
}
