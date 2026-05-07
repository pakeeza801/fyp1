import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../app_config.dart';

class AiPipelineResult {
  final String transcript;
  final String translation;
  final Uint8List? ttsAudio; // optional
  final String? ttsMime; // e.g. audio/wav

  const AiPipelineResult({
    required this.transcript,
    required this.translation,
    required this.ttsAudio,
    required this.ttsMime,
  });
}

class AiClient {
  Uri _uri(String path) => Uri.parse('${AppConfig.aiServerBaseUrl}$path');

  Future<AiPipelineResult> pipeline({
    required Uint8List audioBytes,
    required String srcLang,
    required String tgtLang,
    bool includeTts = true,
  }) async {
    final req = http.MultipartRequest('POST', _uri('/pipeline'));
    req.fields['src_lang'] = srcLang;
    req.fields['tgt_lang'] = tgtLang;
    req.fields['include_tts'] = includeTts ? '1' : '0';
    req.files.add(
      http.MultipartFile.fromBytes(
        'audio',
        audioBytes,
        filename: 'audio.wav',
        contentType: null,
      ),
    );

    final res = await req.send();
    final body = await res.stream.bytesToString();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('AI server error (${res.statusCode}): $body');
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    final transcript = (json['transcript'] as String?) ?? '';
    final translation = (json['translation'] as String?) ?? '';

    Uint8List? ttsAudio;
    String? ttsMime;
    final ttsB64 = json['tts_audio_b64'] as String?;
    if (ttsB64 != null && ttsB64.isNotEmpty) {
      ttsAudio = base64Decode(ttsB64);
      ttsMime = (json['tts_mime'] as String?) ?? 'audio/wav';
    }

    return AiPipelineResult(
      transcript: transcript,
      translation: translation,
      ttsAudio: ttsAudio,
      ttsMime: ttsMime,
    );
  }
}

