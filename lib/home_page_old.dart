import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'l10n/app_localizations.dart';
import 'language_provider.dart';
import 'services/firebase_service.dart';
import 'services/pdf_report_service.dart';
import 'pages/patient_history_page.dart';

enum ConnectionStep {
  initial,
  connecting,
  selectPosition,
  listening,
  results,
}

enum StethPosition {
  lungs,
  heart,
}

class HomePage extends StatefulWidget {
  final LanguageProvider languageProvider;

  const HomePage({super.key, required this.languageProvider});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  ConnectionStep _currentStep = ConnectionStep.initial;
  StethPosition? _selectedPosition;
  int? _riskPercentage;
  bool _isConnected = false;
  int _listeningCountdown = 5;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _showToast(String message, {Color? backgroundColor, IconData? icon}) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => ToastWidget(
        message: message,
        backgroundColor: backgroundColor,
        icon: icon,
        onDismiss: () => overlayEntry.remove(),
      ),
    );

    overlay.insert(overlayEntry);
  }

  void _showDiseaseSelectionDialog() {
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            l10n?.selectDiseaseCategory ?? 'Select Disease Category',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n?.chooseAnalysisType ??
                    'Choose the type of analysis you want to perform:',
                style: TextStyle(color: Colors.grey[400]),
              ),
              const SizedBox(height: 20),

              // Pneumonia & TB Option
              InkWell(
                onTap: () {
                  Navigator.of(context).pop();
                  _loadModel(DiseaseCategory.pneumoniaTB);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.healing, color: Colors.blue, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        l10n?.pneumoniaTB ?? 'Pneumonia & TB Detection',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // COPD & Asthma Option
              InkWell(
                onTap: () {
                  Navigator.of(context).pop();
                  _loadModel(DiseaseCategory.copdAsthma);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.green),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.air, color: Colors.green, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        l10n?.copdAsthma ?? 'COPD & Asthma Detection',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadModel(DiseaseCategory category) async {
    setState(() {
      _isModelLoaded = false;
    });

    print('Loading ${category.name} model...');
    bool success = await _model.loadModel(category);

    setState(() {
      _isModelLoaded = success;
    });

    if (mounted) {
      final l10n = AppLocalizations.of(context);
      final categoryName = category == DiseaseCategory.pneumoniaTB
          ? (l10n?.pneumoniaTB ?? 'Pneumonia & TB')
          : (l10n?.copdAsthma ?? 'COPD & Asthma');

      _showToast(
        success
            ? '${categoryName} model loaded successfully'
            : 'Failed to load ${categoryName} model',
        backgroundColor: success ? Colors.green : Colors.red,
        icon: success ? Icons.check_circle : Icons.error,
      );
    }
  }

  Future<void> _analyzeAudio() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_isModelLoaded) {
      if (mounted) {
        _showToast(
          l10n.modelNotLoaded,
          backgroundColor: Colors.orange,
          icon: Icons.warning,
        );
      }
      return;
    }

    setState(() {
      _isAnalyzing = true;
    });

    try {
      print('Starting audio analysis...');

      // 🧵 THREADING STRATEGY:
      // 1. Model loading: Main thread (required for asset access)
      // 2. Model inference: Main thread with yielding (required for TFLite + assets)
      // 3. Result processing: Separate isolate (compute function)

      // Step 1: Model prediction with yielding (background-friendly on main thread)
      Map<String, dynamic> rawResult = await _model
          .predictWithYielding([])
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception('Analysis timed out after 15 seconds');
            },
          );

      // Step 2: Process results in isolate (heavy computation)
      print('Processing results in separate thread...');
      Map<String, dynamic> processedResult = await compute(
        _processAnalysisResults,
        rawResult,
      );

      setState(() {
        _lastResult = processedResult;
        _isAnalyzing = false;
      });

      print('Analysis complete: ${processedResult['predicted_class']}');

      // Show popup with all dataset results
      _showDatasetResults();
    } catch (e) {
      print('Analysis failed: $e');
      setState(() {
        _isAnalyzing = false;
      });

      _showToast(
        l10n.analysisFailed(e.toString()),
        backgroundColor: Colors.red,
        icon: Icons.error,
      );
    } finally {
      // Ensure _isAnalyzing is always reset, even if there's an uncaught exception
      if (_isAnalyzing) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  Future<void> _saveDiagnosisToFirebase() async {
    if (_lastResult == null) return;

    try {
      final userId = FirebaseService().currentUserId;
      if (userId == null) {
        _showToast('User not logged in', backgroundColor: Colors.red, icon: Icons.error);
        return;
      }

      final diagnosis = _lastResult!['predicted_class'] ?? 'Unknown';
      final heartRate = 72.0; // Default heart rate, can be updated with actual measurement

      await FirebaseService().addDiagnosisRecord(
        uid: userId,
        diagnosis: diagnosis,
        heartRate: heartRate,
        notes: 'Confidence: ${_lastResult!['confidence']}',
      );

      _showToast(
        'Diagnosis saved successfully',
        backgroundColor: Colors.green,
        icon: Icons.check_circle,
      );
    } catch (e) {
      _showToast(
        'Failed to save diagnosis: $e',
        backgroundColor: Colors.red,
        icon: Icons.error,
      );
    }
  }

  Future<void> _generateAndSharePDF() async {
    try {
      final userId = FirebaseService().currentUserId;
      if (userId == null) {
        _showToast('User not logged in', backgroundColor: Colors.red, icon: Icons.error);
        return;
      }

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          backgroundColor: Colors.black87,
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Generating PDF report...', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );

      // Get user profile
      final profile = await FirebaseService().getUserProfile(userId);
      if (profile == null) {
        if (mounted) Navigator.pop(context);
        _showToast('Profile not found', backgroundColor: Colors.red, icon: Icons.error);
        return;
      }

      // Generate PDF
      final pdfFile = await PdfReportService.generateMedicalReport(profile);

      if (mounted) Navigator.pop(context);

      // Share PDF
      await PdfReportService.sharePdf(pdfFile);

      _showToast(
        'PDF report generated',
        backgroundColor: Colors.green,
        icon: Icons.check_circle,
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showToast(
        'Failed to generate PDF: $e',
        backgroundColor: Colors.red,
        icon: Icons.error,
      );
    }
  }

  void _showDatasetResults() async {
    // Show loading first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          backgroundColor: Colors.grey,
          title: Text(
            l10n.loadingAudioFiles,
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          ),
        );
      },
    );

    try {
      // ✅ Load all audio file results with yielding (background-friendly but on main thread)
      List<Map<String, dynamic>> allResults = await _model.getAllAudioResults();

      // Close loading dialog
      Navigator.of(context).pop();

      // Show results dialog
      showDialog(
        context: context,
        builder: (BuildContext context) {
          final l10n = AppLocalizations.of(context)!;
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            title: Text(
              l10n.audioDatasetResults,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: ListView.builder(
                itemCount: allResults.length,
                itemBuilder: (context, index) {
                  var result = allResults[index];
                  return Card(
                    color: Colors.grey[800],
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            result['name'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildResultItem(
                                'Pneumonia',
                                '${result['pneumonia_percent']}%',
                                Colors.red[300]!,
                              ),
                              _buildResultItem(
                                'TB',
                                '${result['tb_percent']}%',
                                Colors.orange[300]!,
                              ),
                              _buildResultItem(
                                'Normal',
                                '${result['normal_percent']}%',
                                Colors.green[300]!,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _saveDiagnosisToFirebase();
                },
                icon: const Icon(Icons.save, color: Colors.green),
                label: const Text('Save', style: TextStyle(color: Colors.green)),
              ),
              TextButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _generateAndSharePDF();
                },
                icon: const Icon(Icons.picture_as_pdf, color: Colors.orange),
                label: const Text('PDF', style: TextStyle(color: Colors.orange)),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.close, style: const TextStyle(color: Colors.blue)),
              ),
            ],
          );
        },
      );
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();

      // Show error
      _showToast(
        'Failed to load audio files: $e',
        backgroundColor: Colors.red,
        icon: Icons.error,
      );
    }
  }

  Widget _buildResultItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageSelector(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.language, color: Colors.white70),
      onSelected: (String languageCode) {
        widget.languageProvider.setLanguage(languageCode);
      },
      itemBuilder: (BuildContext context) {
        return LanguageProvider.supportedLanguages.entries.map((entry) {
          final isSelected =
              widget.languageProvider.currentLanguageCode == entry.key;
          return PopupMenuItem<String>(
            value: entry.key,
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.check : Icons.language,
                  color: isSelected ? Colors.blue : Colors.white70,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  entry.value,
                  style: TextStyle(
                    color: isSelected ? Colors.blue : Colors.white,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/icon/co-logo.png', width: 32, height: 32),
            const SizedBox(width: 8),
            Text(
              l10n.appTitle,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Patient History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PatientHistoryPage(),
                ),
              );
            },
          ),
          _buildLanguageSelector(context),
        ],
      ),
      body: Column(
        children: [
          // Top: ECG Waveform
          Container(
            height: 200,
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.ecgWaveform,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.circle, color: Colors.green, size: 12),
                          const SizedBox(width: 5),
                          Text(
                            l10n.live,
                            style: TextStyle(color: Colors.green, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _realtimeAudioData.isEmpty
                      ? AnimatedBuilder(
                          animation: _waveAnimation,
                          builder: (context, child) {
                            return CustomPaint(
                              painter: WaveformPainter(_waveAnimation.value, []),
                              size: const Size(double.infinity, 150),
                            );
                          },
                        )
                      : CustomPaint(
                          painter: WaveformPainter(0, _realtimeAudioData),
                          size: const Size(double.infinity, 150),
                        ),
                ),
              ],
            ),
          ),

          // Middle: Connect Stethoscope Button
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isStethoscopeConnected
                          ? Colors.green.withOpacity(0.2)
                          : Colors.grey.withOpacity(0.2),
                      border: Border.all(
                        color: _isStethoscopeConnected
                            ? Colors.green
                            : Colors.grey,
                        width: 3,
                      ),
                    ),
                    child: Icon(
                      Icons.hearing,
                      size: 60,
                      color: _isStethoscopeConnected
                          ? Colors.green
                          : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _isStethoscopeConnected
                        ? l10n.stethoscopeConnected
                        : l10n.connectDigitalStethoscope,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _isStethoscopeConnected
                          ? Colors.green
                          : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: _showConnectionDialog,
                    icon: Icon(
                      _isStethoscopeConnected ? Icons.link_off : Icons.link,
                    ),
                    label: Text(
                      _isStethoscopeConnected
                          ? l10n.disconnect
                          : l10n.connectStethoscope,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isStethoscopeConnected
                          ? Colors.red
                          : Colors.blue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom: AI Analysis Button
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isAnalyzing ? null : _startAIAnalysis,
                    icon: _isAnalyzing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.analytics, color: Colors.white),
                    label: Text(
                      _isAnalyzing ? l10n.analyzing : l10n.startAIAnalysis,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isModelLoaded
                          ? Colors.blueAccent
                          : Colors.grey,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                    ),
                  ),
                ),
                if (_lastResult != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.grey[850]?.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildRiskIndicator('Pneumonia', _getPneumoniaRisk()),
                        _buildRiskIndicator('TB', _getTBRisk()),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _connectViaWiFi() async {
    // TODO: Implement WiFi connection logic
    setState(() {
      _currentStep = ConnectionStep.connecting;
    });

    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isConnected = true;
      _currentStep = ConnectionStep.selectPosition;
    });

    _showToast(
      'Connected via WiFi',
      backgroundColor: Colors.green,
      icon: Icons.check_circle,
    );
  }

  void _selectPosition(StethPosition position) {
    setState(() {
      _selectedPosition = position;
      _currentStep = ConnectionStep.listening;
      _listeningCountdown = 5;
    });

    // Start countdown
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _listeningCountdown--;
      });

      if (_listeningCountdown <= 0) {
        timer.cancel();
        _showResults();
      }
    });
  }

  void _showResults() {
    // Generate random risk percentage (5% or 10%)
    final random = math.Random();
    final riskPercentage = random.nextBool() ? 5 : 10;

    setState(() {
      _riskPercentage = riskPercentage;
      _currentStep = ConnectionStep.results;
    });
  }

  void _resetFlow() {
    setState(() {
      _currentStep = ConnectionStep.initial;
      _selectedPosition = null;
      _riskPercentage = null;
      _isConnected = false;
      _listeningCountdown = 5;
    });
    _countdownTimer?.cancel();
  }

  void _showToast(String message, {Color? backgroundColor, IconData? icon}) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => ToastWidget(
        message: message,
        backgroundColor: backgroundColor,
        icon: icon,
        onDismiss: () => overlayEntry.remove(),
      ),
    );

    overlay.insert(overlayEntry);
  }

  Widget _buildLanguageSelector(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.language, color: Colors.white70),
      onSelected: (String languageCode) {
        widget.languageProvider.setLanguage(languageCode);
      },
      itemBuilder: (BuildContext context) {
        return LanguageProvider.supportedLanguages.entries.map((entry) {
          final isSelected =
              widget.languageProvider.currentLanguageCode == entry.key;
          return PopupMenuItem<String>(
            value: entry.key,
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.check : Icons.language,
                  color: isSelected ? Colors.green : Colors.white70,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  entry.value,
                  style: TextStyle(
                    color: isSelected ? Colors.green : Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
    );
  }
}

// Custom Waveform Painter for animated ECG waveforms
class WaveformPainter extends CustomPainter {
  final double animationValue;
  final List<double> audioData;

  WaveformPainter(this.animationValue, this.audioData);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final width = size.width;
    final height = size.height;
    final centerY = height / 2;

    if (audioData.isEmpty) {
      // Create animated dummy ECG-like waveform when no real data
      for (double x = 0; x <= width; x += 2) {
        final normalizedX = x / width;
        final frequency = 2 * math.pi * 2; // ECG frequency

        // Create characteristic ECG pattern
        double y;
        final phase = frequency * normalizedX + animationValue;
        final heartBeat = math.sin(phase);

        // Add sharp spikes for QRS complex
        if (heartBeat > 0.7) {
          y = centerY - height * 0.3 * (1 + math.sin(phase * 10));
        } else if (heartBeat < -0.7) {
          y = centerY + height * 0.1 * math.sin(phase * 5);
        } else {
          y = centerY + heartBeat * height * 0.1;
        }

        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
    } else {
      // Display real audio data (normalized between -1 and 1)
      final samplesPerPixel = math.max(1, audioData.length / width).ceil();
      
      for (int pixelX = 0; pixelX < width.toInt(); pixelX++) {
        final sampleIndex = (pixelX * samplesPerPixel).clamp(0, audioData.length - 1);
        
        // Get the sample value (already normalized between -1 and 1)
        final normalizedValue = audioData[sampleIndex];
        
        // Map to screen coordinates
        // Scale by 0.8 to leave some margin at top and bottom
        final y = centerY - (normalizedValue * height * 0.4);
        
        if (pixelX == 0) {
          path.moveTo(pixelX.toDouble(), y);
        } else {
          path.lineTo(pixelX.toDouble(), y);
        }
      }
    }

    canvas.drawPath(path, paint);

    // Draw grid lines
    final gridPaint = Paint()
      ..color = Colors.green.withOpacity(0.2)
      ..strokeWidth = 1;

    // Horizontal grid lines
    for (int i = 0; i <= 4; i++) {
      final y = (height / 4) * i;
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
    }

    // Vertical grid lines
    for (int i = 0; i <= 8; i++) {
      final x = (width / 8) * i;
      canvas.drawLine(Offset(x, 0), Offset(x, height), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ToastWidget extends StatefulWidget {
  final String message;
  final Color? backgroundColor;
  final IconData? icon;
  final VoidCallback onDismiss;

  const ToastWidget({
    Key? key,
    required this.message,
    this.backgroundColor,
    this.icon,
    required this.onDismiss,
  }) : super(key: key);

  @override
  State<ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: -1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    // Auto-dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      _dismiss();
    });
  }

  void _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slideAnimation.value * 100),
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: Material(
                borderRadius: BorderRadius.circular(24),
                elevation: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: widget.backgroundColor ?? Colors.grey[800],
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, color: Colors.white, size: 20),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Text(
                          widget.message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _dismiss,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white70,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
