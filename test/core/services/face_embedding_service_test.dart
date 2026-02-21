import 'dart:math';

import 'package:eid_reader/core/services/face_embedding_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('cosineSimilarity', () {
    test('identical vectors return 1.0', () {
      final a = [1.0, 0.0, 0.0];
      final b = [1.0, 0.0, 0.0];
      expect(cosineSimilarity(a, b), closeTo(1.0, 1e-10));
    });

    test('opposite vectors return -1.0', () {
      final a = [1.0, 0.0, 0.0];
      final b = [-1.0, 0.0, 0.0];
      expect(cosineSimilarity(a, b), closeTo(-1.0, 1e-10));
    });

    test('orthogonal vectors return 0.0', () {
      final a = [1.0, 0.0, 0.0];
      final b = [0.0, 1.0, 0.0];
      expect(cosineSimilarity(a, b), closeTo(0.0, 1e-10));
    });

    test('similar vectors return high similarity', () {
      final a = [1.0, 0.9, 0.8];
      final b = [1.0, 0.85, 0.75];
      final similarity = cosineSimilarity(a, b);
      expect(similarity, greaterThan(0.99));
    });

    test('empty vectors return 0.0', () {
      expect(cosineSimilarity([], []), 0.0);
    });

    test('zero vectors return 0.0', () {
      final a = [0.0, 0.0, 0.0];
      final b = [1.0, 0.0, 0.0];
      expect(cosineSimilarity(a, b), 0.0);
    });

    test('scaled vectors return 1.0', () {
      final a = [1.0, 2.0, 3.0];
      final b = [2.0, 4.0, 6.0];
      expect(cosineSimilarity(a, b), closeTo(1.0, 1e-10));
    });

    test('handles high-dimensional vectors', () {
      final rng = Random(42);
      final a = List.generate(192, (_) => rng.nextDouble());
      final b = List.generate(192, (_) => rng.nextDouble());

      final similarity = cosineSimilarity(a, b);
      expect(similarity, greaterThanOrEqualTo(-1.0));
      expect(similarity, lessThanOrEqualTo(1.0));
    });
  });
}
