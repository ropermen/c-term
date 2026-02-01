import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class ForegroundServiceManager {
  static bool _isInitialized = false;
  static bool _isRunning = false;

  static Future<void> init() async {
    if (_isInitialized) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'c_term_ssh',
        channelName: 'c-term SSH',
        channelDescription: 'Conexoes SSH ativas',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    _isInitialized = true;
  }

  static Future<void> startService(int sessionCount) async {
    if (!_isInitialized) await init();

    if (_isRunning) {
      await updateNotification(sessionCount);
      return;
    }

    await FlutterForegroundTask.startService(
      notificationTitle: 'c-term',
      notificationText: '$sessionCount conexao(oes) SSH ativa(s)',
      callback: null,
    );

    _isRunning = true;
  }

  static Future<void> updateNotification(int sessionCount) async {
    if (!_isRunning) return;

    await FlutterForegroundTask.updateService(
      notificationTitle: 'c-term',
      notificationText: '$sessionCount conexao(oes) SSH ativa(s)',
    );
  }

  static Future<void> stopService() async {
    if (!_isRunning) return;

    await FlutterForegroundTask.stopService();
    _isRunning = false;
  }

  static bool get isRunning => _isRunning;
}
