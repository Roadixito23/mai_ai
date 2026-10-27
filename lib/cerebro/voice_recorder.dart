import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Graba la voz del usuario a un archivo temporal para transcribirla.
///
/// WAV mono a 16 kHz: lo que Whisper usa internamente, funciona en Android,
/// Windows y Linux (en Linux requiere `parecord`, `pactl` y `ffmpeg`) y un
/// minuto pesa unos 2 MB.
class VoiceRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  String? _path;

  static const RecordConfig _config = RecordConfig(
    encoder: AudioEncoder.wav,
    sampleRate: 16000,
    numChannels: 1,
    noiseSuppress: true,
  );

  /// Empieza a grabar. false si no hay permiso de micrófono.
  Future<bool> start() async {
    if (!await _recorder.hasPermission()) return false;
    final dir = await getTemporaryDirectory();
    _path = p.join(dir.path, 'mai_voz_${DateTime.now().millisecondsSinceEpoch}.wav');
    await _recorder.start(_config, path: _path!);
    return true;
  }

  /// Termina y devuelve el archivo grabado (null si no había grabación).
  Future<String?> stop() async {
    final path = await _recorder.stop() ?? _path;
    _path = null;
    return path;
  }

  /// Descarta la grabación en curso.
  Future<void> cancel() async {
    _path = null;
    await _recorder.cancel();
  }

  static Future<void> deleteFile(String path) async {
    try {
      await File(path).delete();
    } catch (e) {
      debugPrint('No se pudo borrar el audio temporal: $e');
    }
  }

  Future<void> dispose() => _recorder.dispose();
}
