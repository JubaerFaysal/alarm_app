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
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Alarm.init();
      _initialized = true;
      debugPrint('✅ Alarm service initialized');
    } catch (e) {
      debugPrint('❌ Error initializing alarm: $e');
    }
  }

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

  int _generateAlarmId(int medicineId, int timeIndex) {
    return (medicineId * 1000) +
        timeIndex; // Increased multiplier to prevent collisions
  }

  DateTime? _getNextAlarmDateTime(TimeOfDay time, DateTime endDate) {
    final now = DateTime.now();

    var alarmDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    if (alarmDateTime.isBefore(now)) {
      alarmDateTime = alarmDateTime.add(Duration(days: 1));
    }

    final endDay = DateTime(endDate.year, endDate.month, endDate.day);
    final alarmDay = DateTime(
      alarmDateTime.year,
      alarmDateTime.month,
      alarmDateTime.day,
    );

    if (alarmDay.isAfter(endDay)) {
      debugPrint(
        '⚠️ Alarm date $alarmDateTime is after end date $endDate - skipping',
      );
      return null;
    }

    debugPrint('📅 Next alarm for ${_formatTime(time)}: $alarmDateTime');
    return alarmDateTime;
  }

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

  Future<void> cancelMedicineAlarms(int medicineId) async {
    try {
      for (int i = 0; i < 10; i++) {
        final alarmId = _generateAlarmId(medicineId, i);
        try {
          await Alarm.stop(alarmId);
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

void initializeMedicineAlarmListeners() {
    Alarm.ringing.listen((alarmSet) {
      for (final alarm in alarmSet.alarms) {
        debugPrint('🔔 Medicine alarm ringing: ${alarm.id}');
        _onMedicineAlarmRinging(alarm.id);
      }
    });

    debugPrint('✅ Alarm listeners initialized');
  }


  void _onMedicineAlarmRinging(int alarmId) {
    debugPrint('🔔 Medicine alarm ringing: $alarmId');

    final medicineId = alarmId ~/ 1000;
    final timeIndex = alarmId % 1000;

    debugPrint('   Medicine ID: $medicineId, Time Index: $timeIndex');
  }

  Future<void> debugAllAlarms() async {
    try {
      final alarms = await Alarm.getAlarms();
      debugPrint('🔍 SYSTEM WIDE - Currently set alarms: ${alarms.length}');

      if (alarms.isEmpty) {
        debugPrint('   No alarms currently set in the system');
        return;
      }

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
}
