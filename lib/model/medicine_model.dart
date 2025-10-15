import 'package:flutter/material.dart';

class Medicine {
  int? id;
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
    required this.instructions,
    required this.intakeTime,
    required this.color,
    this.isActive = true,
    required this.createdAt,
    required this.endDate,
  });

  // Add copyWith method
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
      createdAt: createdAt ?? this.createdAt,
      endDate: endDate ?? this.endDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'dosage': dosage,
      'type': type,
      'times': times.map((time) => '${time.hour}:${time.minute}').join(','),
      'frequency': frequency,
      'pillCount': pillCount,
      'instructions': instructions,
      'intakeTime': intakeTime,
      'color': color.value,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'endDate': endDate.toIso8601String(),
    };
  }

  static Medicine fromMap(Map<String, dynamic> map) {
    List<TimeOfDay> times = [];
    if (map['times'] is String) {
      final timeStrings = (map['times'] as String).split(',');
      times =
          timeStrings.map((timeStr) {
            final parts = timeStr.split(':');
            return TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            );
          }).toList();
    }

    // Parse end date, provide a default if it does not exist
    DateTime endDate;
    if (map['endDate'] != null) {
      endDate = DateTime.parse(map['endDate']);
    } else {
      endDate = DateTime.now().add(const Duration(days: 3));
    }

    return Medicine(
      id: map['id'],
      name: map['name'] ?? '',
      dosage: map['dosage'] ?? '',
      type: map['type'] ?? '',
      times: times,
      frequency: map['frequency'] ?? '',
      pillCount: map['pillCount'] ?? 1,
      instructions: map['instructions'] ?? '',
      intakeTime: map['intakeTime'] ?? '',
      color: Color(map['color'] ?? 0xFF667EEA),
      isActive: (map['isActive'] ?? 1) == 1,
      createdAt: DateTime.parse(map['createdAt']),
      endDate: endDate,
    );
  }

  // Helper method to check if medicine is still active based on end date
  bool get isWithinDateRange {
    final now = DateTime.now();
    return now.isBefore(endDate) || now.isAtSameMomentAs(endDate);
  }

  // Helper method to get days remaining
  int? get daysRemaining {
    final now = DateTime.now();
    final difference = endDate.difference(now);
    return difference.inDays;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Medicine && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
