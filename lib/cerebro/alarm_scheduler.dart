import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Programa avisos del sistema para cuando termina un temporizador.
abstract interface class AlarmScheduler {
  Future<void> init();

  /// Pide los permisos que haga falta (notificaciones, alarma exacta).
  Future<void> ensurePermissions();

  Future<void> schedule({
    required String id,
    required String title,
    required String body,
    required DateTime at,
  });

  Future<void> cancel(String id);
}

/// Android: alarma del sistema, suena aunque la app esté cerrada.
/// Windows y Linux: el plugin no programa a futuro, así que el aviso sale
/// desde un Timer del proceso (la app debe seguir abierta o en la bandeja).
class LocalAlarmScheduler implements AlarmScheduler {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final Map<String, Timer> _desktopTimers = {};
  bool _ready = false;

  static const _channelId = 'mai_timers';
  static const _channelName = 'Temporizadores';

  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;
  bool get _isDesktop =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;

  /// Id numérico estable entre ejecuciones (String.hashCode no lo es).
  @visibleForTesting
  static int notificationId(String id) {
    var hash = 0x811c9dc5;
    for (final unit in id.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  @override
  Future<void> init() async {
    if (_ready || kIsWeb || !(_isAndroid || _isDesktop)) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          linux: LinuxInitializationSettings(defaultActionName: 'Abrir Mai'),
          windows: WindowsInitializationSettings(
            appName: 'Mai',
            appUserModelId: 'com.example.mai_ai',
            guid: '7a1f6c2e-4b0d-4d6e-9a53-2f5b8c0d1e77',
          ),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('No se pudieron inicializar las notificaciones: $e');
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<void> ensurePermissions() async {
    if (!_ready || !_isAndroid) return;
    try {
      await _android?.requestNotificationsPermission();
      if (await _android?.canScheduleExactNotifications() == false) {
        await _android?.requestExactAlarmsPermission();
      }
    } catch (e) {
      debugPrint('Error pidiendo permisos de notificación: $e');
    }
  }

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Avisos cuando termina un temporizador o pomodoro',
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
        ),
        linux: LinuxNotificationDetails(),
        windows: WindowsNotificationDetails(),
      );

  @override
  Future<void> schedule({
    required String id,
    required String title,
    required String body,
    required DateTime at,
  }) async {
    if (!_ready) return;
    await cancel(id);
    final nid = notificationId(id);

    try {
      if (_isAndroid) {
        final exact = await _android?.canScheduleExactNotifications() ?? false;
        await _plugin.zonedSchedule(
          id: nid,
          title: title,
          body: body,
          scheduledDate: tz.TZDateTime.fromMillisecondsSinceEpoch(
            tz.UTC,
            at.millisecondsSinceEpoch,
          ),
          notificationDetails: _details,
          androidScheduleMode: exact
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } else {
        final delay = at.difference(DateTime.now());
        _desktopTimers[id] = Timer(delay.isNegative ? Duration.zero : delay, () {
          _desktopTimers.remove(id);
          _plugin.show(id: nid, title: title, body: body, notificationDetails: _details);
        });
      }
    } catch (e) {
      debugPrint('No se pudo programar el aviso: $e');
    }
  }

  @override
  Future<void> cancel(String id) async {
    _desktopTimers.remove(id)?.cancel();
    if (!_ready || !_isAndroid) return;
    try {
      await _plugin.cancel(id: notificationId(id));
    } catch (e) {
      debugPrint('No se pudo cancelar el aviso: $e');
    }
  }
}
