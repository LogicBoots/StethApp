import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
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

class _HomePageState extends State<HomePage> {
  ConnectionStep _currentStep = ConnectionStep.initial;
  StethPosition? _selectedPosition;
  int? _riskPercentage;
  bool _isConnected = false;
  int _listeningCountdown = 25;
  Timer? _countdownTimer;
  bool _showWaveform = false;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _connectViaWiFi() async {
    // Show connecting state
    setState(() {
      _currentStep = ConnectionStep.connecting;
    });

    // Simulate connection attempt
    await Future.delayed(const Duration(seconds: 2));

    // Connection successful - proceed to position selection
    setState(() {
      _currentStep = ConnectionStep.selectPosition;
      _isConnected = true;
    });

    _showToast(
      'Connected to stethoscope',
      backgroundColor: Colors.green,
      icon: Icons.check_circle,
    );
  }

  void _selectPosition(StethPosition position) {
    setState(() {
      _selectedPosition = position;
      _currentStep = ConnectionStep.listening;
      _listeningCountdown = 25;
      _showWaveform = false;
    });

    // Show waveform after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _currentStep == ConnectionStep.listening) {
        setState(() {
          _showWaveform = true;
        });
      }
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
      _listeningCountdown = 25;
      _showWaveform = false;
    });
    _countdownTimer?.cancel();
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
              CircularProgressIndicator(color: Colors.green),
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

      // Get recommendation text
      final recommendation = _riskPercentage != null
          ? (_riskPercentage! <= 5
              ? 'No need to consult a doctor. Continue with quarterly checkups.'
              : 'Low risk detected. Maintain quarterly checkups for monitoring.')
          : null;

      // Generate PDF with risk assessment
      final pdfFile = await PdfReportService.generateMedicalReport(
        profile,
        riskPercentage: _riskPercentage,
        recommendation: recommendation,
      );

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/icon/co-logo.png', width: 32, height: 32),
            const SizedBox(width: 8),
            const Text(
              'AI Stethoscope',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.grey.shade900,
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
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () async {
              await FirebaseService().signOut();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_currentStep) {
      case ConnectionStep.initial:
        return _buildInitialScreen();
      case ConnectionStep.connecting:
        return _buildConnectingScreen();
      case ConnectionStep.selectPosition:
        return _buildSelectPositionScreen();
      case ConnectionStep.listening:
        return _buildListeningScreen();
      case ConnectionStep.results:
        return _buildResultsScreen();
    }
  }

  Widget _buildInitialScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green.withOpacity(0.1),
                border: Border.all(color: Colors.green, width: 3),
              ),
              child: const Icon(
                Icons.wifi,
                size: 80,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              'Connect Stethoscope',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Connect your digital stethoscope via WiFi to begin analysis',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _connectViaWiFi,
                icon: const Icon(Icons.wifi, size: 24),
                label: const Text(
                  'Connect via WiFi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Colors.green,
            strokeWidth: 3,
          ),
          const SizedBox(height: 32),
          const Text(
            'Connecting to stethoscope...',
            style: TextStyle(
              fontSize: 20,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Please wait',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectPositionScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Select Position',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Where are you placing the stethoscope?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 48),
            Row(
              children: [
                Expanded(
                  child: _buildPositionCard(
                    position: StethPosition.lungs,
                    icon: Icons.air,
                    title: 'Lungs',
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildPositionCard(
                    position: StethPosition.heart,
                    icon: Icons.favorite,
                    title: 'Heart',
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPositionCard({
    required StethPosition position,
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () => _selectPosition(position),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.5), width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: color),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListeningScreen() {
    final positionText = _selectedPosition == StethPosition.lungs ? 'Lungs' : 'Heart';
    final icon = _selectedPosition == StethPosition.lungs ? Icons.air : Icons.favorite;
    final color = _selectedPosition == StethPosition.lungs ? Colors.blue : Colors.red;
    final isHeart = _selectedPosition == StethPosition.heart;

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated pulsing icon
              TweenAnimationBuilder(
                tween: Tween<double>(begin: 0.8, end: 1.2),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeInOut,
                builder: (context, double scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: Icon(icon, size: 80, color: color),
                  );
                },
                onEnd: () {
                  setState(() {});
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Place on $positionText',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Listening',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0, end: 3),
                    duration: const Duration(milliseconds: 1500),
                    builder: (context, double value, child) {
                      final dots = '.' * (value.toInt() % 4);
                      return Text(
                        dots.padRight(3),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      );
                    },
                    onEnd: () {
                      setState(() {});
                    },
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Realistic Waveform Display
              Container(
                height: 200,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _showWaveform
                      ? TweenAnimationBuilder(
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 100),
                          builder: (context, double value, child) {
                            return CustomPaint(
                              painter: MedicalWaveformPainter(
                                animationValue: DateTime.now().millisecondsSinceEpoch / 1000.0,
                                color: color,
                                isHeartSound: isHeart,
                              ),
                              size: const Size(double.infinity, 200),
                            );
                          },
                          onEnd: () {
                            setState(() {});
                          },
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(
                                color: Colors.green,
                                strokeWidth: 2,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Establishing connection...',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Countdown with progress
              Stack(
                alignment: Alignment.center,
                children: [
                  TweenAnimationBuilder(
                    tween: Tween<double>(begin: 1.0, end: 1.1),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeInOut,
                    builder: (context, double scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.green.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                        ),
                      );
                    },
                    onEnd: () {
                      setState(() {});
                    },
                  ),
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: 1 - (_listeningCountdown / 25),
                      strokeWidth: 5,
                      backgroundColor: Colors.grey.shade800,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_listeningCountdown',
                        style: const TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const Text(
                        'seconds',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              Text(
                'Analyzing audio data...',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsScreen() {
    final positionText = _selectedPosition == StethPosition.lungs ? 'Lungs' : 'Heart';
    final recommendation = _riskPercentage! <= 5
        ? 'No need to consult a doctor. Continue with quarterly checkups.'
        : 'Low risk detected. Maintain quarterly checkups for monitoring.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green.withOpacity(0.1),
                border: Border.all(color: Colors.green, width: 3),
              ),
              child: const Icon(
                Icons.check_circle,
                size: 80,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Analysis Complete',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    positionText,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$_riskPercentage%',
                    style: const TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Risk Level',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      recommendation,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    await _generateAndSharePDF();
                  },
                  icon: const Icon(Icons.picture_as_pdf, size: 20),
                  label: const Text(
                    'Generate PDF',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _resetFlow,
                  icon: const Icon(Icons.refresh, size: 20),
                  label: const Text(
                    'New Test',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Realistic Medical Waveform Painter
class MedicalWaveformPainter extends CustomPainter {
  final double animationValue;
  final Color color;
  final bool isHeartSound;

  MedicalWaveformPainter({
    required this.animationValue,
    required this.color,
    required this.isHeartSound,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final gridPaint = Paint()
      ..color = Colors.green.withOpacity(0.15)
      ..strokeWidth = 0.5;

    final width = size.width;
    final height = size.height;
    final centerY = height / 2;

    // Draw grid (like medical monitors)
    for (int i = 0; i <= 10; i++) {
      final y = (height / 10) * i;
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
    }
    for (int i = 0; i <= 20; i++) {
      final x = (width / 20) * i;
      canvas.drawLine(Offset(x, 0), Offset(x, height), gridPaint);
    }

    final path = Path();
    final random = math.Random(42); // Fixed seed for consistency

    if (isHeartSound) {
      // Realistic Heart Sound Waveform (ECG-like with lub-dub pattern)
      for (double x = 0; x <= width; x += 1) {
        final t = (x / width) * 6 + animationValue; // Multiple heartbeats visible
        
        // Use different random values for each point for more noise
        final noiseRandom = math.Random((t * 1000 + x).toInt());
        
        // Create irregular heartbeat pattern
        double y = centerY;
        
        // QRS Complex (main spike) - appears at irregular intervals
        final beatPhase = (t % 1.2); // Slightly irregular timing
        
        if (beatPhase < 0.08) {
          // Q wave (small dip) with noise
          y = centerY + height * 0.05;
          y += (noiseRandom.nextDouble() - 0.5) * height * 0.03;
        } else if (beatPhase < 0.12) {
          // R wave (sharp spike - the "lub") with noise
          final progress = (beatPhase - 0.08) / 0.04;
          y = centerY - height * 0.35 * math.sin(progress * math.pi);
          y += (noiseRandom.nextDouble() - 0.5) * height * 0.05;
        } else if (beatPhase < 0.16) {
          // S wave (small dip after spike) with noise
          y = centerY + height * 0.08;
          y += (noiseRandom.nextDouble() - 0.5) * height * 0.04;
        } else if (beatPhase < 0.35) {
          // ST segment with more noise
          y = centerY + (noiseRandom.nextDouble() - 0.5) * height * 0.05;
          // Add multiple frequency noise components
          y += math.sin(t * 50 + noiseRandom.nextDouble() * math.pi) * height * 0.02;
          y += math.sin(t * 80 + noiseRandom.nextDouble() * math.pi) * height * 0.015;
        } else if (beatPhase < 0.45) {
          // T wave (the "dub" - smaller rounded peak) with noise
          final progress = (beatPhase - 0.35) / 0.1;
          y = centerY - height * 0.12 * math.sin(progress * math.pi);
          y += (noiseRandom.nextDouble() - 0.5) * height * 0.04;
        } else {
          // Baseline with significant natural variation and noise
          y = centerY + (noiseRandom.nextDouble() - 0.5) * height * 0.04;
          // Add 60Hz electrical noise simulation
          y += math.sin(t * 120 * math.pi) * height * 0.008;
          // Add muscle tremor artifact
          y += math.sin(t * 15 + noiseRandom.nextDouble()) * height * 0.012;
        }
        
        // Add breathing artifact
        y += math.sin(t * 0.3) * height * 0.025;
        
        // Add movement artifact (random spikes)
        if (noiseRandom.nextDouble() > 0.98) {
          y += (noiseRandom.nextDouble() - 0.5) * height * 0.08;
        }
        
        // Add high-frequency noise throughout
        y += (noiseRandom.nextDouble() - 0.5) * height * 0.015;
        
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
    } else {
      // Realistic Lung Sound Waveform (breath sounds)
      for (double x = 0; x <= width; x += 1) {
        final t = (x / width) * 4 + animationValue; // Slower breathing cycle
        
        // Simulate breathing cycle: inhale -> pause -> exhale -> pause
        final breathCycle = t % 1.0;
        double amplitude = 0;
        
        if (breathCycle < 0.35) {
          // Inhale (increasing amplitude with turbulence)
          final progress = breathCycle / 0.35;
          amplitude = progress * 0.25;
          // Add high-frequency turbulence for breath sounds
          amplitude += (random.nextDouble() - 0.5) * 0.15 * progress;
        } else if (breathCycle < 0.4) {
          // Brief pause
          amplitude = (random.nextDouble() - 0.5) * 0.05;
        } else if (breathCycle < 0.75) {
          // Exhale (decreasing amplitude with turbulence)
          final progress = (breathCycle - 0.4) / 0.35;
          amplitude = (1 - progress) * 0.25;
          amplitude += (random.nextDouble() - 0.5) * 0.15 * (1 - progress);
        } else {
          // Pause between breaths
          amplitude = (random.nextDouble() - 0.5) * 0.03;
        }
        
        // Add multiple frequency components for realistic lung sounds
        double y = centerY;
        y += math.sin(t * 15 + random.nextDouble()) * amplitude * height;
        y += math.sin(t * 25 + random.nextDouble() * 2) * amplitude * height * 0.5;
        y += math.sin(t * 40 + random.nextDouble() * 3) * amplitude * height * 0.3;
        
        // Add very subtle low-frequency component (heartbeat visible in lung sounds)
        y += math.sin(t * 3) * height * 0.01;
        
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
    }

    canvas.drawPath(path, paint);
    
    // Add glow effect
    final glowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawPath(path, glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Custom Wave Painter for audio visualization
class WavePainter extends CustomPainter {
  final double animationValue;
  final Color color;

  WavePainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final width = size.width;
    final height = size.height;
    final centerY = height / 2;

    for (double x = 0; x <= width; x += 2) {
      final normalizedX = x / width;
      final frequency = 2 * math.pi * 3;
      final phase = frequency * normalizedX + animationValue * 2 * math.pi;
      
      final y = centerY + math.sin(phase) * height * 0.4;

      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
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
