import 'dart:io';

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

  // Cached last preview frame for VIZ face pre-detection (Step 2 optimization)
  Uint8List? _lastPreviewNv21;
  int _lastPreviewWidth = 0;
  int _lastPreviewHeight = 0;
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
            () => _initError = 'Camera permission denied. Please allow camera access to scan MRZ.');
        return;
      }
      if (status.isPermanentlyDenied) {
        setState(() =>
            _initError = 'Camera permission permanently denied. Please enable it in Settings.');
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _initError = 'No cameras available');
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
      setState(() => _initError = 'Camera initialization failed');
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

      // Build InputImage from camera frame (includes MRZ ROI crop)
      final inputImage = _buildInputImage(image);
      if (inputImage == null) {
        _log.fine('Frame skipped: _buildInputImage returned null');
        return;
      }

      // Cache un-cropped NV21 for preview face detection (only after first
      // MRZ candidate to avoid unnecessary copies).
      final frameCount = ref.read(mrzCameraProvider).debugFrameCount;
      if (frameCount > 0) {
        final Uint8List nv21;
        if (image.format.group == ImageFormatGroup.nv21) {
          nv21 = image.planes.first.bytes;
        } else if (image.format.group == ImageFormatGroup.yuv420) {
          nv21 = _yuv420ToNv21(image);
        } else {
          nv21 = Uint8List(0);
        }
        if (nv21.isNotEmpty) {
          _lastPreviewNv21 = Uint8List.fromList(nv21);
          _lastPreviewWidth = image.width;
          _lastPreviewHeight = image.height;
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

  /// Captures a high-resolution still image for VIZ face detection.
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

      // Stop the image stream before taking a picture.
      await _cameraController!.stopImageStream();
      _isStreamActive = false;

      // Run preview-frame face detection IN PARALLEL with the 300ms
      // stabilization delay — effectively free face pre-detection.
      Rect? previewFaceRect;
      Size? previewSize;
      final rotationValue =
          InputImageRotationValue.fromRawValue(rotationCompensation);

      if (_lastPreviewNv21 != null && rotationValue != null) {
        // InputImageMetadata.size must describe the RAW buffer layout
        // (before rotation). ML Kit uses this + bytesPerRow to read pixels.
        final rawSize = Size(
          _lastPreviewWidth.toDouble(),
          _lastPreviewHeight.toDouble(),
        );
        // previewSize describes the ROTATED coordinate system that ML Kit
        // returns face coordinates in. For 90°/270°, width and height swap.
        final bool swapDims =
            rotationCompensation == 90 || rotationCompensation == 270;
        previewSize = Size(
          swapDims
              ? _lastPreviewHeight.toDouble()
              : _lastPreviewWidth.toDouble(),
          swapDims
              ? _lastPreviewWidth.toDouble()
              : _lastPreviewHeight.toDouble(),
        );
        final previewInputImage = InputImage.fromBytes(
          bytes: _lastPreviewNv21!,
          metadata: InputImageMetadata(
            size: rawSize,
            rotation: rotationValue,
            format: InputImageFormat.nv21,
            bytesPerRow: _lastPreviewWidth,
          ),
        );
        final faceService = ref.read(faceDetectionServiceProvider);
        if (faceService != null) {
          final results = await Future.wait([
            faceService.detectFaces(previewInputImage),
            Future.delayed(const Duration(milliseconds: 300)),
          ]);
          final faceRects = results[0] as List<Rect>;
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
        } else {
          await Future.delayed(const Duration(milliseconds: 300));
        }
        _lastPreviewNv21 = null; // Free memory
      } else {
        await Future.delayed(const Duration(milliseconds: 300));
      }
      _log.fine('VIZ capture: stream stopped (${sw.elapsedMilliseconds}ms)');

      final xFile = await _cameraController!.takePicture();
      final imageBytes = await File(xFile.path).readAsBytes();
      _log.info(
        'VIZ capture: picture taken, ${imageBytes.length} bytes '
        '(${sw.elapsedMilliseconds}ms)',
      );

      // Build InputImage from the still file
      final inputImage = InputImage.fromFilePath(xFile.path);

      final notifier = ref.read(mrzCameraProvider.notifier);
      await notifier.captureViz(
        imageBytes: Uint8List.fromList(imageBytes),
        inputImage: inputImage,
        rotationCompensation: rotationCompensation,
        previewFaceRect: previewFaceRect,
        previewSize: previewSize,
      );

      _log.info('VIZ capture: completed (${sw.elapsedMilliseconds}ms)');

      // Clean up the temp file
      try {
        await File(xFile.path).delete();
      } catch (_) {}
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
        'crop=${cropped.width}x${cropped.height} '
        '(${cropped.bytes.length} bytes)',
      );
    }

    return InputImage.fromBytes(
      bytes: cropped.bytes,
      metadata: InputImageMetadata(
        size: Size(cropped.width.toDouble(), cropped.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: cropped.width,
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
          const SnackBar(content: Text('Flashlight not available')),
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
        title: const Text('Scan Passport'),
        actions: [
          if (kDebugMode)
            IconButton(
              icon: Icon(
                _showDebugLog ? Icons.bug_report : Icons.bug_report_outlined,
              ),
              tooltip: _showDebugLog ? 'Hide debug log' : 'Show debug log',
              onPressed: () => setState(() => _showDebugLog = !_showDebugLog),
            ),
          if (_isInitialized)
            IconButton(
              icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off),
              tooltip: _isTorchOn ? 'Turn off flashlight' : 'Turn on flashlight',
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
              if (_initError!.contains('Settings')) ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => openAppSettings(),
                  child: const Text('Open Settings'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (!_isInitialized || _cameraController == null) {
      return const Center(
        child: CircularProgressIndicator(),
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

        return CustomPaint(
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
                    child: const Text(
                      'VIZ',
                      textAlign: TextAlign.center,
                      style: TextStyle(
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (cameraState.isProcessing)
          const LinearProgressIndicator()
        else
          const SizedBox(height: 4),
        const SizedBox(height: 12),
        Text(
          'Position the passport data page within the frame',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
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
              'MRZ Detected',
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
                      'Name',
                      data.givenNames != null && data.givenNames!.isNotEmpty
                          ? '${data.givenNames} ${data.surname}'
                          : data.surname!,
                    ),
                  _buildField('Document No.', data.documentNumber),
                  if (data.nationality != null)
                    _buildField('Nationality', data.nationality!),
                  _buildField('Date of Birth',
                      MrzUtils.formatDisplayDate(data.dateOfBirth, isDob: true)),
                  if (data.sex != null && data.sex!.isNotEmpty)
                    _buildField('Sex', data.sex!),
                  _buildField('Date of Expiry',
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
                  if (_cameraController != null && !_isStreamActive) {
                    _startImageStream();
                  }
                },
                child: const Text('Rescan'),
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
                    : const Text('Use This Data'),
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
        text = 'Detecting face...';
      case VizCaptureStatus.ready:
        final quality = cameraState.vizCapture?.qualityMetrics;
        icon = Icons.face;
        color = Theme.of(context).colorScheme.primary;
        if (quality != null && quality.issues.isNotEmpty) {
          text = 'Face captured (${quality.issues.first})';
        } else {
          text = 'Face captured';
        }
      case VizCaptureStatus.noFace:
        icon = Icons.face_retouching_off;
        color = Theme.of(context).colorScheme.error;
        text = 'No face detected';
      case VizCaptureStatus.error:
        icon = Icons.warning_amber;
        color = Theme.of(context).colorScheme.error;
        text = 'Face detection failed';
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
