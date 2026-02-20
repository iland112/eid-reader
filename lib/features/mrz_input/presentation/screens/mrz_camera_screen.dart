import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

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

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
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
        ResolutionPreset.medium,
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
    final notifier = ref.read(mrzCameraProvider.notifier);

    // Build InputImage from camera frame
    final inputImage = _buildInputImage(image);
    if (inputImage == null) return;

    await notifier.processImage(inputImage);
  }

  InputImage? _buildInputImage(CameraImage image) {
    if (_cameraController == null) return null;

    final sensorOrientation =
        _cameraController!.description.sensorOrientation;
    final rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    if (rotation == null) return null;

    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  void _onUseData(MrzData data) {
    Navigator.of(context).pop(data);
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
        title: const Text('Scan MRZ'),
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
            ),
          ],
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
      painter: _MrzOverlayPainter(),
      child: const Center(
        child: SizedBox(
          width: 320,
          height: 80,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.fromBorderSide(
                BorderSide(color: Colors.white70, width: 2),
              ),
              borderRadius: BorderRadius.all(Radius.circular(8)),
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
          ? _buildDetectedPanel(cameraState.detectedMrz!)
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
          'Position the MRZ area of your passport within the frame',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDetectedPanel(MrzData data) {
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
        _buildField('Document No.', data.documentNumber),
        _buildField('Date of Birth', data.dateOfBirth),
        _buildField('Date of Expiry', data.dateOfExpiry),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  ref.read(mrzCameraProvider.notifier).reset();
                },
                child: const Text('Rescan'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _onUseData(data),
                child: const Text('Use This Data'),
              ),
            ),
          ],
        ),
      ],
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

/// Paints a semi-transparent overlay with a clear window for MRZ scanning.
class _MrzOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black54;

    // Draw semi-transparent overlay
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Cut out the MRZ window
    final windowRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: 320,
      height: 80,
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
