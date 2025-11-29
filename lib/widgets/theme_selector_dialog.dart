import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class ThemeSelectorDialog extends StatelessWidget {
  const ThemeSelectorDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
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
            // Header
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [Colors.indigo[700]!, Colors.indigo[900]!]
                      : [Colors.indigo[400]!, Colors.indigo[600]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.palette,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Seleccionar Tema',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Personaliza la apariencia',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Opciones de tema
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _ThemeOptionTile(
                    icon: Icons.light_mode,
                    title: 'Tema Claro',
                    description: 'Interfaz brillante y clara',
                    themeMode: ThemeMode.light,
                    currentThemeMode: themeProvider.themeMode,
                    onTap: () async {
                      await themeProvider.setThemeMode(ThemeMode.light);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _ThemeOptionTile(
                    icon: Icons.dark_mode,
                    title: 'Tema Oscuro',
                    description: 'Interfaz oscura y relajante',
                    themeMode: ThemeMode.dark,
                    currentThemeMode: themeProvider.themeMode,
                    onTap: () async {
                      await themeProvider.setThemeMode(ThemeMode.dark);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  _ThemeOptionTile(
                    icon: Icons.settings_suggest,
                    title: 'Sistema',
                    description: 'Usar configuración del sistema',
                    themeMode: ThemeMode.system,
                    currentThemeMode: themeProvider.themeMode,
                    onTap: () async {
                      await themeProvider.setThemeMode(ThemeMode.system);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    isDark: isDark,
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

class _ThemeOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final ThemeMode themeMode;
  final ThemeMode currentThemeMode;
  final VoidCallback onTap;
  final bool isDark;

  const _ThemeOptionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.themeMode,
    required this.currentThemeMode,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = themeMode == currentThemeMode;

    Color getIconColor() {
      if (themeMode == ThemeMode.light) {
        return isDark ? Colors.amber[300]! : Colors.amber[700]!;
      } else if (themeMode == ThemeMode.dark) {
        return isDark ? Colors.indigo[300]! : Colors.indigo[700]!;
      } else {
        return isDark ? Colors.purple[300]! : Colors.purple[700]!;
      }
    }

    return Material(
      elevation: isSelected ? 6 : 2,
      borderRadius: BorderRadius.circular(12),
      color: isSelected
          ? (isDark ? Colors.indigo[900]!.withOpacity(0.3) : Colors.indigo[50])
          : (isDark ? const Color(0xFF2C2C2C) : Colors.white),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? (isDark ? Colors.indigoAccent : Colors.indigo)
                  : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey[300]!),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: getIconColor().withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: getIconColor().withOpacity(0.3),
                  ),
                ),
                child: Icon(
                  icon,
                  color: getIconColor(),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? (isDark ? Colors.indigoAccent : Colors.indigo[900])
                            : (isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: isDark ? Colors.indigoAccent : Colors.indigo[700],
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
