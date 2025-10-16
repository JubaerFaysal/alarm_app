import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'dart:convert';
import '../database/db_helper.dart';
import '../model/medicine_model.dart';

class MedicineAlarmService {
  static final MedicineAlarmService _instance =
      MedicineAlarmService._internal();
  factory MedicineAlarmService() => _instance;
  MedicineAlarmService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _initialized = false;

  // Local notifications for full-screen capability
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Callback to show alarm screen from main app
  Function(Medicine)? _onAlarmTriggered;

  Future<void> initialize({Function(Medicine)? onAlarmTriggered}) async {
    if (_initialized) return;

    try {
      // Store the callback
      _onAlarmTriggered = onAlarmTriggered;

      // Initialize Alarm
      await Alarm.init();

      // Initialize local notifications
      await _initializeNotifications();

      _initialized = true;
      debugPrint('✅ Alarm service initialized with full-screen support');
    } catch (e) {
      debugPrint('❌ Error initializing alarm: $e');
    }
  }

  Future<void> _initializeNotifications() async {
    // Create notification channel for full-screen intents
   const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'medicine_alarm_channel',
      'Medicine Alarms',
      description: 'Alarms for medicine reminders with full-screen support',
      importance: Importance.max,
      sound: RawResourceAndroidNotificationSound('alarm'),
      enableVibration: true,
      playSound: true,
    );


    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    await _notificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _onNotificationTapped(response.payload);
      },
    );
  }

  /// Set alarms for a medicine
  Future<bool> setMedicineAlarms(Medicine medicine) async {
    try {
      if (!_initialized) {
        await initialize();
      }

      await cancelMedicineAlarms(medicine.id!);

      debugPrint(
        '🔄 Setting ${medicine.times.length} alarms for ${medicine.name}',
      );

      for (int i = 0; i < medicine.times.length; i++) {
        final time = medicine.times[i];
        final alarmId = _generateAlarmId(medicine.id!, i);

        final alarmDateTime = _getNextAlarmDateTime(time, medicine.endDate);

        if (alarmDateTime != null) {
          final success = await _setSingleAlarm(
            alarmId: alarmId,
            dateTime: alarmDateTime,
            medicine: medicine,
            timeIndex: i,
          );

          if (success) {
            debugPrint(
              '✅ Alarm ${i + 1}/${medicine.times.length} SET: ${medicine.name} at ${_formatTime(time)} '
              '(ID: $alarmId, Time: $alarmDateTime)',
            );
          } else {
            debugPrint(
              '❌ Failed to set alarm ${i + 1} for medicine ${medicine.name} at ${_formatTime(time)}',
            );
          }
        } else {
          debugPrint(
            '⚠️ Skipping alarm ${i + 1} for ${medicine.name} at ${_formatTime(time)} - past end date',
          );
        }
      }

      await _verifyAlarmsSet(medicine);
      return true;
    } catch (e) {
      debugPrint('❌ Error setting medicine alarms: $e');
      return false;
    }
  }

  /// Generate unique alarm ID combining medicine ID and time index
  int _generateAlarmId(int medicineId, int timeIndex) {
    return (medicineId * 1000) + timeIndex;
  }

  /// Calculate the next alarm DateTime
  DateTime? _getNextAlarmDateTime(TimeOfDay time, DateTime endDate) {
    final now = DateTime.now();

    // Create DateTime for today with the selected time
    var alarmDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
      0, // seconds
      0, // milliseconds
    );

    // If the time has already passed today, schedule for tomorrow
    if (alarmDateTime.isBefore(now)) {
      alarmDateTime = alarmDateTime.add(Duration(days: 1));
    }

    // Add a safety buffer - ensure alarm is at least 1 minute in the future
    final minimumAlarmTime = now.add(Duration(minutes: 1));
    if (alarmDateTime.isBefore(minimumAlarmTime)) {
      alarmDateTime = minimumAlarmTime;
    }

    final endDay = DateTime(endDate.year, endDate.month, endDate.day);
    final alarmDay = DateTime(
      alarmDateTime.year,
      alarmDateTime.month,
      alarmDateTime.day,
    );

    // Check if alarm date is within the valid range
    if (alarmDay.isAfter(endDay)) {
      debugPrint(
        '⚠️ Alarm date $alarmDateTime is after end date $endDate - skipping',
      );
      return null;
    }

    debugPrint(
      '📅 Next alarm for ${_formatTime(time)}: $alarmDateTime (${alarmDateTime.difference(now).inMinutes} minutes from now)',
    );
    return alarmDateTime;
  }

  /// Set a single alarm with full-screen notification
  Future<bool> _setSingleAlarm({
    required int alarmId,
    required DateTime dateTime,
    required Medicine medicine,
    required int timeIndex,
  }) async {
    try {
      // Create alarm settings
      final alarmSettings = AlarmSettings(
        id: alarmId,
        dateTime: dateTime,
        assetAudioPath: 'assets/alarm.mp3',
        loopAudio: true,
        vibrate: true,
        volumeSettings: VolumeSettings.fade(
          volume: 0.8,
          fadeDuration: Duration(seconds: 3),
          volumeEnforced: true,
        ),
        notificationSettings: NotificationSettings(
          title: '💊 Medicine Reminder: ${medicine.name}',
          body:
              'Time to take ${medicine.dosage} of ${medicine.name} '
              '(${medicine.pillCount} ${medicine.type.toLowerCase()}${medicine.pillCount > 1 ? 's' : ''})',
          stopButton: 'Taken',
        ),
        androidFullScreenIntent: true,
        warningNotificationOnKill: true,
      );

      // Schedule full-screen notification
      await _scheduleFullScreenNotification(
        alarmId: alarmId,
        dateTime: dateTime,
        medicine: medicine,
      );

      final result = await Alarm.set(alarmSettings: alarmSettings);

      if (result) {
        debugPrint(
          '🎯 Alarm ${timeIndex + 1} SET SUCCESSFULLY: ${medicine.name} '
          '(ID: $alarmId, Time: $dateTime)',
        );
      } else {
        debugPrint('❌ Alarm.set() returned false for alarm ${timeIndex + 1}');
      }

      return result;
    } catch (e, stack) {
      debugPrint('❌ Error setting alarm ${timeIndex + 1}: $e');
      debugPrint('Stack trace: $stack');
      return false;
    }
  }

  /// Schedule full-screen notification
  Future<void> _scheduleFullScreenNotification({
    required int alarmId,
    required DateTime dateTime,
    required Medicine medicine,
  }) async {
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
            'medicine_alarm_channel',
            'Medicine Alarms',
            channelDescription:
                'Alarms for medicine reminders with full-screen support',
            importance: Importance.max,
            priority: Priority.high,
            fullScreenIntent: true,
            enableVibration: true,
            playSound: true,
            sound: RawResourceAndroidNotificationSound('alarm'),
            autoCancel: false,
            ongoing: true,
            category: AndroidNotificationCategory.alarm,
          );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
      );

      // Convert to TZDateTime for scheduling
      final scheduledDate = TZDateTime.from(dateTime, _local as Location);

     await _notificationsPlugin.zonedSchedule(
        alarmId,
        '💊 Medicine Reminder: ${medicine.name}',
        'Time to take ${medicine.dosage} • ${medicine.pillCount} ${medicine.type}${medicine.pillCount > 1 ? 's' : ''}',
        tz.TZDateTime.from(scheduledDate, tz.local),
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        // androidAllowWhileIdle: true,
        // uiLocalNotificationDateInterpretation:
        // UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: jsonEncode({
          'medicineId': medicine.id,
          'alarmId': alarmId,
          'medicineName': medicine.name,
          'dosage': medicine.dosage,
          'pillCount': medicine.pillCount,
          'type': medicine.type,
          'medicineNames': medicine.medicineNames,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }), 
        
      );



      debugPrint('📱 Full-screen notification scheduled for alarm $alarmId');
    } catch (e) {
      debugPrint('❌ Error scheduling full-screen notification: $e');
    }
  }

  /// Verify that all alarms were set correctly
  Future<void> _verifyAlarmsSet(Medicine medicine) async {
    try {
      final alarms = await Alarm.getAlarms();
      final medicineAlarmIds = List.generate(
        medicine.times.length,
        (i) => _generateAlarmId(medicine.id!, i),
      );

      final setAlarms = alarms
          .where((alarm) => medicineAlarmIds.contains(alarm.id))
          .toList();

      debugPrint('🔍 Verification for ${medicine.name}:');
      debugPrint('   Expected alarms: ${medicine.times.length}');
      debugPrint('   Actually set: ${setAlarms.length}');

      for (final alarm in setAlarms) {
        final timeIndex = alarm.id % 1000;
        final time = TimeOfDay.fromDateTime(alarm.dateTime);
        debugPrint(
          '   - Time ${timeIndex + 1}: ${_formatTime(time)} (ID: ${alarm.id})',
        );
      }

      if (setAlarms.length != medicine.times.length) {
        debugPrint('❌ ALARM COUNT MISMATCH for ${medicine.name}');
      }
    } catch (e) {
      debugPrint('❌ Error verifying alarms: $e');
    }
  }

  /// Cancel all alarms for a medicine
  Future<void> cancelMedicineAlarms(int medicineId) async {
    try {
      // Cancel alarms for all possible time slots (up to 12 times per medicine)
      for (int i = 0; i < 12; i++) {
        final alarmId = _generateAlarmId(medicineId, i);
        try {
          await Alarm.stop(alarmId);
          await _notificationsPlugin.cancel(alarmId);
          debugPrint('   - Cancelled alarm ID: $alarmId');
        } catch (e) {
          // Ignore errors for alarms that don't exist
        }
      }
      debugPrint('✅ Cancelled all alarms for medicine ID: $medicineId');
    } catch (e) {
      debugPrint('❌ Error cancelling medicine alarms: $e');
    }
  }

  /// Cancel all medicine alarms
  Future<void> cancelAllMedicineAlarms() async {
    try {
      final medicines = await _dbHelper.getMedicines();
      for (final medicine in medicines) {
        if (medicine.id != null) {
          await cancelMedicineAlarms(medicine.id!);
        }
      }
      debugPrint('✅ Cancelled all medicine alarms');
    } catch (e) {
      debugPrint('❌ Error cancelling all medicine alarms: $e');
    }
  }

  /// Setup alarm listeners for medicine reminders
  void initializeMedicineAlarmListeners() {
    // Listen for ringing alarms from alarm package
 Alarm.ringing.listen((alarmSet) {
      for (final alarm in alarmSet.alarms) {
        debugPrint('🔔 ALARM RINGING: ${alarm.id}');
        _onMedicineAlarmRinging(alarm.id);
      }
    });


    debugPrint('✅ Alarm listeners initialized with full-screen support');
  }

  /// Handle when medicine alarm rings
  void _onMedicineAlarmRinging(int alarmId) async {
    debugPrint('🔔 Medicine alarm ringing: $alarmId');

    // Extract medicine ID and time index from alarm ID
    final medicineId = alarmId ~/ 1000;

    try {
      // Get medicine details from database
      final medicines = await _dbHelper.getMedicines();
      final medicine = medicines.firstWhere(
        (m) => m.id == medicineId,
        orElse: () => Medicine(
          name: 'Medicine',
          medicineNames: ['Medicine'],
          dosage: '',
          type: 'Tablet',
          times: [],
          frequency: 'Once Daily',
          pillCount: 1,
          instructions: '',
          intakeTime: 'After Food',
          color: Colors.blue,
          isActive: true,
          isTaken: false,
          createdAt: DateTime.now(),
          endDate: DateTime.now().add(Duration(days: 30)),
        ),
      );

      // Trigger the alarm screen callback
      if (_onAlarmTriggered != null) {
        _onAlarmTriggered!(medicine);
      } else {
        debugPrint('❌ No alarm callback registered');
      }
    } catch (e) {
      debugPrint('❌ Error handling alarm for medicine ID $medicineId: $e');
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(String? payload) {
    if (payload != null) {
      try {
        final data = jsonDecode(payload);
        debugPrint('📱 Notification tapped with payload: $data');

        // Extract medicine data and trigger alarm screen
        final medicine = Medicine(
          id: data['medicineId'],
          name: data['medicineName'] ?? 'Medicine',
          medicineNames: List<String>.from(
            data['medicineNames'] ?? ['Medicine'],
          ),
          dosage: data['dosage'] ?? '',
          type: data['type'] ?? 'Tablet',
          times: [],
          frequency: 'Once Daily',
          pillCount: data['pillCount'] ?? 1,
          instructions: '',
          intakeTime: 'After Food',
          color: Colors.blue,
          isActive: true,
          isTaken: false,
          createdAt: DateTime.now(),
          endDate: DateTime.now().add(Duration(days: 30)),
        );

        // Trigger the alarm screen callback
        if (_onAlarmTriggered != null) {
          _onAlarmTriggered!(medicine);
        }
      } catch (e) {
        debugPrint('❌ Error parsing notification payload: $e');
      }
    }
  }

  /// Show immediate test alarm (for testing)
  void showTestAlarm() {
    final testMedicine = Medicine(
      name: 'Test Medicine',
      medicineNames: ['Paracetamol', 'Vitamin C'],
      dosage: '500mg',
      type: 'Tablet',
      times: [TimeOfDay.now()],
      frequency: 'Once Daily',
      pillCount: 2,
      instructions: 'Take with water',
      intakeTime: 'After Food',
      color: Colors.blue,
      isActive: true,
      isTaken: false,
      createdAt: DateTime.now(),
      endDate: DateTime.now().add(Duration(days: 30)),
    );

    if (_onAlarmTriggered != null) {
      _onAlarmTriggered!(testMedicine);
    }
  }

  /// Debug method to check all set alarms in the system
  Future<void> debugAllAlarms() async {
    try {
      final alarms = await Alarm.getAlarms();
      final notifications = await _notificationsPlugin
          .pendingNotificationRequests();

      debugPrint('🔍 SYSTEM WIDE ALARM DEBUG:');
      debugPrint('   Alarm package alarms: ${alarms.length}');
      debugPrint('   Scheduled notifications: ${notifications.length}');

      if (alarms.isEmpty) {
        debugPrint('   No alarms currently set in alarm system');
      } else {
        // Group by medicine ID
        final alarmGroups = <int, List<AlarmSettings>>{};
        for (final alarm in alarms) {
          final medicineId = alarm.id ~/ 1000;
          if (!alarmGroups.containsKey(medicineId)) {
            alarmGroups[medicineId] = [];
          }
          alarmGroups[medicineId]!.add(alarm);
        }

        for (final entry in alarmGroups.entries) {
          debugPrint(
            '   Medicine ID: ${entry.key} - ${entry.value.length} alarms:',
          );
          for (final alarm in entry.value) {
            final timeIndex = alarm.id % 1000;
            final time = TimeOfDay.fromDateTime(alarm.dateTime);
            debugPrint(
              '     - Time ${timeIndex + 1}: ${_formatTime(time)} (ID: ${alarm.id})',
            );
          }
        }
      }

      if (notifications.isNotEmpty) {
        debugPrint('   Scheduled notifications:');
        for (final notification in notifications) {
          debugPrint(
            '     - ID: ${notification.id}, Title: ${notification.title}',
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error debugging all alarms: $e');
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  // Timezone local
  static final _local = DateTime.now().timeZoneOffset;
}
