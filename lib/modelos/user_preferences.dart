/// Modelo que representa las preferencias del usuario
class UserPreferences {
  final String preferredModelId;
  final String theme; // 'light', 'dark', 'system'
  final bool voiceModeEnabled;
  final String language; // 'es-ES', 'es-MX', etc.
  final bool streamingEnabled;
  final bool showTimestamps;
  final bool soundEnabled;
  final double fontSize; // Tamaño de fuente en pts
  final bool autoScrollEnabled;

  const UserPreferences({
    this.preferredModelId = 'gemini-2.5-flash',
    this.theme = 'system',
    this.voiceModeEnabled = false,
    this.language = 'es-ES',
    this.streamingEnabled = true,
    this.showTimestamps = false,
    this.soundEnabled = true,
    this.fontSize = 14.0,
    this.autoScrollEnabled = true,
  });

  /// Valores predeterminados
  factory UserPreferences.defaults() {
    return const UserPreferences();
  }

  /// Crear una copia con valores actualizados
  UserPreferences copyWith({
    String? preferredModelId,
    String? theme,
    bool? voiceModeEnabled,
    String? language,
    bool? streamingEnabled,
    bool? showTimestamps,
    bool? soundEnabled,
    double? fontSize,
    bool? autoScrollEnabled,
  }) {
    return UserPreferences(
      preferredModelId: preferredModelId ?? this.preferredModelId,
      theme: theme ?? this.theme,
      voiceModeEnabled: voiceModeEnabled ?? this.voiceModeEnabled,
      language: language ?? this.language,
      streamingEnabled: streamingEnabled ?? this.streamingEnabled,
      showTimestamps: showTimestamps ?? this.showTimestamps,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      fontSize: fontSize ?? this.fontSize,
      autoScrollEnabled: autoScrollEnabled ?? this.autoScrollEnabled,
    );
  }

  /// Convertir a JSON para persistencia
  Map<String, dynamic> toJson() {
    return {
      'preferredModelId': preferredModelId,
      'theme': theme,
      'voiceModeEnabled': voiceModeEnabled,
      'language': language,
      'streamingEnabled': streamingEnabled,
      'showTimestamps': showTimestamps,
      'soundEnabled': soundEnabled,
      'fontSize': fontSize,
      'autoScrollEnabled': autoScrollEnabled,
    };
  }

  /// Crear desde JSON
  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      preferredModelId: json['preferredModelId'] as String? ?? 'gemini-2.5-flash',
      theme: json['theme'] as String? ?? 'system',
      voiceModeEnabled: json['voiceModeEnabled'] as bool? ?? false,
      language: json['language'] as String? ?? 'es-ES',
      streamingEnabled: json['streamingEnabled'] as bool? ?? true,
      showTimestamps: json['showTimestamps'] as bool? ?? false,
      soundEnabled: json['soundEnabled'] as bool? ?? true,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 14.0,
      autoScrollEnabled: json['autoScrollEnabled'] as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserPreferences &&
          runtimeType == other.runtimeType &&
          preferredModelId == other.preferredModelId &&
          theme == other.theme &&
          voiceModeEnabled == other.voiceModeEnabled &&
          language == other.language &&
          streamingEnabled == other.streamingEnabled &&
          showTimestamps == other.showTimestamps &&
          soundEnabled == other.soundEnabled &&
          fontSize == other.fontSize &&
          autoScrollEnabled == other.autoScrollEnabled;

  @override
  int get hashCode => Object.hash(
        preferredModelId,
        theme,
        voiceModeEnabled,
        language,
        streamingEnabled,
        showTimestamps,
        soundEnabled,
        fontSize,
        autoScrollEnabled,
      );
}
