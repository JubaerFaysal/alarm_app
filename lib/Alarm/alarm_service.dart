

import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../model/medicine_model.dart';

class MedicineAlarmService {
  static final MedicineAlarmService _instance = MedicineAlarmService._internal();
  factory MedicineAlarmService() => _instance;
  MedicineAlarmService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _initialized = false;

  /// Initialize alarm service
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // Initialize Alarm
      await Alarm.init();
      _initialized = true;
      debugPrint('✅ Alarm service initialized');
    } catch (e) {
      debugPrint('❌ Error initializing alarm: $e');
    }
  }

  /// Set alarms for a medicine
  Future<bool> setMedicineAlarms(Medicine medicine) async {
    try {
      if (!_initialized) {
        await initialize();
      }

      // Cancel existing alarms for this medicine first
      await cancelMedicineAlarms(medicine.id!);

      // Set alarms for each time
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
              '✅ Medicine alarm set: ${medicine.name} at ${_formatTime(time)} '
              '(ID: $alarmId, Time: $alarmDateTime)',
            );
          } else {
            debugPrint(
              '❌ Failed to set alarm for medicine ${medicine.name} at ${_formatTime(time)}',
            );
          }
        }
      }

      return true;
    } catch (e) {
      debugPrint('❌ Error setting medicine alarms: $e');
      return false;
    }
  }

  /// Generate unique alarm ID combining medicine ID and time index
  int _generateAlarmId(int medicineId, int timeIndex) {
    return medicineId * 1000 + timeIndex; // Use larger multiplier to avoid conflicts
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
    );

    // If the time has already passed today, schedule for tomorrow
    if (alarmDateTime.isBefore(now)) {
      alarmDateTime = alarmDateTime.add(Duration(days: 1));
    }

    // Check if alarm date is before end date
    if (alarmDateTime.isAfter(endDate)) {
      debugPrint('⚠️ Alarm date $alarmDateTime is after end date $endDate - skipping');
      return null;
    }

    debugPrint('📅 Next alarm for ${_formatTime(time)}: $alarmDateTime');
    return alarmDateTime;
  }

  /// Set a single alarm
  Future<bool> _setSingleAlarm({
    required int alarmId,
    required DateTime dateTime,
    required Medicine medicine,
    required int timeIndex,
  }) async {
    try {
      // Test with a time 1 minute from now for debugging
      //final testDateTime = DateTime.now().add(Duration(minutes: 1));
      
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


      final result = await Alarm.set(alarmSettings: alarmSettings);

      if (result) {
        debugPrint(
          '🎯 Alarm SET SUCCESSFULLY: ${medicine.name} at ${_formatTime(medicine.times[timeIndex])} '
          '(ID: $alarmId, Time: $dateTime)',
        );
        
        // Verify the alarm was set
        final alarms = await Alarm.getAlarms();
        debugPrint('📋 Currently set alarms: ${alarms.length}');
        for (final alarm in alarms) {
          debugPrint('   - Alarm ID: ${alarm.id}, Time: ${alarm.dateTime}');
        }
      } else {
        debugPrint('❌ Alarm.set() returned false');
      }

      return result;
    } catch (e, stack) {
      debugPrint('❌ Error setting single alarm: $e');
      debugPrint('Stack trace: $stack');
      return false;
    }
  }

  /// Cancel all alarms for a medicine
  Future<void> cancelMedicineAlarms(int medicineId) async {
    try {
      // Cancel alarms for all possible time slots
      for (int i = 0; i < 10; i++) {
        final alarmId = _generateAlarmId(medicineId, i);
        await Alarm.stop(alarmId);
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
    // Listen for ringing alarms
    Alarm.ringing.listen((alarmId) {
      debugPrint('🔔🔔🔔 ALARM RINGING: $alarmId');
      _onMedicineAlarmRinging(alarmId as int);
    });

    // Listen for alarm stop events
Alarm.ringing.listen((alarmSet) {
      if (alarmSet.alarms.isEmpty) {
        debugPrint('⏹️ All alarms stopped');
      } else {
        for (final alarm in alarmSet.alarms) {
          debugPrint('🔔 Alarm ringing: ${alarm.id}');
        }
      }
    });


    debugPrint('✅ Alarm listeners initialized');
  }

  /// Handle when medicine alarm rings
  void _onMedicineAlarmRinging(int alarmId) {
    debugPrint('🔔 Medicine alarm ringing: $alarmId');
    
    // You can show notification or update UI here
    // For now, just log the event
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  /// Debug method to check all set alarms
  Future<void> debugAlarms() async {
    try {
      final alarms = await Alarm.getAlarms();
      debugPrint('🔍 DEBUG - Currently set alarms: ${alarms.length}');
      for (final alarm in alarms) {
        debugPrint('   - Alarm ID: ${alarm.id}, Time: ${alarm.dateTime}');
      }
    } catch (e) {
      debugPrint('❌ Error debugging alarms: $e');
    }
  }
}