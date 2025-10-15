import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../model/medicine_model.dart';

class MedicineAlarmService {
  static final MedicineAlarmService _instance =
      MedicineAlarmService._internal();
  factory MedicineAlarmService() => _instance;
  MedicineAlarmService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Set alarms for a medicine
  Future<bool> setMedicineAlarms(Medicine medicine) async {
    try {
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

          if (!success) {
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
    return medicineId * 100 + timeIndex;
  }

  /// Calculate the next alarm DateTime
  DateTime? _getNextAlarmDateTime(TimeOfDay time, DateTime endDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Create DateTime for today with the selected time
    var alarmDateTime = DateTime(
      today.year,
      today.month,
      today.day,
      time.hour,
      time.minute,
    );

    // If the time has already passed today, schedule for tomorrow
    if (alarmDateTime.isBefore(now)) {
      alarmDateTime = alarmDateTime.add(Duration(days: 1));
    }

    // Check if alarm date is before end date
    if (alarmDateTime.isAfter(endDate)) {
      return null;
    }

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
          '✅ Medicine alarm set: ${medicine.name} at ${_formatTime(medicine.times[timeIndex])} '
          '(ID: $alarmId, Time: $dateTime)',
        );
      }

      return result;
    } catch (e) {
      debugPrint('❌ Error setting single alarm: $e');
      return false;
    }
  }

  /// Cancel all alarms for a medicine
  Future<void> cancelMedicineAlarms(int medicineId) async {
    try {
      // Cancel alarms for all time slots (0-3)
      for (int i = 0; i < 4; i++) {
        final alarmId = _generateAlarmId(medicineId, i);
        await Alarm.stop(alarmId);
      }
      debugPrint('✅ Cancelled all alarms for medicine ID: $medicineId');
    } catch (e) {
      debugPrint('❌ Error cancelling medicine alarms: $e');
    }
  }

  /// Cancel all medicine alarms (when app starts or resets)
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
    Alarm.ringing.listen((alarmSet) {
      for (final alarm in alarmSet.alarms) {
        _onMedicineAlarmRinging(alarm.id);
      }
    });
  }

  /// Handle when medicine alarm rings
  void _onMedicineAlarmRinging(int alarmId) {
    debugPrint('🔔 Medicine alarm ringing: $alarmId');

    // You can add additional logic here like:
    // - Show custom notification
    // - Update UI
    // - Play custom sound
    // - etc.
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}
