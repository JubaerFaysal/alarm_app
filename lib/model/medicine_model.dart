import 'package:flutter/material.dart';
import 'dart:convert';

class Medicine {
  final int? id;
  final String name;
  final String dosage;
  final String type;
  final List<TimeOfDay> times;
  final String frequency;
  final int pillCount;
  final String instructions;
  final String intakeTime;
  final Color color;
  final bool isActive;
  final bool isTaken;
  final DateTime createdAt;
  final DateTime endDate;

  Medicine({
    this.id,
    required this.name,
    required this.dosage,
    required this.type,
    required this.times,
    required this.frequency,
    required this.pillCount,
    this.instructions = '',
    required this.intakeTime,
    required this.color,
    this.isActive = true,
    this.isTaken = false,
    required this.createdAt,
    required this.endDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'dosage': dosage,
      'type': type,
      'times': jsonEncode(
        times.map((t) => {'hour': t.hour, 'minute': t.minute}).toList(),
      ),
      'frequency': frequency,
      'pillCount': pillCount,
      'instructions': instructions,
      'intakeTime': intakeTime,
      'color': color.value,
      'isActive': isActive ? 1 : 0,
      'isTaken': isTaken ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'endDate': endDate.toIso8601String(),
    };
  }

  factory Medicine.fromMap(Map<String, dynamic> map) {
    try {
      List<TimeOfDay> timesList = [];

      // Handle both JSON format and corrupted string format
      if (map['times'] is String) {
        final timesString = map['times'] as String;

        // Check if it's valid JSON
        if (timesString.trim().startsWith('[')) {
          // It's JSON format - parse normally
          final List<dynamic> timesJson = jsonDecode(timesString);
          timesList = timesJson
              .map((t) => TimeOfDay(hour: t['hour'], minute: t['minute']))
              .toList();
        } else {
          // It's corrupted format like "9:42" - try to recover
          debugPrint('⚠️ Recovering corrupted time format: $timesString');
          try {
            // Try to parse time string like "9:42"
            final timeParts = timesString.split(':');
            if (timeParts.length == 2) {
              final hour = int.parse(timeParts[0]);
              final minute = int.parse(timeParts[1]);
              timesList.add(TimeOfDay(hour: hour, minute: minute));
            }
          } catch (e) {
            debugPrint('❌ Could not recover time: $e');
            // Fallback to default time
            timesList.add(TimeOfDay(hour: 8, minute: 0));
          }
        }
      }

      // If no times were parsed, add a default
      if (timesList.isEmpty) {
        timesList.add(TimeOfDay(hour: 8, minute: 0));
      }

      return Medicine(
        id: map['id'],
        name: map['name'],
        dosage: map['dosage'],
        type: map['type'],
        times: timesList,
        frequency: map['frequency'],
        pillCount: map['pillCount'],
        instructions: map['instructions'] ?? '',
        intakeTime: map['intakeTime'],
        color: Color(map['color']),
        isActive: map['isActive'] == 1,
        isTaken: (map['isTaken'] ?? 0) == 1,
        createdAt: DateTime.parse(map['createdAt']),
        endDate: DateTime.parse(map['endDate']),
      );
    } catch (e) {
      debugPrint('❌ Critical error parsing medicine: $e');
      debugPrint('Medicine data: $map');

      // Return a default medicine to prevent app crash
      return Medicine(
        id: map['id'],
        name: map['name'] ?? 'Unknown Medicine',
        dosage: map['dosage'] ?? '',
        type: map['type'] ?? 'Tablet',
        times: [TimeOfDay(hour: 8, minute: 0)],
        frequency: map['frequency'] ?? 'Once Daily',
        pillCount: map['pillCount'] ?? 1,
        instructions: map['instructions'] ?? '',
        intakeTime: map['intakeTime'] ?? 'After Food',
        color: Color(map['color'] ?? 0xFF4CAF50),
        isActive: (map['isActive'] ?? 1) == 1,
        isTaken: (map['isTaken'] ?? 0) == 1,
        createdAt: DateTime.now(),
        endDate: DateTime.now().add(Duration(days: 30)),
      );
    }
  }

  Medicine copyWith({
    int? id,
    String? name,
    String? dosage,
    String? type,
    List<TimeOfDay>? times,
    String? frequency,
    int? pillCount,
    String? instructions,
    String? intakeTime,
    Color? color,
    bool? isActive,
    bool? isTaken,
    DateTime? createdAt,
    DateTime? endDate,
  }) {
    return Medicine(
      id: id ?? this.id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      type: type ?? this.type,
      times: times ?? this.times,
      frequency: frequency ?? this.frequency,
      pillCount: pillCount ?? this.pillCount,
      instructions: instructions ?? this.instructions,
      intakeTime: intakeTime ?? this.intakeTime,
      color: color ?? this.color,
      isActive: isActive ?? this.isActive,
      isTaken: isTaken ?? this.isTaken,
      createdAt: createdAt ?? this.createdAt,
      endDate: endDate ?? this.endDate,
    );
  }

  bool get isToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endDay = DateTime(endDate.year, endDate.month, endDate.day);
    final startDay = DateTime(createdAt.year, createdAt.month, createdAt.day);

    return (today.isAfter(startDay.subtract(Duration(days: 1))) &&
        !today.isAfter(endDay));
  }

  bool get isWithinDateRange {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endDay = DateTime(endDate.year, endDate.month, endDate.day);
    return !today.isAfter(endDay);
  }

  int get daysRemaining {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endDay = DateTime(endDate.year, endDate.month, endDate.day);
    final difference = endDay.difference(today).inDays;
    return difference >= 0 ? difference : 0;
  }
}
