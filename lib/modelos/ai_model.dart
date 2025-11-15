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

  // Lista de modelos disponibles
  static List<AIModel> get availableModels => [
        // Modelos GRATIS
        AIModel(
          id: 'google/gemma-2-9b-it:free',
          name: 'Gemma 2 9B',
          description: 'Mejor balance calidad/rendimiento (RECOMENDADO)',
          isFree: true,
          provider: 'Google',
        ),
        AIModel(
          id: 'meta-llama/llama-3.2-3b-instruct:free',
          name: 'Llama 3.2 3B',
          description: 'Rápido pero con rate limiting',
          isFree: true,
          provider: 'Meta',
        ),
        AIModel(
          id: 'meta-llama/llama-3.2-1b-instruct:free',
          name: 'Llama 3.2 1B',
          description: 'Más rápido, respuestas básicas',
          isFree: true,
          provider: 'Meta',
        ),
        AIModel(
          id: 'mistralai/mistral-7b-instruct:free',
          name: 'Mistral 7B',
          description: 'Buena calidad general',
          isFree: true,
          provider: 'Mistral AI',
        ),
        AIModel(
          id: 'microsoft/phi-3-mini-128k-instruct:free',
          name: 'Phi-3 Mini',
          description: 'Eficiente y rápido',
          isFree: true,
          provider: 'Microsoft',
        ),
        AIModel(
          id: 'qwen/qwen-2-7b-instruct:free',
          name: 'Qwen 2 7B',
          description: 'Bueno para tareas variadas',
          isFree: true,
          provider: 'Alibaba',
        ),

        // Modelos DE PAGO
        AIModel(
          id: 'anthropic/claude-3.5-sonnet',
          name: 'Claude 3.5 Sonnet',
          description: 'La mejor calidad disponible',
          isFree: false,
          provider: 'Anthropic',
        ),
        AIModel(
          id: 'openai/gpt-4o',
          name: 'GPT-4o',
          description: 'Muy capaz y versátil',
          isFree: false,
          provider: 'OpenAI',
        ),
        AIModel(
          id: 'google/gemini-pro-1.5',
          name: 'Gemini Pro 1.5',
          description: 'Excelente balance calidad/precio',
          isFree: false,
          provider: 'Google',
        ),
        AIModel(
          id: 'meta-llama/llama-3.1-70b-instruct',
          name: 'Llama 3.1 70B',
          description: 'Potente modelo open source',
          isFree: false,
          provider: 'Meta',
        ),
      ];

  // Obtener modelos gratis
  static List<AIModel> get freeModels =>
      availableModels.where((model) => model.isFree).toList();

  // Obtener modelos de pago
  static List<AIModel> get paidModels =>
      availableModels.where((model) => !model.isFree).toList();

  // Buscar modelo por ID
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
