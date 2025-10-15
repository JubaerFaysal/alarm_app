import 'package:alarm_test_final/Alarm/alarm_service.dart';
import 'package:alarm_test_final/database/db_helper.dart';
import 'package:alarm_test_final/medicine_remainder.dart';
import 'package:flutter/material.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final MedicineAlarmService _medicineAlarmService = MedicineAlarmService();

  @override
  void initState() {
    super.initState();
    _initializeAlarms();
  }

  Future<void> _initializeAlarms() async {
    try {
      // Initialize alarm service first
      await _medicineAlarmService.initialize();

      // Initialize alarm listeners
      _medicineAlarmService.initializeMedicineAlarmListeners();

      // Reschedule all alarms
      await _rescheduleAllMedicineAlarms();

      // Debug: Check what alarms are set
      await _medicineAlarmService.debugAlarms();
    } catch (e) {
      debugPrint('❌ Error in alarm initialization: $e');
    }
  }

  Future<void> _rescheduleAllMedicineAlarms() async {
    try {
      final dbHelper = DatabaseHelper();
      final medicines = await dbHelper.getMedicines();

      debugPrint('🔄 Rescheduling alarms for ${medicines.length} medicines');

      for (final medicine in medicines) {
        if (medicine.isActive &&
            medicine.id != null &&
            medicine.isWithinDateRange) {
          await _medicineAlarmService.setMedicineAlarms(medicine);
        }
      }

      debugPrint('✅ Rescheduled alarms for ${medicines.length} medicines');
    } catch (e) {
      debugPrint('❌ Error rescheduling medicine alarms: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Medicine Reminder',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: MedicineListScreen(),
    );
  }
}
