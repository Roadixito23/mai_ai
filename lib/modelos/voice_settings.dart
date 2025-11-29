/// Modelo que representa la configuración de voz (STT y TTS)
class VoiceSettings {
  // Configuración de Speech-to-Text (STT)
  final String sttLanguage; // 'es-ES', 'es-MX', etc.
  final int maxListeningSeconds; // Tiempo máximo de escucha
  final int pauseSilenceSeconds; // Pausa de silencio antes de detener
  final bool partialResults; // Mostrar resultados parciales
  final bool onDeviceRecognition; // Usar reconocimiento en el dispositivo

  // Configuración de Text-to-Speech (TTS)
  final String ttsLanguage; // 'es-ES', 'es-MX', etc.
  final double speechRate; // Velocidad de habla (0.0 - 1.0)
  final double volume; // Volumen (0.0 - 1.0)
  final double pitch; // Tono (0.5 - 2.0)
  final String? preferredVoice; // Voz preferida (ej: 'Microsoft Helena')

  const VoiceSettings({
    this.sttLanguage = 'es-ES',
    this.maxListeningSeconds = 30,
    this.pauseSilenceSeconds = 3,
    this.partialResults = true,
    this.onDeviceRecognition = true,
    this.ttsLanguage = 'es-ES',
    this.speechRate = 0.5,
    this.volume = 1.0,
    this.pitch = 1.0,
    this.preferredVoice,
  });

  /// Valores predeterminados recomendados
  factory VoiceSettings.defaults() {
    return const VoiceSettings();
  }

  /// Configuración optimizada para español de España
  factory VoiceSettings.spanishSpain() {
    return const VoiceSettings(
      sttLanguage: 'es-ES',
      ttsLanguage: 'es-ES',
      preferredVoice: 'Microsoft Helena',
    );
  }

  /// Configuración optimizada para español de México
  factory VoiceSettings.spanishMexico() {
    return const VoiceSettings(
      sttLanguage: 'es-MX',
      ttsLanguage: 'es-MX',
      preferredVoice: 'Microsoft Sabina',
    );
  }

  /// Crear una copia con valores actualizados
  VoiceSettings copyWith({
    String? sttLanguage,
    int? maxListeningSeconds,
    int? pauseSilenceSeconds,
    bool? partialResults,
    bool? onDeviceRecognition,
    String? ttsLanguage,
    double? speechRate,
    double? volume,
    double? pitch,
    String? preferredVoice,
  }) {
    return VoiceSettings(
      sttLanguage: sttLanguage ?? this.sttLanguage,
      maxListeningSeconds: maxListeningSeconds ?? this.maxListeningSeconds,
      pauseSilenceSeconds: pauseSilenceSeconds ?? this.pauseSilenceSeconds,
      partialResults: partialResults ?? this.partialResults,
      onDeviceRecognition: onDeviceRecognition ?? this.onDeviceRecognition,
      ttsLanguage: ttsLanguage ?? this.ttsLanguage,
      speechRate: speechRate ?? this.speechRate,
      volume: volume ?? this.volume,
      pitch: pitch ?? this.pitch,
      preferredVoice: preferredVoice ?? this.preferredVoice,
    );
  }

  /// Validar que los valores estén en rangos correctos
  bool get isValid {
    return speechRate >= 0.0 &&
        speechRate <= 1.0 &&
        volume >= 0.0 &&
        volume <= 1.0 &&
        pitch >= 0.5 &&
        pitch <= 2.0 &&
        maxListeningSeconds > 0 &&
        pauseSilenceSeconds > 0;
  }

  /// Convertir a JSON para persistencia
  Map<String, dynamic> toJson() {
    return {
      'sttLanguage': sttLanguage,
      'maxListeningSeconds': maxListeningSeconds,
      'pauseSilenceSeconds': pauseSilenceSeconds,
      'partialResults': partialResults,
      'onDeviceRecognition': onDeviceRecognition,
      'ttsLanguage': ttsLanguage,
      'speechRate': speechRate,
      'volume': volume,
      'pitch': pitch,
      'preferredVoice': preferredVoice,
    };
  }

  /// Crear desde JSON
  factory VoiceSettings.fromJson(Map<String, dynamic> json) {
    return VoiceSettings(
      sttLanguage: json['sttLanguage'] as String? ?? 'es-ES',
      maxListeningSeconds: json['maxListeningSeconds'] as int? ?? 30,
      pauseSilenceSeconds: json['pauseSilenceSeconds'] as int? ?? 3,
      partialResults: json['partialResults'] as bool? ?? true,
      onDeviceRecognition: json['onDeviceRecognition'] as bool? ?? true,
      ttsLanguage: json['ttsLanguage'] as String? ?? 'es-ES',
      speechRate: (json['speechRate'] as num?)?.toDouble() ?? 0.5,
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
      pitch: (json['pitch'] as num?)?.toDouble() ?? 1.0,
      preferredVoice: json['preferredVoice'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoiceSettings &&
          runtimeType == other.runtimeType &&
          sttLanguage == other.sttLanguage &&
          maxListeningSeconds == other.maxListeningSeconds &&
          pauseSilenceSeconds == other.pauseSilenceSeconds &&
          partialResults == other.partialResults &&
          onDeviceRecognition == other.onDeviceRecognition &&
          ttsLanguage == other.ttsLanguage &&
          speechRate == other.speechRate &&
          volume == other.volume &&
          pitch == other.pitch &&
          preferredVoice == other.preferredVoice;

  @override
  int get hashCode => Object.hash(
        sttLanguage,
        maxListeningSeconds,
        pauseSilenceSeconds,
        partialResults,
        onDeviceRecognition,
        ttsLanguage,
        speechRate,
        volume,
        pitch,
        preferredVoice,
      );
}
