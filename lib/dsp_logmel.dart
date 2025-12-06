import 'dart:math' as math;

/// Audio preprocessing for digital stethoscope data
/// Matches features.py exactly: librosa.feature.melspectrogram + librosa.power_to_db
class AudioPreprocessor {
  // Fixed parameters matching features.py exactly
  static const int sampleRate = 16000;
  static const int nMels = 64;
  static const int hopLength = 160; // 10ms
  static const int nFft = 400; // 25ms
  static const int maxFrames = 256; // fixed frame length

  /// Main processing pipeline: PCM -> log-mel spectrogram (matches features.py)
  static List<List<List<List<double>>>> processAudio(List<double> pcmData) {
    print('DEBUG: Starting audio processing...');
    print('DEBUG: Input PCM length: ${pcmData.length}');

    // Step 1: Ensure audio is exactly 1 second (16000 samples)
    if (pcmData.length < sampleRate) {
      pcmData = List<double>.from(pcmData)
        ..addAll(List.filled(sampleRate - pcmData.length, 0.0));
    } else if (pcmData.length > sampleRate) {
      pcmData = pcmData.sublist(0, sampleRate);
    }

    // Step 2: Compute STFT with Hann window (matching librosa)
    List<List<double>> spectrogram = _computeSTFT(pcmData);
    print('DEBUG: STFT frames: ${spectrogram.length}');

    // Step 3: Apply Mel filter bank
    List<List<double>> melSpectrogram = _applyMelFilters(spectrogram);
    print(
      'DEBUG: Mel spectrogram shape: ${melSpectrogram.length} x ${melSpectrogram[0].length}',
    );

    // Step 4: Convert to log scale (power_to_db, ref=max)
    List<List<double>> logMelSpectrogram = _powerToDb(melSpectrogram);
    print('DEBUG: Applied power_to_db conversion');

    // Step 5: Pad or truncate to fixed frame length
    List<List<double>> fixedFrames = _padOrTruncateFrames(logMelSpectrogram);
    print(
      'DEBUG: After padding - shape: ${fixedFrames.length} x ${fixedFrames[0].length}',
    );

    // Step 6: Normalize by dividing by max value (like train_model.py does)
    List<List<double>> normalizedFrames = _normalizeToRange01(fixedFrames);
    print(
      'DEBUG: Final normalized shape: ${normalizedFrames.length} x ${normalizedFrames[0].length}',
    );

    // DEBUG: Print some sample values to check if preprocessing is working
    print('DEBUG: Sample normalized values (should be in [0,1] range):');
    if (normalizedFrames.isNotEmpty && normalizedFrames[0].isNotEmpty) {
      print('  Frame 0: [${normalizedFrames[0].take(5).join(', ')}...]');
      if (normalizedFrames.length > 1) {
        int midFrame = normalizedFrames.length ~/ 2;
        print(
          '  Frame $midFrame: [${normalizedFrames[midFrame].take(5).join(', ')}...]',
        );
      }
      double minVal = normalizedFrames.expand((f) => f).reduce(math.min);
      double maxVal = normalizedFrames.expand((f) => f).reduce(math.max);
      print('  Min value: $minVal');
      print('  Max value: $maxVal');
    }

    // Reshape for model input: [batch_size, n_mels, time_frames, channels]
    // Convert from [n_mels, time_frames] to [1, n_mels, time_frames, 1]
    List<List<List<List<double>>>> result = [
      List.generate(
        nMels,
        (i) => List.generate(maxFrames, (j) => [normalizedFrames[i][j]]),
      ),
    ];

    print(
      'DEBUG: Final tensor shape: [${result.length}, ${result[0].length}, ${result[0][0].length}, ${result[0][0][0].length}]',
    );

    return result;
  }

