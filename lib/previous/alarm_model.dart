class AlarmModel {
  final int id;
  final DateTime dateTime;
  final String label;
  final bool isActive;
  final String audioPath;
  final bool vibrate;
  final double volume;

  AlarmModel({
    required this.id,
    required this.dateTime,
    this.label = 'Alarm',
    this.isActive = true,
    this.audioPath = 'assets/alarm.mp3',
    this.vibrate = true,
    this.volume = 0.8,
  });

  AlarmModel copyWith({
    int? id,
    DateTime? dateTime,
    String? label,
    bool? isActive,
    String? audioPath,
    bool? vibrate,
    double? volume,
  }) {
    return AlarmModel(
      id: id ?? this.id,
      dateTime: dateTime ?? this.dateTime,
      label: label ?? this.label,
      isActive: isActive ?? this.isActive,
      audioPath: audioPath ?? this.audioPath,
      vibrate: vibrate ?? this.vibrate,
      volume: volume ?? this.volume,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dateTime': dateTime.millisecondsSinceEpoch,
      'label': label,
      'isActive': isActive,
      'audioPath': audioPath,
      'vibrate': vibrate,
      'volume': volume,
    };
  }

  factory AlarmModel.fromMap(Map<String, dynamic> map) {
    return AlarmModel(
      id: map['id'],
      dateTime: DateTime.fromMillisecondsSinceEpoch(map['dateTime']),
      label: map['label'],
      isActive: map['isActive'],
      audioPath: map['audioPath'],
      vibrate: map['vibrate'],
      volume: map['volume'],
    );
  }

  String get timeString {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String get amPm {
    return dateTime.hour < 12 ? 'AM' : 'PM';
  }

  @override
  String toString() {
    return 'AlarmModel(id: $id, dateTime: $dateTime, label: $label, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AlarmModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
