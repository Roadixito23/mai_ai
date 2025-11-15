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

class _ModelSelectorDialogState extends State<ModelSelectorDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  AIModel? _selectedModel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedModel = AIModel.findById(widget.currentModel);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildModelTile(AIModel model) {
    final isSelected = _selectedModel?.id == model.id;
    final isCurrent = widget.currentModel == model.id;

    return Card(
      elevation: isSelected ? 4 : 1,
      color: isSelected ? Colors.purple[50] : null,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: model.isFree ? Colors.green[100] : Colors.orange[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            model.isFree ? Icons.check_circle : Icons.star,
            color: model.isFree ? Colors.green[700] : Colors.orange[700],
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                model.name,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 16,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: model.isFree ? Colors.green : Colors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                model.isFree ? 'GRATIS' : 'DE PAGO',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(model.description),
            const SizedBox(height: 4),
            Text(
              model.provider,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        trailing: isCurrent
            ? const Icon(Icons.check_circle, color: Colors.purple)
            : null,
        onTap: () {
          setState(() {
            _selectedModel = model;
          });
        },
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
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Título
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.purple, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Seleccionar Modelo de IA',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),

            // Tabs
            TabBar(
              controller: _tabController,
              labelColor: Colors.purple,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.purple,
              tabs: const [
                Tab(
                  icon: Icon(Icons.check_circle),
                  text: 'Gratis',
                ),
                Tab(
                  icon: Icon(Icons.star),
                  text: 'De Pago',
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Lista de modelos
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildModelList(AIModel.freeModels),
                  _buildModelList(AIModel.paidModels),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Advertencia si es de pago
            if (_selectedModel != null && !_selectedModel!.isFree)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '⚠️ Este modelo consume créditos de tu API key',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Botones
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _selectedModel == null
                      ? null
                      : () => Navigator.pop(context, _selectedModel),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Seleccionar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
