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

  static List<AIModel> get availableModels => [
    AIModel(
      id: 'llama-3.3-70b-versatile',
      name: 'Llama 3.3 70B',
      description: 'Equilibrado e inteligente - Recomendado para uso general',
      isFree: true,
      provider: 'Groq',
    ),
    AIModel(
      id: 'openai/gpt-oss-120b',
      name: 'GPT-OSS 120B',
      description: 'Más potente - Ideal para tareas complejas',
      isFree: true,
      provider: 'Groq',
    ),
    AIModel(
      id: 'openai/gpt-oss-20b',
      name: 'GPT-OSS 20B',
      description: 'Rápido y capaz para el día a día',
      isFree: true,
      provider: 'Groq',
    ),
    AIModel(
      id: 'llama-3.1-8b-instant',
      name: 'Llama 3.1 8B Instant',
      description: 'Ultra rápido y ligero',
      isFree: true,
      provider: 'Groq',
    ),
  ];

  /// Modelo devuelto por la API: usa el nombre conocido o deriva uno del id.
  factory AIModel.fromId(String id, {String provider = 'Groq'}) {
    final known = findById(id);
    if (known != null) return known;
    final slug = id.split('/').last.replaceAll('-', ' ').replaceAll('_', ' ');
    return AIModel(
      id: id,
      name: slug,
      description: 'Disponible en tu cuenta de $provider',
      isFree: true,
      provider: provider,
    );
  }

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