  /// Compute STFT with Hann window (matching librosa)
  static List<List<double>> _computeSTFT(List<double> pcmData) {
    // Apply center padding like librosa (center=True by default)
    int padLength = nFft ~/ 2;
    List<double> paddedAudio = [];

    // Pad beginning with reflection
    for (int i = padLength - 1; i >= 0; i--) {
      if (i + 1 < pcmData.length) {
        paddedAudio.add(pcmData[i + 1]);
      } else {
        paddedAudio.add(0.0);
      }
    }

    // Add original audio
    paddedAudio.addAll(pcmData);

    // Pad end with reflection
    for (
      int i = pcmData.length - 2;
      i > pcmData.length - 2 - padLength && i >= 0;
      i--
    ) {
      paddedAudio.add(pcmData[i]);
    }

    print(
      'DEBUG: Original audio length: ${pcmData.length}, padded length: ${paddedAudio.length}',
    );

    int numFrames = ((paddedAudio.length - nFft) / hopLength).floor() + 1;
    List<List<double>> magnitude = [];

    for (int frame = 0; frame < numFrames; frame++) {
      int start = frame * hopLength;

      if (start + nFft > paddedAudio.length) break;

      List<double> windowed = [];
      for (int i = 0; i < nFft; i++) {
        double hann = 0.5 * (1 - math.cos(2 * math.pi * i / (nFft - 1)));
        windowed.add(paddedAudio[start + i] * hann);
      }

      // DFT for power spectrum (simplified FFT)
      List<double> frameMagnitude = List.filled(nFft ~/ 2 + 1, 0.0);
      for (int k = 0; k < nFft ~/ 2 + 1; k++) {
        double real = 0.0;
        double imag = 0.0;

        for (int n = 0; n < nFft; n++) {
          double angle = -2 * math.pi * k * n / nFft;
          real += windowed[n] * math.cos(angle);
          imag += windowed[n] * math.sin(angle);
        }

        frameMagnitude[k] =
            (real * real + imag * imag) / nFft; // Power, normalized
      }

      magnitude.add(frameMagnitude);
    }

    print('DEBUG: STFT frames after center padding: ${magnitude.length}');

    // Transpose to [freq_bins, time_frames] for mel filter application
    if (magnitude.isEmpty) return [];

    return List.generate(
      magnitude[0].length,
      (i) => List.generate(magnitude.length, (j) => magnitude[j][i]),
    );
  }

  /// Apply mel filter bank to convert to mel scale
  static List<List<double>> _applyMelFilters(List<List<double>> stft) {
    List<List<double>> melFilters = _createMelFilterBank();
    List<List<double>> melSpec = [];

    // stft is [freq_bins, time_frames], we want [n_mels, time_frames]
    for (int t = 0; t < stft[0].length; t++) {
      List<double> melFrame = List.filled(nMels, 0.0);
      for (int m = 0; m < nMels; m++) {
        double sum = 0.0;
        for (int f = 0; f < stft.length; f++) {
          sum += stft[f][t] * melFilters[m][f];
        }
        melFrame[m] = math.max(sum, 1e-10); // Avoid log(0)
      }
      melSpec.add(melFrame);
    }

    // Transpose to [n_mels, time_frames] for consistency
    return List.generate(
      nMels,
      (m) => List.generate(melSpec.length, (t) => melSpec[t][m]),
    );
  }

  /// Create triangular mel filter bank (approximating librosa)
  static List<List<double>> _createMelFilterBank() {
    int freqBins = (nFft / 2).floor() + 1;
    List<List<double>> filters = List.generate(
      nMels,
      (_) => List.filled(freqBins, 0.0),
    );

    double melMin = _hzToMel(0);
    double melMax = _hzToMel(sampleRate / 2);

    List<double> melPoints = [];
    for (int i = 0; i <= nMels + 1; i++) {
      double mel = melMin + (melMax - melMin) * i / (nMels + 1);
      melPoints.add(_melToHz(mel));
    }

    List<int> bins = melPoints
        .map((hz) => (hz * nFft / sampleRate).floor())
        .toList();

    for (int m = 0; m < nMels; m++) {
      int left = bins[m];
      int center = bins[m + 1];
      int right = bins[m + 2];

      // Triangular filter
      for (int b = left; b < center && b < freqBins; b++) {
        if (center > left) {
          filters[m][b] = (b - left) / (center - left);
        }
      }
      for (int b = center; b < right && b < freqBins; b++) {
        if (right > center) {
          filters[m][b] = (right - b) / (right - center);
        }
      }
    }

    // Normalize filters like librosa
    for (int m = 0; m < nMels; m++) {
      double sum = filters[m].reduce((a, b) => a + b);
      if (sum > 0) {
        for (int f = 0; f < freqBins; f++) {
          filters[m][f] /= sum;
        }
      }
    }

    return filters;
  }

