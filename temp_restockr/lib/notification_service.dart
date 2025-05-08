import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(initSettings);
  }

  Future<void> scheduleShoppingReminder(DateTime shoppingDate, String title, String body) async {
    // Schedule notification for 1 day before
    final reminderDate = shoppingDate.subtract(const Duration(days: 1));
    
    // Only schedule if the reminder date is in the future
    if (reminderDate.isAfter(DateTime.now())) {
      await _notifications.zonedSchedule(
        0, // notification id
        title,
        body,
        tz.TZDateTime.from(reminderDate, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'shopping_reminders',
            'Shopping Reminders',
            channelDescription: 'Notifications for upcoming shopping dates',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    // Schedule notification for the day of shopping
    await _notifications.zonedSchedule(
      1, // different notification id
      'Shopping Day!',
      'Today is your scheduled shopping day. Don\'t forget to check your shopping list!',
      tz.TZDateTime.from(shoppingDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'shopping_reminders',
          'Shopping Reminders',
          channelDescription: 'Notifications for upcoming shopping dates',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
} 