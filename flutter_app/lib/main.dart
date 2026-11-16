import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const _configuredPredictionServerUrl = String.fromEnvironment(
  'PREDICTION_SERVER_URL',
);

String get _predictionServerUrl {
  if (_configuredPredictionServerUrl.isNotEmpty) {
    return _configuredPredictionServerUrl;
  }
  return defaultTargetPlatform == TargetPlatform.android
      ? 'http://192.168.1.19:8000'
      : 'http://127.0.0.1:8000';
}

String _imageExtension(String value) {
  final extension = value.toLowerCase().split('?').first;
  final dot = extension.lastIndexOf('.');
  if (dot >= 0) {
    final candidate = extension.substring(dot);
    if ({'.jpg', '.jpeg', '.png', '.bmp', '.webp'}.contains(candidate)) {
      return candidate;
    }
  }
  return '.jpg';
}

class _DiseaseInfo {
  const _DiseaseInfo({
    required this.about,
    required this.symptoms,
    required this.actions,
  });

  final String about;
  final List<String> symptoms;
  final List<String> actions;
}

const _diseaseInfo = <String, _DiseaseInfo>{
  'Grassy Shoot': _DiseaseInfo(
    about:
        'Grassy shoot is a disease that causes sugarcane to grow many thin shoots that look like grass.',
    symptoms: [
      'Many thin shoots growing from the plant',
      'Leaves that look like grass',
      'Yellow or pale leaves',
      'Slow plant growth',
    ],
    actions: [
      'Remove and properly dispose of infected plants.',
      'Use healthy planting materials.',
      'Clean tools before using them on other plants.',
      'Ask an agriculture expert about ways to control the disease.',
    ],
  ),
  'Mosaic': _DiseaseInfo(
    about:
        'Mosaic is a viral disease that causes light and dark green patches on sugarcane leaves.',
    symptoms: [
      'Light and dark green patches on leaves',
      'Yellow or light-colored streaks',
      'Uneven leaf color',
      'Slow plant growth',
    ],
    actions: [
      'Remove badly infected plants when advised by an agriculture expert.',
      'Use healthy planting materials.',
      'Control insects such as aphids that may spread the virus.',
      'Check nearby plants for similar symptoms.',
    ],
  ),
  'Red Rot': _DiseaseInfo(
    about:
        'Red rot is a fungal disease that damages the inside of sugarcane stalks.',
    symptoms: [
      'Red areas inside the stalk',
      'White patches inside the red areas',
      'Dry or damaged stalks',
      'Poor plant growth',
    ],
    actions: [
      'Remove infected stalks and plant remains.',
      'Use healthy planting materials.',
      'Choose sugarcane varieties that can resist the disease.',
      'Avoid planting in areas with a history of severe infection without proper field management.',
    ],
  ),
  'Smut': _DiseaseInfo(
    about:
        'Smut is a fungal disease that causes a long, black, whip-like growth on sugarcane.',
    symptoms: [
      'Black, whip-like growth at the top of the plant',
      'Thin and narrow leaves',
      'Many small shoots',
      'Slow plant growth',
    ],
    actions: [
      'Remove infected plants carefully.',
      'Dispose of infected black whip growth properly.',
      'Use healthy planting materials.',
      'Choose disease-resistant sugarcane varieties.',
      'Clean tools after handling infected plants.',
    ],
  ),
  'Yellow Leaf': _DiseaseInfo(
    about:
        'Yellow leaf is a disease that causes sugarcane leaves to turn yellow.',
    symptoms: [
      'Yellowing along the middle of older leaves',
      'Yellow areas spreading across the leaves',
      'Weak plant growth',
      'Smaller or thinner stalks',
    ],
    actions: [
      'Check nearby plants for yellowing leaves.',
      'Use healthy planting materials.',
      'Control aphids when they are present and identified.',
      'Remove severely infected plants when advised by an agriculture expert.',
      'Ask an agriculture expert to confirm the disease.',
    ],
  ),
};

void main() {
  runApp(const SugarcaneApp());
}

class SugarcaneApp extends StatelessWidget {
  const SugarcaneApp({super.key});

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF0875C9);
    return MaterialApp(
      title: 'Sugarcane Disease Classifier',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: blue,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F9FD),
        appBarTheme: AppBarTheme(
          backgroundColor: blue,
          foregroundColor: Colors.white,
          centerTitle: false,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: blue.withValues(alpha: 0.18)),
          ),
        ),
        useMaterial3: true,
      ),
      home: const ClassifierPage(),
    );
  }
}

class ClassifierPage extends StatefulWidget {
  const ClassifierPage({super.key});

  @override
  State<ClassifierPage> createState() => _ClassifierPageState();
}

class _ClassifierPageState extends State<ClassifierPage> {
  Uint8List? _imageBytes;
  String? _fileName;
  String? _prediction;
  double? _confidence;
  String? _possiblePrediction;
  double? _possibleConfidence;
  String? _error;
  bool _loading = false;

