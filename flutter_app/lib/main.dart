import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const SugarcaneApp());
}

class SugarcaneApp extends StatelessWidget {
  const SugarcaneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sugarcane Disease Classifier',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
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
    setState(() {
      _imageBytes = file.bytes;
      _fileName = file.name;
      _prediction = null;
      _confidence = null;
      _error = null;
    });
    await _predict(file.bytes!, file.extension ?? '.jpg');
  }

  Future<void> _predict(Uint8List bytes, String extension) async {
    setState(() => _loading = true);
    try {
      final response = await http
          .post(
            Uri.parse('http://127.0.0.1:8000/predict'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'image': base64Encode(bytes),
              'extension': extension.startsWith('.') ? extension : '.$extension',
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
      });
    } on Object catch (error) {
      setState(() => _error = 'Could not connect to the prediction server: $error');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sugarcane Disease Classifier')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_imageBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(_imageBytes!, height: 300, fit: BoxFit.contain),
                  )
                else
                  const Icon(Icons.photo_library_outlined, size: 100, color: Colors.green),
                const SizedBox(height: 20),
                Text(_fileName ?? 'Select a sugarcane image'),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _loading ? null : _selectImage,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload Image'),
                ),
                const SizedBox(height: 20),
                if (_loading) const CircularProgressIndicator(),
                if (_prediction != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        'Prediction: $_prediction\n'
                        'Confidence: ${(_confidence! * 100).toStringAsFixed(2)}%',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                if (_error != null)
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
