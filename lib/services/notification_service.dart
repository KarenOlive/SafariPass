import 'package:flutter_local_notifications/flutter_local_notifications.dart' as fln;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:io';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final fln.FlutterLocalNotificationsPlugin _notificationsPlugin =
      fln.FlutterLocalNotificationsPlugin();

  Future<void> setup() async {
    tz.initializeTimeZones();

    const fln.AndroidInitializationSettings androidSettings =
        fln.AndroidInitializationSettings('@mipmap/ic_launcher');

    const fln.DarwinInitializationSettings iosSettings = fln.DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const fln.InitializationSettings initSettings = fln.InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (fln.NotificationResponse details) {
        // Handle notification tap
      },
    );

    if (Platform.isAndroid) {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<fln.AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();
    }
  }

  /// Schedules 3 notifications for a ticket: 24h, 2h, and 30m before departure.
  Future<void> scheduleTicketNotifications(Map<String, dynamic> ticket) async {
    final String? departureStr = ticket['departure'];
    if (departureStr == null) return;

    final DateTime departure = DateTime.parse(departureStr);
    final String ticketId = ticket['ticket_id'] ?? '';
    final String destination = ticket['destination'] ?? 'Destination';
    final String carrier = ticket['carrier'] ?? 'Flight';
    final String pnr = ticket['pnr'] ?? '';

    final times = [
      {'offset': const Duration(hours: 24), 'label': '1 Day'},
      {'offset': const Duration(hours: 2), 'label': '2 Hours'},
      {'offset': const Duration(minutes: 30), 'label': '30 Minutes'},
    ];

    final int baseId = ticketId.hashCode.abs() % 100000;

    for (int i = 0; i < times.length; i++) {
      final duration = times[i]['offset'] as Duration;
      final label = times[i]['label'] as String;
      final scheduledTime = departure.subtract(duration);

      if (scheduledTime.isAfter(DateTime.now())) {
        await _scheduleNotification(
          id: baseId * 10 + i,
          title: '✈️ SafariPass: $label to go!',
          body: '$carrier to $destination ($pnr) is departing soon.',
          scheduledDate: scheduledTime,
        );
      }
    }
  }

  /// Sends an immediate test notification
  Future<void> triggerTestNotification() async {
    await _notificationsPlugin.show(
      id: 999,
      title: '🧪 SafariPass Test Alert',
      body: 'This is a verification that your notification system is active!',
      notificationDetails: const fln.NotificationDetails(
        android: fln.AndroidNotificationDetails(
          'test_channel',
          'Test Notifications',
          channelDescription: 'Used for system verification',
          importance: fln.Importance.max,
          priority: fln.Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: fln.DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
    print('✅ Test notification triggered');
  }

  /// Notify user that a flight status has changed (e.g., Delayed, Cancelled)
  Future<void> notifyFlightStatusChange({
    required String ticketId,
    required String carrier,
    required String route,
    required String newStatus,
    String? delayMinutes,
  }) async {
    final urgency = newStatus.toLowerCase() == 'cancelled' ? '🚨' : '⚠️';
    final delayText = delayMinutes != null ? ' (Delayed $delayMinutes min)' : '';

    await _notificationsPlugin.show(
      id: (ticketId.hashCode.abs() % 100000) * 10 + 5,
      title: '$urgency Flight Status Changed',
      body: '$carrier $route: $newStatus$delayText',
      notificationDetails: const fln.NotificationDetails(
        android: fln.AndroidNotificationDetails(
          'flight_status_changes',
          'Flight Status Updates',
          channelDescription: 'Notifications for flight status changes',
          importance: fln.Importance.high,
          priority: fln.Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: fln.DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
    print('✅ Flight status change notification sent for $carrier $route');
  }

  /// Notify user that gate has changed
  Future<void> notifyGateChange({
    required String ticketId,
    required String carrier,
    required String route,
    required String oldGate,
    required String newGate,
  }) async {
    await _notificationsPlugin.show(
      id: (ticketId.hashCode.abs() % 100000) * 10 + 6,
      title: '🚪 Gate Change',
      body: '$carrier $route: Gate $oldGate → $newGate',
      notificationDetails: const fln.NotificationDetails(
        android: fln.AndroidNotificationDetails(
          'gate_changes',
          'Gate Changes',
          channelDescription: 'Notifications for gate changes',
          importance: fln.Importance.high,
          priority: fln.Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: fln.DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
    print('✅ Gate change notification sent: $oldGate → $newGate');
  }

  /// Notify user of tight connection (less than 2 hours between arrival and departure)
  Future<void> notifyTightConnection({
    required String journeyId,
    required String departure1Carrier,
    required String departure1Gate,
    required DateTime arrival1Time,
    required String departure2Carrier,
    required String departure2Gate,
    required DateTime departure2Time,
  }) async {
    final timeUntilNextFlight = departure2Time.difference(arrival1Time).inMinutes;

    await _notificationsPlugin.show(
      id: (journeyId.hashCode.abs() % 100000) * 10 + 7,
      title: '⏰ Tight Connection Alert',
      body: 'Only $timeUntilNextFlight min between $departure1Carrier (Gate $departure1Gate) and $departure2Carrier (Gate $departure2Gate)',
      notificationDetails: const fln.NotificationDetails(
        android: fln.AndroidNotificationDetails(
          'tight_connections',
          'Tight Connection Alerts',
          channelDescription: 'Notifications for tight connections',
          importance: fln.Importance.max,
          priority: fln.Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: fln.DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
    print('✅ Tight connection alert sent: $timeUntilNextFlight min connection');
  }

  /// Cancel all notifications for a ticket (3 trip reminders)
  Future<void> cancelTicketNotifications(String ticketId) async {
    final int baseId = ticketId.hashCode.abs() % 100000;
    for (int i = 0; i < 3; i++) {
      await _notificationsPlugin.cancel(id: baseId * 10 + i);
    }
    print('✅ Notifications cancelled for ticket $ticketId');
  }

  /// Private helper to schedule timezone-aware notifications
  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);

    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tzDate,
      notificationDetails: fln.NotificationDetails(
        android: const fln.AndroidNotificationDetails(
          'trip_reminders',
          'Trip Reminders',
          channelDescription: 'Notifications for upcoming flights and trips',
          importance: fln.Importance.max,
          priority: fln.Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const fln.DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: fln.AndroidScheduleMode.exactAllowWhileIdle,
    );
    print('✅ Notification scheduled for $scheduledDate (ID: $id)');
  }
}
