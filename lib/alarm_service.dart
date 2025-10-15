import 'dart:async';
import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';

class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  bool _initialized = false;

  final _alarmRingController = StreamController<int>.broadcast();
  final _alarmStopController = StreamController<int>.broadcast();

  Stream<int> get onAlarmRing => _alarmRingController.stream;
  Stream<int> get onAlarmStop => _alarmStopController.stream;

  /// Initialize listeners only once
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Listen for ringing alarms
    Alarm.ringing.listen((alarmSet) {
      for (final alarm in alarmSet.alarms) {
        _alarmRingController.add(alarm.id);
        _onAlarmStart(alarm.id);
      }
    });

    // Listen for scheduled alarms (for debugging or UI updates)
    Alarm.scheduled.listen((alarmSet) {
      debugPrint('Scheduled alarms updated: ${alarmSet.alarms.length}');
    });
  }

  void _onAlarmStart(int alarmId) {
    debugPrint('Alarm $alarmId started ringing');
  }

  void _onAlarmStop(int alarmId) {
    debugPrint('Alarm $alarmId stopped');
    _alarmStopController.add(alarmId);
  }

  Future<bool> setAlarm({
    required int id,
    required DateTime dateTime,
    String assetAudioPath = 'assets/alarm.mp3',
    String title = 'Alarm',
    String body = 'Your alarm is ringing!',
    bool loopAudio = true,
    bool vibrate = true,
    double volume = 0.8,
    Duration fadeDuration = const Duration(seconds: 3),
    bool enableNotificationOnKill = true,
  }) async {
    try {
      if (dateTime.isBefore(DateTime.now())) {
        debugPrint('❌ Error: Alarm time is in the past');
        return false;
      }

      debugPrint('⏰ Setting alarm for: $dateTime with $assetAudioPath');

      final alarmSettings = AlarmSettings(
        id: id,
        dateTime: dateTime,
        assetAudioPath: assetAudioPath,
        loopAudio: loopAudio,
        vibrate: vibrate,
        androidFullScreenIntent: true,
        warningNotificationOnKill: enableNotificationOnKill,
        volumeSettings: VolumeSettings.fade(
          volume: volume,
          fadeDuration: fadeDuration,
          volumeEnforced: true,
        ),
        notificationSettings: NotificationSettings(
          title: title,
          body: body,
          stopButton: 'Stop',
        ),
      );

      final result = await Alarm.set(alarmSettings: alarmSettings);
      debugPrint(result ? '✅ Alarm set successfully' : '❌ Failed to set alarm');
      return result;
    } catch (e, stack) {
      debugPrint('❌ Error setting alarm: $e');
      debugPrint('Stack: $stack');
      return false;
    }
  }

  Future<void> stopAlarm(int id) async {
    try {
      await Alarm.stop(id);
      _onAlarmStop(id);
    } catch (e) {
      debugPrint('Error stopping alarm: $e');
    }
  }

  Future<void> stopAllAlarms() async {
    try {
      final active = await getActiveAlarmIds();
      await Alarm.stopAll();
      for (final id in active) {
        _onAlarmStop(id);
      }
    } catch (e) {
      debugPrint('Error stopping all alarms: $e');
    }
  }

  Future<List<int>> getActiveAlarmIds() async {
    try {
      final alarms = await Alarm.getAlarms();
      return alarms.map((e) => e.id).toList();
    } catch (e) {
      debugPrint('Error getting alarms: $e');
      return [];
    }
  }

  List<int> getRingingAlarmIds() {
    try {
      final ringing = Alarm.ringing.value;
      return ringing.alarms.map((e) => e.id).toList();
    } catch (e) {
      debugPrint('Error getting ringing alarms: $e');
      return [];
    }
  }

  void dispose() {
    _alarmRingController.close();
    _alarmStopController.close();
  }
}
