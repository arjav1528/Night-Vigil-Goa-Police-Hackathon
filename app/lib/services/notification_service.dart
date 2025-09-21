import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:night_vigil/models/duty_assignment_model.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();
    const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid, iOS: initializationSettingsIOS);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    tz.initializeTimeZones();
  }

  Future<void> scheduleDutyReminder(DutyAssignment duty) async {
    final scheduleTime = duty.startTime.subtract(const Duration(minutes: 10));

    if (scheduleTime.isAfter(DateTime.now())) {
      // --- THIS IS THE CORRECTED CODE ---
      await flutterLocalNotificationsPlugin.zonedSchedule(
        duty.id.hashCode,
        'Upcoming Duty Reminder',
        'Your duty at ${duty.location} starts in 10 minutes.',
        tz.TZDateTime.from(scheduleTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'duty_reminder_channel',
            'Duty Reminders',
            channelDescription: 'Notifications for upcoming duties',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        // The `androidAllowWhileIdle` parameter is now `androidScheduleMode`
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        // The `uiLocalNotificationDateInterpretation` parameter is correct
        
      );
      // ------------------------------------
      
      print('Scheduled reminder for duty at ${duty.location}');
    }
  }

  // --- For Location Boundary Alerts ---
  Future<void> showLocationAlert() async {
    const NotificationDetails notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'location_alert_channel',
        'Location Alerts',
        channelDescription: 'Alerts for leaving duty area',
        importance: Importance.max,
        priority: Priority.high,
      ),
    );
    await flutterLocalNotificationsPlugin.show(
      99, // A fixed ID for this type of alert
      'Location Alert',
      'You have moved outside your designated duty radius!',
      notificationDetails,
    );
  }
}