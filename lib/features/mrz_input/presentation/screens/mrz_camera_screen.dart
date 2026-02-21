import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/utils/mrz_utils.dart';
import '../../domain/entities/mrz_data.dart';
import '../providers/mrz_camera_provider.dart';

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

  @override
  void initState() {
    super.initState();
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
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _cameraController!.initialize();

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

      // Build InputImage from camera frame
      final inputImage = _buildInputImage(image);
      if (inputImage == null) return;

      await notifier.processImage(inputImage);

      // If MRZ was just detected, capture VIZ
      final state = ref.read(mrzCameraProvider);
      if (state.detectedMrz != null &&
          state.vizCaptureStatus == VizCaptureStatus.idle &&
          !_isCapturingViz) {
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

    try {
      // Stop the image stream before taking a picture
      await _cameraController!.stopImageStream();
      _isStreamActive = false;

      final xFile = await _cameraController!.takePicture();
      final imageBytes = await File(xFile.path).readAsBytes();

      // Build InputImage from the still file
      final inputImage = InputImage.fromFilePath(xFile.path);

      final notifier = ref.read(mrzCameraProvider.notifier);
      await notifier.captureViz(
        imageBytes: Uint8List.fromList(imageBytes),
        inputImage: inputImage,
      );

      // Clean up the temp file
      try {
        await File(xFile.path).delete();
      } catch (_) {}
    } catch (e) {
      // VIZ capture failure is non-fatal; MRZ data is still usable
      if (mounted) {
        setState(() {});
      }
    } finally {
      _isCapturingViz = false;
    }
  }

  InputImage? _buildInputImage(CameraImage image) {
    if (_cameraController == null) return null;

    final sensorOrientation =
        _cameraController!.description.sensorOrientation;
    final rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    if (rotation == null) return null;

    // ML Kit fromBytes only works reliably with NV21 on Android.
    // If camera returns YUV420, convert to NV21 first.
    final Uint8List nv21Bytes;
    if (image.format.group == ImageFormatGroup.nv21) {
      nv21Bytes = image.planes.first.bytes;
    } else if (image.format.group == ImageFormatGroup.yuv420) {
      nv21Bytes = _yuv420ToNv21(image);
    } else {
      return null;
    }

    return InputImage.fromBytes(
      bytes: nv21Bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: image.width,
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

  bool _isVizCapturing(MrzCameraState cameraState) {
    return cameraState.vizCaptureStatus == VizCaptureStatus.idle ||
        cameraState.vizCaptureStatus == VizCaptureStatus.detectingFace;
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

  @override
  void dispose() {
    _cameraController?.stopImageStream().catchError((_) {});
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(mrzCameraProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Passport'),
        actions: [
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
            child: _buildCameraPreview(),
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

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(_cameraController!),
        _buildOverlay(),
      ],
    );
  }

  Widget _buildOverlay() {
    return CustomPaint(
      painter: _PassportOverlayPainter(),
      child: Center(
        child: SizedBox(
          width: 320,
          height: 200,
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
                  'MRZ',
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
        // Debug OCR output
        if (cameraState.debugOcrText != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              cameraState.debugOcrText!,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: Theme.of(context).colorScheme.primary,
              ),
              maxLines: 8,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black54;

    // Draw semi-transparent overlay
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Cut out the passport page window (larger than MRZ-only)
    final windowRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: 320,
      height: 200,
    );
    final windowPath = Path()
      ..addRRect(RRect.fromRectAndRadius(windowRect, const Radius.circular(8)));

    final combinedPath =
        Path.combine(PathOperation.difference, overlayPath, windowPath);

    canvas.drawPath(combinedPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
