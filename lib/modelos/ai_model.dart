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
        // --- MODELOS DE GOOGLE (GRATIS) ---
        AIModel(
          id: 'gemini-pro',
          name: 'Gemini Pro',
          description: 'Modelo equilibrado y estable (RECOMENDADO)',
          isFree: true,
          provider: 'Google',
        ),
        AIModel(
          id: 'gemini-flash',
          name: 'Gemini Flash',
          description: 'Rápido y eficiente para respuestas generales',
          isFree: true,
          provider: 'Google',
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
