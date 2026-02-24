import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:logging/logging.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

final _log = Logger('FaceEmbeddingService');

/// Abstraction for face embedding generation to enable testing.
abstract class FaceEmbeddingService {
  /// Generates a face embedding vector from face image bytes (JPEG).
  /// Returns a normalized embedding vector.
  Future<List<double>> generateEmbedding(Uint8List faceImageBytes);

  /// Preloads the model so that the first generateEmbedding() call is fast.
  /// No-op if already loaded. Safe to call multiple times.
  Future<void> preload();

  /// Releases resources.
  void close();
}

/// Calculates cosine similarity between two embedding vectors.
/// Returns a value between -1.0 and 1.0 (higher = more similar).
double cosineSimilarity(List<double> a, List<double> b) {
  if (a.length != b.length || a.isEmpty) return 0;

  double dotProduct = 0;
  double normA = 0;
  double normB = 0;

  for (int i = 0; i < a.length; i++) {
    dotProduct += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }

  final denominator = sqrt(normA) * sqrt(normB);
  if (denominator == 0) return 0;

  return dotProduct / denominator;
}

/// TFLite MobileFaceNet implementation for on-device face embedding.
///
/// Model: MobileFaceNet (112x112 input, 192-dimensional embedding output).
/// PII never leaves the device.
class TfLiteFaceEmbeddingService implements FaceEmbeddingService {
  static const int _inputSize = 112;
  static const int _embeddingSize = 192;
  static const String _modelAssetPath = 'assets/models/mobilefacenet.tflite';

  Interpreter? _interpreter;

  /// Loads the TFLite model. Must be called before generateEmbedding().
  Future<void> initialize() async {
    try {
      _interpreter = await Interpreter.fromAsset(_modelAssetPath);
      _log.fine('MobileFaceNet model loaded');
    } catch (e) {
      _log.warning('Failed to load MobileFaceNet model: $e');
      rethrow;
    }
  }

  @override
  Future<void> preload() async {
    if (_interpreter == null) {
      await initialize();
    }
  }

  @override
  Future<List<double>> generateEmbedding(Uint8List faceImageBytes) async {
    if (_interpreter == null) {
      await initialize();
    }

    // Decode and preprocess the face image
    final input = _preprocess(faceImageBytes);

    // Run inference
    final output = List.filled(_embeddingSize, 0.0).reshape([1, _embeddingSize]);
    _interpreter!.run(input, output);

    // Extract and normalize the embedding
    final embedding = List<double>.from(output[0] as List);
    return _normalize(embedding);
  }

  /// Preprocesses face image: resize to 112x112, normalize to [-1, 1].
  List<List<List<List<double>>>> _preprocess(Uint8List imageBytes) {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw Exception('Failed to decode face image for embedding');
    }

    // Resize to 112x112
    final resized = img.copyResize(
      decoded,
      width: _inputSize,
      height: _inputSize,
      interpolation: img.Interpolation.linear,
    );

    // Convert to 4D tensor [1, 112, 112, 3] with values normalized to [-1, 1]
    final input = List.generate(
      1,
      (_) => List.generate(
        _inputSize,
        (y) => List.generate(
          _inputSize,
          (x) {
            final pixel = resized.getPixel(x, y);
            return [
              (pixel.r.toDouble() - 127.5) / 127.5,
              (pixel.g.toDouble() - 127.5) / 127.5,
              (pixel.b.toDouble() - 127.5) / 127.5,
            ];
          },
        ),
      ),
    );

    return input;
  }

  /// L2-normalizes the embedding vector.
  List<double> _normalize(List<double> embedding) {
    double norm = 0;
    for (final v in embedding) {
      norm += v * v;
    }
    norm = sqrt(norm);
    if (norm == 0) return embedding;

    return embedding.map((v) => v / norm).toList();
  }

  @override
  void close() {
    _interpreter?.close();
    _interpreter = null;
  }
}
