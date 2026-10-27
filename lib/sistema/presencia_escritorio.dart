import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'lanzador.dart';

/// Mai en Windows y Linux: vive en la bandeja (cerrar la ventana la oculta,
/// así timers y sincronización siguen activos) y un atajo global la trae al
/// frente escuchando.
class PresenciaEscritorio with WindowListener, TrayListener {
  PresenciaEscritorio._();

  static final PresenciaEscritorio shared = PresenciaEscritorio._();

  static bool get soportado => !kIsWeb && (Platform.isWindows || Platform.isLinux);

  /// Ctrl+Alt+Espacio: muestra a Mai y empieza a escuchar; si ya escuchaba, envía.
  static final HotKey atajo = HotKey(
    key: PhysicalKeyboardKey.space,
    modifiers: [HotKeyModifier.control, HotKeyModifier.alt],
    scope: HotKeyScope.system,
  );
  static const String atajoTexto = 'Ctrl+Alt+Espacio';

  bool _saliendo = false;

  Future<void> init() async {
    if (!soportado) return;
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);

    // Si la bandeja o el atajo fallan (escritorio sin bandeja, Linux sin
    // keybinder), Mai sigue funcionando como una ventana normal.
    try {
      await _initBandeja();
    } catch (e) {
      debugPrint('Bandeja no disponible: $e');
      await windowManager.setPreventClose(false); // sin bandeja, cerrar = salir
    }
    try {
      await hotKeyManager.unregisterAll(); // limpia registros de un hot restart
      await hotKeyManager.register(atajo, keyDownHandler: (_) => escuchar());
    } catch (e) {
      debugPrint('Atajo global no disponible: $e');
    }
  }

  Future<void> _initBandeja() async {
    await trayManager.setIcon(Platform.isWindows ? 'assets/tray/mai.ico' : 'assets/tray/mai.png');
    await trayManager.setToolTip('Mai');
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: 'abrir', label: 'Abrir Mai'),
      MenuItem(key: 'hablar', label: 'Hablar con Mai ($atajoTexto)'),
      MenuItem.separator(),
      MenuItem(key: 'salir', label: 'Salir'),
    ]));
    trayManager.addListener(this);
  }

  Future<void> mostrar() async {
    if (await windowManager.isMinimized()) await windowManager.restore();
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> escuchar() async {
    await mostrar();
    Lanzador.shared.pedir(const Escuchar());
  }

  /// Cierra de verdad: quita el atajo y la bandeja y termina la app.
  Future<void> salir() async {
    _saliendo = true;
    try {
      await hotKeyManager.unregisterAll();
      await trayManager.destroy();
    } catch (_) {}
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  @override
  void onWindowClose() {
    if (!_saliendo) windowManager.hide();
  }

  @override
  void onTrayIconMouseDown() => mostrar();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'abrir':
        mostrar();
      case 'hablar':
        escuchar();
      case 'salir':
        salir();
    }
  }
}