  Future<void> _selectImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'bmp', 'webp'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    final file = result.files.single;
    await _useImage(file.bytes!, file.name, file.extension ?? '.jpg');
  }

  Future<void> _captureImage() async {
    CameraController? controller;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No camera was found on this device.');
      }

      controller = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) return;

      final image = await showDialog<XFile>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Capture Photo'),
          content: _buildCameraPreview(controller!),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () async {
                final capturedImage = await controller!.takePicture();
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(capturedImage);
                }
              },
              icon: const Icon(Icons.camera),
              label: const Text('Take Photo'),
            ),
          ],
        ),
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      await _useImage(
        bytes,
        image.name,
        _imageExtension(image.name),
      );
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not access the camera: $error');
      }
    } finally {
      await controller?.dispose();
    }
  }

  Widget _buildCameraPreview(CameraController controller) {
    final previewSize = controller.value.previewSize;
    final isPortrait =
        MediaQuery.orientationOf(context) == Orientation.portrait;
    return SizedBox(
      width: double.infinity,
      height: 320,
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: isPortrait
                ? (previewSize?.height ?? 720)
                : (previewSize?.width ?? 1280),
            height: isPortrait
                ? (previewSize?.width ?? 1280)
                : (previewSize?.height ?? 720),
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }

  Future<void> _useImage(
    Uint8List bytes,
    String fileName,
    String extension,
  ) async {
    setState(() {
      _imageBytes = bytes;
      _fileName = fileName;
      _prediction = null;
      _confidence = null;
      _possiblePrediction = null;
      _possibleConfidence = null;
      _error = null;
    });
    await _predict(bytes, extension);
  }

  Future<void> _predict(Uint8List bytes, String extension) async {
    setState(() => _loading = true);
    try {
      final response = await http
          .post(
            Uri.parse('$_predictionServerUrl/predict'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'image': base64Encode(bytes),
              'extension': _imageExtension(extension),
            }),
          )
          .timeout(const Duration(seconds: 60));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || body['error'] != null) {
        throw Exception(body['error'] ?? 'Prediction failed.');
      }
      setState(() {
        _prediction = body['className'] as String;
        _confidence = (body['confidence'] as num).toDouble();
        _possiblePrediction = body['possibleClassName'] as String?;
        _possibleConfidence = (body['possibleConfidence'] as num?)?.toDouble();
      });
    } on Object catch (error) {
      setState(
        () => _error = 'Could not connect to the prediction server: $error',
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _buildDiseaseInfo(BuildContext context) {
    final info = _diseaseInfo[_prediction];
    if (info == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  'About $_prediction',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(info.about),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.fact_check_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Common symptoms',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ...info.symptoms.map(
              (symptom) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(symptom)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Icon(
                  Icons.volunteer_activism_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Suggested actions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ...info.actions.map(
              (action) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.arrow_right_alt,
                      size: 19,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 7),
                    Expanded(child: Text(action)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startNewScan() {
    setState(() {
      _imageBytes = null;
      _fileName = null;
      _prediction = null;
      _confidence = null;
      _possiblePrediction = null;
      _possibleConfidence = null;
      _error = null;
    });
  }

  Widget _buildPredictionSummary(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final confidence = _confidence ?? 0;
    final possibleConfidence = _possibleConfidence == null
        ? ''
        : ' (${(_possibleConfidence! * 100).toStringAsFixed(1)}%)';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: colorScheme.primaryContainer,
                  foregroundColor: colorScheme.primary,
                  child: const Icon(Icons.eco_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Disease detected',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _prediction!,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.verified_outlined, color: colorScheme.primary),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Confidence',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${(confidence * 100).toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: confidence,
                minHeight: 9,
                backgroundColor: colorScheme.surfaceContainerHighest,
                color: colorScheme.primary,
              ),
            ),
            if (confidence < 1 && _possiblePrediction != null) ...[
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.help_outline,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Possible detection: $_possiblePrediction$possibleConfidence',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImageCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: _imageBytes != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  _imageBytes!,
                  height: 280,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              )
            : SizedBox(
                height: 280,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_search_outlined,
                      size: 58,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'No image selected',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    const Text('Choose an image to begin'),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildImageActions(BuildContext context) {
    return Column(
      children: [
        Text(
          _fileName ?? 'Ready for image analysis',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _loading ? null : _selectImage,
            icon: const Icon(Icons.file_upload_outlined),
            label: const Text('Upload Image'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _loading ? null : _captureImage,
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Capture Photo'),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysisPanel(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_prediction != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPredictionSummary(context),
          const SizedBox(height: 12),
          _buildDiseaseInfo(context),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _startNewScan,
            icon: const Icon(Icons.refresh),
            label: const Text('Scan Another Image'),
          ),
        ],
      );
    }
    if (_error != null) {
      return Text(
        _error!,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 42,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Ready to analyze',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Upload a sugarcane leaf image or capture a photo to see the disease prediction and recommended actions.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _prediction == null ? 'Hello!' : 'Prediction result',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _prediction == null
                ? 'Detect sugarcane diseases using AI.'
                : 'Review the result and recommended actions below.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/kalam_ai_logo.png',
              height: 30,
              width: 30,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 8),
            const Text(
              'kalamAI',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWideWeb = kIsWeb && constraints.maxWidth >= 900;
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isWideWeb ? 1180 : 720),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPageHeader(context),
                    if (isWideWeb)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                _buildImageCard(context),
                                const SizedBox(height: 10),
                                _buildImageActions(context),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(child: _buildAnalysisPanel(context)),
                        ],
                      )
                    else ...[
                      _buildImageCard(context),
                      const SizedBox(height: 10),
                      _buildImageActions(context),
                      const SizedBox(height: 20),
                      _buildAnalysisPanel(context),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
