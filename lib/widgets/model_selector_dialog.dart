import 'package:flutter/material.dart';
import '../modelos/ai_model.dart';

class ModelSelectorDialog extends StatefulWidget {
  final String currentModel;

  const ModelSelectorDialog({
    super.key,
    required this.currentModel,
  });

  @override
  State<ModelSelectorDialog> createState() => _ModelSelectorDialogState();
}

/// Widget para mostrar las características de un modelo
class _ModelFeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _ModelFeatureChip({
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chipColor = color ?? (isDark ? Colors.purple[300] : Colors.purple[700]);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor!.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: chipColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: chipColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: chipColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelSelectorDialogState extends State<ModelSelectorDialog> {
  AIModel? _selectedModel;

  @override
  void initState() {
    super.initState();
    _selectedModel = AIModel.findById(widget.currentModel);
  }

  /// Obtener características específicas de cada modelo
  List<_ModelFeatureChip> _getModelFeatures(AIModel model, bool isDark) {
    switch (model.id) {
      case 'gemini-2.5-flash':
        return [
          _ModelFeatureChip(
            icon: Icons.flash_on,
            label: 'Ultra Rápido',
            color: isDark ? Colors.amber[300] : Colors.amber[700],
          ),
          const _ModelFeatureChip(
            icon: Icons.recommend,
            label: 'Recomendado',
          ),
        ];
      case 'gemini-2.5-pro':
        return [
          _ModelFeatureChip(
            icon: Icons.stars,
            label: 'Más Potente',
            color: isDark ? Colors.blue[300] : Colors.blue[700],
          ),
          _ModelFeatureChip(
            icon: Icons.psychology,
            label: 'Razonamiento Avanzado',
            color: isDark ? Colors.cyan[300] : Colors.cyan[700],
          ),
        ];
      case 'gemini-2.0-flash':
        return [
          _ModelFeatureChip(
            icon: Icons.verified_outlined,
            label: 'Estable',
            color: isDark ? Colors.green[300] : Colors.green[700],
          ),
        ];
      case 'gemini-2.5-flash-lite':
        return [
          _ModelFeatureChip(
            icon: Icons.speed,
            label: 'Económico',
            color: isDark ? Colors.teal[300] : Colors.teal[700],
          ),
          _ModelFeatureChip(
            icon: Icons.bolt,
            label: 'Ligero',
            color: isDark ? Colors.lightGreen[300] : Colors.lightGreen[700],
          ),
        ];
      default:
        return [];
    }
  }

  Widget _buildModelTile(AIModel model) {
    final isSelected = _selectedModel?.id == model.id;
    final isCurrent = widget.currentModel == model.id;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      child: Material(
        elevation: isSelected ? 8 : 2,
        borderRadius: BorderRadius.circular(16),
        color: isSelected
            ? (isDark ? Colors.purple[900]!.withOpacity(0.3) : Colors.purple[50])
            : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedModel = model;
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? (isDark ? Colors.purpleAccent : Colors.purple)
                    : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey[300]!),
                width: isSelected ? 2.5 : 1,
              ),
              gradient: isSelected
                  ? LinearGradient(
                      colors: isDark
                          ? [Colors.purple[900]!.withOpacity(0.2), Colors.purple[800]!.withOpacity(0.1)]
                          : [Colors.purple[50]!, Colors.purple[100]!.withOpacity(0.3)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icono del modelo con gradiente
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [Colors.purple[400]!, Colors.purple[700]!]
                          : [Colors.purple[300]!, Colors.purple[600]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: (isDark ? Colors.purple[400]! : Colors.purple[300]!)
                            .withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),

                // Contenido del modelo
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Título y badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              model.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isSelected
                                    ? (isDark ? Colors.purpleAccent : Colors.purple[900])
                                    : (isDark ? Colors.white : Colors.black87),
                              ),
                            ),
                          ),
                          if (isCurrent)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isDark
                                      ? [Colors.purpleAccent, Colors.purple[400]!]
                                      : [Colors.purple, Colors.purple[700]!],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.purple.withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Text(
                                'EN USO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Descripción
                      Text(
                        model.description,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey[400] : Colors.grey[700],
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Features chips
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _getModelFeatures(model, isDark),
                      ),
                      const SizedBox(height: 10),

                      // Proveedor
                      Row(
                        children: [
                          Icon(
                            Icons.verified,
                            size: 14,
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Por ${model.provider}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.grey[500] : Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          if (model.isFree)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isDark ? Colors.green[700] : Colors.green[100]),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'GRATIS',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? Colors.green[100] : Colors.green[800],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Check icon
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                    color: isSelected
                        ? (isDark ? Colors.purpleAccent : Colors.purple[700])
                        : (isDark ? Colors.grey[700] : Colors.grey[400]),
                    size: 32,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModelList(List<AIModel> models) {
    if (models.isEmpty) {
      return const Center(
        child: Text('No hay modelos disponibles'),
      );
    }

    return ListView.builder(
      itemCount: models.length,
      itemBuilder: (context, index) => _buildModelTile(models[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: screenSize.width > 600 ? 600 : screenSize.width * 0.95,
        constraints: BoxConstraints(
          maxHeight: screenSize.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header modernizado con gradiente
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [Colors.purple[700]!, Colors.purple[900]!]
                      : [Colors.purple[400]!, Colors.purple[600]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Seleccionar Modelo de IA',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Elige el modelo que mejor se adapte a tus necesidades',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Cerrar',
                  ),
                ],
              ),
            ),

            // Lista de modelos con padding mejorado
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _buildModelList(AIModel.availableModels),
              ),
            ),

            // Footer con información y botones
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Info banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.green[900]!.withOpacity(0.3) : Colors.green[50],
                      border: Border.all(
                        color: isDark ? Colors.green[700]! : Colors.green[200]!,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: isDark ? Colors.green[300] : Colors.green[700],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Todos los modelos son gratuitos con Google AI Studio',
                            style: TextStyle(
                              color: isDark ? Colors.green[100] : Colors.green[900],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Botones de acción
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancelar',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[400] : Colors.grey[700],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _selectedModel == null
                            ? null
                            : () => Navigator.pop(context, _selectedModel),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? Colors.purpleAccent : Colors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check, size: 18),
                            const SizedBox(width: 8),
                            const Text(
                              'Seleccionar',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