  static double _hzToMel(double hz) =>
      2595 * (math.log(1 + hz / 700) / math.ln10);
  static double _melToHz(double mel) => 700 * (math.pow(10, mel / 2595) - 1);

  /// Convert power spectrogram to dB (librosa.power_to_db equivalent)
  /// Uses ref=np.max like features.py
  static List<List<double>> _powerToDb(List<List<double>> melSpec) {
    // Find max value across entire spectrogram (ref=np.max)
    double maxValue = 0.0;
    for (var frame in melSpec) {
      for (var value in frame) {
        if (value > maxValue) maxValue = value;
      }
    }

    if (maxValue == 0.0) maxValue = 1e-10; // Avoid log(0)

    print('DEBUG: Power spectrogram max value: $maxValue');

    // Convert to dB: 10 * log10(S / ref)
    // librosa.power_to_db has top_db=80.0 by default which clips minimum values
    List<List<double>> dbSpec = melSpec.map((frame) {
      return frame.map((value) {
        // Use a small floor to avoid -inf
        double floor = 1e-10;
        value = value > floor ? value : floor;
        double dbValue = 10.0 * math.log(value / maxValue) / math.ln10;

        // Apply top_db clipping like librosa (default top_db=80.0)
        return math.max(dbValue, -80.0);
      }).toList();
    }).toList();

    // Debug: Check dB range
    double dbMin = dbSpec.expand((f) => f).reduce(math.min);
    double dbMax = dbSpec.expand((f) => f).reduce(math.max);
    print('DEBUG: dB range: $dbMin to $dbMax');

    return dbSpec;
  }

  /// Pad or truncate spectrogram to fixed frame length
  static List<List<double>> _padOrTruncateFrames(
    List<List<double>> spectrogram,
  ) {
    // Spectrogram shape is [n_mels, time_frames]
    int currentFrames = spectrogram[0].length;
    print('DEBUG: Input frames: $currentFrames, target: $maxFrames');

    if (currentFrames == maxFrames) {
      return spectrogram;
    } else if (currentFrames > maxFrames) {
      // Truncate - take first maxFrames
      return spectrogram.map((melRow) => melRow.sublist(0, maxFrames)).toList();
    } else {
      // Pad with silence (-80 dB is a common minimum for audio)
      List<List<double>> padded = [];
      for (int m = 0; m < spectrogram.length; m++) {
        List<double> paddedRow = List.from(spectrogram[m]);
        int paddingNeeded = maxFrames - currentFrames;
        paddedRow.addAll(List.filled(paddingNeeded, -80.0));
        padded.add(paddedRow);
      }
      return padded;
    }
  }

  /// Normalize spectrogram to [0,1] range by dividing by max value
  /// This matches the normalization step in train_model.py: feat = feat / np.max(feat)
  static List<List<double>> _normalizeToRange01(
    List<List<double>> spectrogram,
  ) {
    // Find the maximum value across the entire spectrogram
    double maxValue = double.negativeInfinity;
    for (var frame in spectrogram) {
      for (var value in frame) {
        if (value > maxValue) maxValue = value;
      }
    }

    print('DEBUG: Spectrogram max value before normalization: $maxValue');

    // Match Python exactly: if np.max(feat) > 0: feat = feat / np.max(feat)
    if (maxValue > 0) {
      // Normal case: divide by max value
      return spectrogram.map((frame) {
        return frame.map((value) => value / maxValue).toList();
      }).toList();
    } else {
      // When max <= 0, Python does NOTHING - just return as is
      print(
        'DEBUG: Max value <= 0, returning spectrogram unchanged (like Python)',
      );
      return spectrogram;
    }
  }
}
