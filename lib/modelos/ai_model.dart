class AIModel {
  final String id;
  final String name;
  final String description;
  final bool isFree;
  final String provider;

  const AIModel({
    required this.id,
    required this.name,
    required this.description,
    required this.isFree,
    required this.provider,
  });

  // Lista ACTUALIZADA con modelos disponibles
  static List<AIModel> get availableModels => [
    AIModel(
      id: 'gemini-2.5-flash',
      name: 'Gemini 2.5 Flash',
      description: 'Rápido e inteligente - Recomendado para uso general',
      isFree: true,
      provider: 'Google',
    ),
    AIModel(
      id: 'gemini-2.5-pro',
      name: 'Gemini 2.5 Pro',
      description: 'Más potente - Ideal para tareas complejas',
      isFree: true,
      provider: 'Google',
    ),
    AIModel(
      id: 'gemini-2.0-flash',
      name: 'Gemini 2.0 Flash',
      description: 'Modelo de segunda generación estable',
      isFree: true,
      provider: 'Google',
    ),
    AIModel(
      id: 'gemini-2.5-flash-lite',
      name: 'Gemini 2.5 Flash-Lite',
      description: 'Ultra rápido y económico',
      isFree: true,
      provider: 'Google',
    ),
  ];

  static List<AIModel> get freeModels =>
      availableModels.where((model) => model.isFree).toList();

  static List<AIModel> get paidModels =>
      availableModels.where((model) => !model.isFree).toList();

  static AIModel? findById(String id) {
    try {
      return availableModels.firstWhere((model) => model.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is AIModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}