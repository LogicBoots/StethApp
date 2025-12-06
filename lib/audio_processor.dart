import 'dart:typed_data';

class AudioProcessor {
  /// Process raw audio samples for model input
  /// Input: normalized audio data [-1.0, 1.0]
  /// Output: processed data ready for TFLite model
  static List<double> prepareForModel(
    List<double> audioData, {
    int targetSampleCount = 8000,
    bool normalize = true,
  }) {
    List<double> processed = List<double>.from(audioData);

    // Resample if needed
    if (processed.length != targetSampleCount) {
      processed = resample(processed, targetSampleCount);
    }

    // Additional normalization if needed
    if (normalize) {
      processed = normalizeAudio(processed);
    }

    return processed;
  }

  /// Resample audio to target sample count
  static List<double> resample(List<double> input, int targetLength) {
    if (input.isEmpty) return [];
    if (input.length == targetLength) return input;

    final output = List<double>.filled(targetLength, 0.0);
    final ratio = input.length / targetLength;

    for (int i = 0; i < targetLength; i++) {
      final sourceIndex = (i * ratio).floor();
      final nextIndex = (sourceIndex + 1).clamp(0, input.length - 1);
      final fraction = (i * ratio) - sourceIndex;

      // Linear interpolation
      output[i] = input[sourceIndex] * (1 - fraction) +
          input[nextIndex] * fraction;
    }

    return output;
  }

  /// Normalize audio to [-1.0, 1.0] range
  static List<double> normalizeAudio(List<double> audio) {
    if (audio.isEmpty) return [];

    // Find max absolute value
    double maxAbs = 0.0;
    for (final sample in audio) {
      final abs = sample.abs();
      if (abs > maxAbs) maxAbs = abs;
    }

    // Avoid division by zero
    if (maxAbs == 0.0) return audio;

    // Normalize
    return audio.map((sample) => sample / maxAbs).toList();
  }

  /// Convert normalized float samples to 16-bit PCM
  static Int16List toInt16PCM(List<double> normalized) {
    final pcm = Int16List(normalized.length);
    for (int i = 0; i < normalized.length; i++) {
      // Clamp to [-1.0, 1.0] and scale to int16 range
      final clamped = normalized[i].clamp(-1.0, 1.0);
      pcm[i] = (clamped * 32767).round();
    }
    return pcm;
  }

  /// Convert 16-bit PCM to normalized float samples
  static List<double> fromInt16PCM(Int16List pcm) {
    return pcm.map((sample) => sample / 32768.0).toList();
  }

  /// Apply a simple low-pass filter to reduce noise
  static List<double> lowPassFilter(List<double> audio, {double alpha = 0.1}) {
    if (audio.isEmpty) return [];

    final filtered = List<double>.filled(audio.length, 0.0);
    filtered[0] = audio[0];

    for (int i = 1; i < audio.length; i++) {
      filtered[i] = alpha * audio[i] + (1 - alpha) * filtered[i - 1];
    }

    return filtered;
  }

  /// Calculate RMS (Root Mean Square) of audio signal
  static double calculateRMS(List<double> audio) {
    if (audio.isEmpty) return 0.0;

    double sumSquares = 0.0;
    for (final sample in audio) {
      sumSquares += sample * sample;
    }

    return (sumSquares / audio.length).abs().toDouble();
  }

  /// Detect if audio contains meaningful signal (not just noise/silence)
  static bool hasSignificantAudio(List<double> audio, {double threshold = 0.01}) {
    final rms = calculateRMS(audio);
    return rms > threshold;
  }

  /// Split audio into chunks of specified duration
  static List<List<double>> splitIntoChunks(
    List<double> audio,
    int chunkSize, {
    int overlap = 0,
  }) {
    final chunks = <List<double>>[];
    final step = chunkSize - overlap;

    for (int i = 0; i < audio.length - chunkSize + 1; i += step) {
      chunks.add(audio.sublist(i, i + chunkSize));
    }

    return chunks;
  }
}
