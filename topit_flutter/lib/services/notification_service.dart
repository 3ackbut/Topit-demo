import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

const worldModeNotificationPayload = 'world_mode';

typedef NotificationTapHandler = void Function(String? payload);

class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _notificationId = 1001;
  static const _channelId = 'daily_world_topic';
  static const _channelName = '世界のお題';
  static const _channelDescription = '毎日の世界のお題を知らせます';

  final FlutterLocalNotificationsPlugin _plugin;
  NotificationTapHandler? _onNotificationTap;
  bool _initialized = false;

  void setOnNotificationTap(NotificationTapHandler handler) {
    _onNotificationTap = handler;
  }

  Future<bool> initialize({NotificationTapHandler? onNotificationTap}) async {
    _onNotificationTap = onNotificationTap;

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _plugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        _onNotificationTap?.call(response.payload);
      },
    );
    _initialized = true;

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    return launchDetails?.didNotificationLaunchApp == true &&
        launchDetails?.notificationResponse?.payload ==
            worldModeNotificationPayload;
  }

  Future<void> requestPermissionAndSchedule() async {
    if (!_initialized) {
      return;
    }

    final iosPlugin =
        _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
    final iosGranted = await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    final androidPlugin =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    final androidGranted =
        await androidPlugin?.requestNotificationsPermission();

    // Android versions before 13 return null because no runtime permission is
    // needed. iOS returns null only when its platform implementation is absent.
    if (iosGranted == false || androidGranted == false) {
      return;
    }

    await scheduleDailyWorldNotification();
  }

  Future<void> scheduleDailyWorldNotification({DateTime? now}) async {
    if (!_initialized) {
      return;
    }

    final current = (now ?? DateTime.now()).toUtc();
    // `tz.UTC` is built into the timezone package.  Using it directly avoids
    // looking up the optional `Etc/UTC` database alias, which is unavailable
    // in some timezone-data builds.
    final nextMidnight = tz.TZDateTime.from(nextUtcMidnight(current), tz.UTC);

    await _plugin.cancel(_notificationId);
    await _plugin.zonedSchedule(
      _notificationId,
      'トピット',
      '今日の世界のお題を確認しよう!',
      nextMidnight,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: worldModeNotificationPayload,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static DateTime nextUtcMidnight(DateTime now) {
    final current = now.toUtc();
    return DateTime.utc(current.year, current.month, current.day + 1);
  }
}
