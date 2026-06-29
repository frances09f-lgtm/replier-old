import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class ModelDownloadService {
  static const String _modelDir = 'local_models';

  static const Map<String, Map<String, String>> availableModels = {
    'Qwen2.5-0.5B-Q4_K_M': {
      'url': 'https://huggingface.co/bartowski/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/Qwen2.5-0.5B-Instruct-Q4_K_M.gguf',
      'size': '~350 MB',
      'description': 'Best quality/size tradeoff',
    },
    'SmolLM2-360M-Q4_K_M': {
      'url': 'https://huggingface.co/HuggingFaceTB/SmolLM2-360M-Instruct-GGUF/resolve/main/SmolLM2-360M-Instruct-Q4_K_M.gguf',
      'size': '~250 MB',
      'description': 'Smallest, fastest, basic quality',
    },
    'TinyLlama-1.1B-Q4_K_M': {
      'url': 'https://huggingface.co/mradermacher/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/TinyLlama-1.1B-Chat-v1.0.Q4_K_M.gguf',
      'size': '~700 MB',
      'description': 'Best quality, larger file',
    },
  };

  static Future<Directory> _getModelDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${dir.path}/$_modelDir');
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    return modelDir;
  }

  static Future<List<File>> getDownloadedModels() async {
    final dir = await _getModelDirectory();
    final files = await dir.list().toList();
    return files
        .whereType<File>()
        .where((f) => f.path.endsWith('.gguf'))
        .toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
  }

  static Future<String?> getLatestModelPath() async {
    final models = await getDownloadedModels();
    if (models.isEmpty) return null;
    return models.first.path;
  }

  static Future<String?> downloadModel(
    String modelKey, {
    String? hfToken,
    void Function(double progress)? onProgress,
    void Function(String? error)? onComplete,
  }) async {
    final modelInfo = availableModels[modelKey];
    if (modelInfo == null) {
      onComplete?.call('Unknown model: $modelKey');
      return null;
    }

    final url = modelInfo['url']!;
    final fileName = url.split('/').last;
    final dir = await _getModelDirectory();
    final filePath = '${dir.path}/$fileName';

    final existing = File(filePath);
    if (await existing.exists()) {
      final size = await existing.length();
      if (size < 1024 * 1024) {
        // Existing file is too small, re-download
        await existing.delete();
      } else {
        onComplete?.call(null);
        return filePath;
      }
    }

    // Try each download source in order
    final urls = [url];
    final altKeys = availableModels.keys
        .where((k) => k != modelKey)
        .toList();
    for (final altKey in altKeys) {
      final altUrl = availableModels[altKey]!['url']!;
      if (altUrl != url) {
        urls.add(altUrl);
      }
    }

    for (int attempt = 0; attempt < urls.length; attempt++) {
      final result = await _downloadBinary(
        urls[attempt], filePath, hfToken, onProgress, onComplete,
      );
      if (result != null) return result;

      // Try next URL if this one failed
      if (attempt < urls.length - 1) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    return null;
  }

  static Future<String?> _downloadBinary(
    String url,
    String filePath,
    String? hfToken,
    void Function(double progress)? onProgress,
    void Function(String? error)? onComplete,
  ) async {
    try {
      final client = HttpClient();
      client.badCertificateCallback = ((X509Certificate cert, String host, int port) => false);
      client.connectionTimeout = const Duration(seconds: 30);
      client.idleTimeout = const Duration(seconds: 30);

      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('User-Agent', 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36');
      request.headers.set('Accept', '*/*');
      if (hfToken != null && hfToken.isNotEmpty) {
        request.headers.set('Authorization', 'Bearer $hfToken');
      }

      final response = await request.close();

      if (response.statusCode == 307 || response.statusCode == 302) {
        final redirectUrl = response.headers.value('location');
        client.close();
        if (redirectUrl != null) {
          return await _downloadBinary(redirectUrl, filePath, hfToken, onProgress, onComplete);
        }
        return null;
      }

      if (response.statusCode != 200) {
        final partial = File(filePath);
        if (await partial.exists()) await partial.delete();
        client.close();
        return null;
      }

      final contentLength = response.contentLength;
      final file = File(filePath);
      final sink = file.openWrite();
      var receivedBytes = 0;

      await for (final chunk in response) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (contentLength > 0) {
          onProgress?.call(receivedBytes / contentLength);
        }
      }

      await sink.flush();
      await sink.close();
      client.close();

      // Verify file
      if (receivedBytes == 0) {
        await file.delete();
        onComplete?.call('Downloaded file is empty');
        return null;
      }

      // Sanity check: GGUF files are at least 1MB; smaller means corrupt/partial
      if (receivedBytes < 1024 * 1024) {
        await file.delete();
        onComplete?.call('Downloaded file too small ($receivedBytes bytes) - likely corrupted');
        return null;
      }

      onComplete?.call(null);
      return filePath;
    } catch (e) {
      final partial = File(filePath);
      if (await partial.exists()) await partial.delete();
      return null;
    }
  }

  static Future<bool> deleteModel(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Failed to delete model: $e');
      return false;
    }
  }

  static Future<int> getModelSize(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }
}
