import 'dart:convert';
import 'dart:io';

import 'api_client.dart';

class AnalysisResult {
  const AnalysisResult({required this.summary, required this.steps});

  final String summary;
  final List<String> steps;
}

class AnalysisService {
  AnalysisService._();

  static final AnalysisService instance = AnalysisService._();
  final ApiClient _apiClient = ApiClient.instance;

  Future<AnalysisResult> analyzeImage({
    required File image,
    required String description,
  }) async {
    final bytes = await image.readAsBytes();
    final base64Image = 'data:image/${_detectMime(image.path)};base64,${base64Encode(bytes)}';

    final response = await _apiClient.post(
      '/api/analysis',
      body: {
        'imageBase64': base64Image,
        'description': description,
      },
    );

    final summary = response['summary']?.toString() ?? 'No summary generated.';
    final stepsData = response['steps'];
    final steps = stepsData is List
        ? stepsData.map((step) => step.toString()).where((step) => step.trim().isNotEmpty).toList()
        : const <String>[];

    return AnalysisResult(summary: summary, steps: steps);
  }

  String _detectMime(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    return 'jpeg';
  }

  Future<String> chat({required String question, String? context}) async {
    final response = await _apiClient.post(
      '/api/analysis/chat',
      body: {
        'question': question,
        if (context != null && context.trim().isNotEmpty) 'context': context,
      },
    );

    final success = response['success'] == true;
    if (!success) {
      final message = response['message']?.toString() ?? 'Failed to get AI response.';
      throw ApiException(message, statusCode: response['statusCode'] as int?);
    }

    return response['answer']?.toString() ?? 'No answer generated.';
  }
}
